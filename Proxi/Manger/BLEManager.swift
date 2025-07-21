//
//  BLEManager.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/20/25.
//
import Foundation
import SwiftUI
import CoreBluetooth
import NearbyInteraction
import simd

// MARK: - Message Protocol (Qorvo)
enum MessageId: UInt8 {
    // Messages from the accessory
    case accessoryConfigurationData = 0x1
    case accessoryUwbDidStart = 0x2
    case accessoryUwbDidStop = 0x3
    
    // Messages to the accessory
    case initialize = 0xA
    case configureAndStart = 0xB
    case stop = 0xC
}

// MARK: - UWB Location Data
struct UWBLocation {
    var distance: Float = 0
    var azimuth: Float = 0
    var elevation: Float = 0
    var direction: simd_float3 = SIMD3<Float>(x: 0, y: 0, z: 0)
    var isValid: Bool = false
    var timestamp: Date = Date()
}

// MARK: - UWB BLE Manager (Qorvo Protocol)
class BLEManager: NSObject, ObservableObject {
    
    // MARK: - BLE Properties (Qorvo UUIDs)
    private let transferServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let rxCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private let txCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    
    // Alternative Qorvo NI Service UUIDs
    private let qorvoServiceUUID = CBUUID(string: "2E938FD0-6A61-11ED-A1EB-0242AC120002")
    private let qorvoRxUUID = CBUUID(string: "2E93998A-6A61-11ED-A1EB-0242AC120002")
    private let qorvoTxUUID = CBUUID(string: "2E939AF2-6A61-11ED-A1EB-0242AC120002")
    
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var rxCharacteristic: CBCharacteristic?
    private var txCharacteristic: CBCharacteristic?
    
    // MARK: - UWB Properties
    private var niSession: NISession?
    private var configuration: NINearbyAccessoryConfiguration?
    private var accessoryDiscoveryToken: NIDiscoveryToken?
    
    // MARK: - Published Properties (Compatible with existing interface)
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var isRanging = false
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectionStatus = "Disconnected"
    @Published var uwbLocation = UWBLocation()
    @Published var debugLog: [String] = []
    @Published var rssi: Int = 0
    @Published var protocolState = "Not Connected"
    @Published var receivedNumber: Int = 0 // For compatibility
    
    // Protocol state tracking
    private var lastMessageSent: MessageId?
    private var configurationAttempts = 0
    
    // MARK: - Computed Properties for Compatibility
    var connectedPeripheralID: UUID? {
        return peripheral?.identifier
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        addDebugLog("🚀 UWB BLE Manager initialized (Qorvo Protocol)")
    }
    
    private func updateProtocolState(_ newState: String) {
        DispatchQueue.main.async {
            self.protocolState = newState
        }
    }
    
    // MARK: - Public Methods
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            addDebugLog("❌ Cannot scan - Bluetooth not powered on")
            return
        }
        
        discoveredPeripherals.removeAll()
        isScanning = true
        updateProtocolState("Scanning")
        addDebugLog("🔍 Scanning for Qorvo UWB devices...")
        
        // Scan for both service UUIDs
        centralManager.scanForPeripherals(
            withServices: [transferServiceUUID, qorvoServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        addDebugLog("⏹️ Stopped scanning")
    }
    
    func connect(to peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self
        protocolState = "Connecting"
        centralManager.connect(peripheral, options: nil)
        addDebugLog("🔗 Connecting to: \(peripheral.name ?? "Unknown")")
        connectionStatus = "Connecting..."
    }
    
    func disconnect() {
        protocolState = "Disconnecting"
        
        // Send stop command if connected
        if isConnected {
            sendMessage(.stop)
        }
        
        // Clean up UWB session
        if niSession != nil {
            niSession?.invalidate()
            niSession = nil
            isRanging = false
            uwbLocation.isValid = false
        }
        
        guard let peripheral = peripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
        addDebugLog("🔌 Disconnecting from device")
    }
    
    func readRSSI() {
        peripheral?.readRSSI()
    }
    
    func retryUWBInitialization() {
        guard isConnected else {
            addDebugLog("❌ Cannot retry - not connected")
            return
        }
        
        addDebugLog("🔄 Retrying UWB initialization...")
        configurationAttempts = 0
        
        // Clean up existing session
        niSession?.invalidate()
        niSession = nil
        isRanging = false
        protocolState = "Retrying"
        
        // Start fresh
        startUWBProtocol()
    }
    
    // MARK: - UWB Protocol Methods
    private func startUWBProtocol() {
        protocolState = "Initializing UWB"
        configurationAttempts += 1
        
        // Create new NI session
        niSession = NISession()
        niSession?.delegate = self
        addDebugLog("🎯 Created new NISession")
        
        // Send initialize command
        addDebugLog("📤 Sending INITIALIZE (0x0A) to start protocol...")
        sendMessage(.initialize)
    }
    
    // MARK: - Message Handling
    private func sendMessage(_ messageId: MessageId, data: Data? = nil) {
        guard let characteristic = rxCharacteristic else {
            addDebugLog("❌ Cannot send - no RX characteristic")
            return
        }
        
        var message = Data([messageId.rawValue])
        if let data = data {
            message.append(data)
        }
        
        lastMessageSent = messageId
        
        let hexString = message.map { String(format: "%02X", $0) }.joined(separator: " ")
        addDebugLog("📤 TX: \(messageId) [\(hexString)]")
        
        peripheral?.writeValue(message, for: characteristic, type: .withResponse)
    }
    
    private func handleReceivedData(_ data: Data) {
        guard data.count > 0 else {
            addDebugLog("❌ Received empty data")
            return
        }
        
        let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        addDebugLog("📥 RX: [\(hexString)]")
        
        guard let messageId = MessageId(rawValue: data[0]) else {
            addDebugLog("❌ Unknown message ID: 0x\(String(format: "%02X", data[0]))")
            return
        }
        
        addDebugLog("📥 Message: \(messageId) (0x\(String(format: "%02X", messageId.rawValue)))")
        
        switch messageId {
        case .accessoryConfigurationData:
            protocolState = "Received Config"
            addDebugLog("✅ Received UWB configuration from accessory")
            
            if data.count > 1 {
                let configData = data.advanced(by: 1)
                addDebugLog("   Config size: \(configData.count) bytes")
                handleConfigurationData(configData)
            } else {
                addDebugLog("❌ Configuration data is empty!")
            }
            
        case .accessoryUwbDidStart:
            protocolState = "UWB Active"
            addDebugLog("🎉 Accessory confirmed UWB started!")
            isRanging = true
            
        case .accessoryUwbDidStop:
            protocolState = "UWB Stopped"
            addDebugLog("⏹️ Accessory stopped UWB")
            isRanging = false
            uwbLocation.isValid = false
            
        default:
            addDebugLog("❓ Unexpected message from accessory")
        }
    }
    
    private func handleConfigurationData(_ configData: Data) {
        do {
            addDebugLog("🔧 Creating NINearbyAccessoryConfiguration...")
            configuration = try NINearbyAccessoryConfiguration(data: configData)
            configuration?.isCameraAssistanceEnabled = true
            accessoryDiscoveryToken = configuration?.accessoryDiscoveryToken
            
            addDebugLog("✅ Configuration created successfully")
            
            guard let config = configuration else {
                addDebugLog("❌ Configuration is nil after creation")
                return
            }
            
            // Ensure we have a valid session
            if niSession == nil {
                addDebugLog("⚠️ No NISession - creating one")
                niSession = NISession()
                niSession?.delegate = self
            }
            
            addDebugLog("🏃 Running NISession with configuration...")
            niSession?.run(config)
            
            protocolState = "Waiting for Shareable Config"
            addDebugLog("⏳ Waiting for iOS to generate shareable config...")
            
        } catch {
            addDebugLog("❌ Configuration error: \(error)")
            protocolState = "Config Error"
            
            if configurationAttempts < 3 {
                addDebugLog("🔄 Retrying initialization (attempt \(configurationAttempts + 1)/3)...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.startUWBProtocol()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func addDebugLog(_ message: String) {
        let timestamp = DateFormatter.timestamp.string(from: Date())
        let logMessage = "\(timestamp): \(message)"
        DispatchQueue.main.async {
            self.debugLog.append(logMessage)
            if self.debugLog.count > 100 {
                self.debugLog.removeFirst()
            }
        }
        print(logMessage)
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            addDebugLog("✅ Bluetooth powered on")
        case .poweredOff:
            addDebugLog("❌ Bluetooth powered off")
            protocolState = "BLE Off"
        default:
            addDebugLog("⚠️ Bluetooth state: \(central.state.rawValue)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any], rssi RSSI: NSNumber) {
        addDebugLog("📱 Found: \(peripheral.name ?? "Unknown") RSSI: \(RSSI)")
        
        if !discoveredPeripherals.contains(peripheral) {
            discoveredPeripherals.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        addDebugLog("✅ Connected to: \(peripheral.name ?? "Unknown")")
        connectionStatus = "Connected"
        isConnected = true
        protocolState = "BLE Connected"
        stopScanning()
        
        // Discover services
        addDebugLog("🔍 Discovering services...")
        peripheral.discoverServices([transferServiceUUID, qorvoServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        addDebugLog("❌ Connection failed: \(error?.localizedDescription ?? "Unknown")")
        connectionStatus = "Failed"
        protocolState = "Connection Failed"
        isConnected = false
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        addDebugLog("🔌 Disconnected: \(peripheral.name ?? "Unknown")")
        
        // Clean up
        connectionStatus = "Disconnected"
        protocolState = "Disconnected"
        isConnected = false
        isRanging = false
        self.peripheral = nil
        rxCharacteristic = nil
        txCharacteristic = nil
        rssi = 0
        configurationAttempts = 0
        
        // Clean up UWB
        niSession?.invalidate()
        niSession = nil
        uwbLocation.isValid = false
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            addDebugLog("❌ Service discovery error: \(error)")
            return
        }
        
        guard let services = peripheral.services else {
            addDebugLog("❌ No services found")
            return
        }
        
        addDebugLog("📋 Found \(services.count) services")
        
        for service in services {
            addDebugLog("   Service: \(service.uuid)")
            
            if service.uuid == transferServiceUUID {
                peripheral.discoverCharacteristics([rxCharacteristicUUID, txCharacteristicUUID], for: service)
            } else if service.uuid == qorvoServiceUUID {
                peripheral.discoverCharacteristics([qorvoRxUUID, qorvoTxUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            addDebugLog("❌ Characteristic discovery error: \(error)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        addDebugLog("📋 Found \(characteristics.count) characteristics for service \(service.uuid)")
        
        for characteristic in characteristics {
            // Handle both standard and Qorvo UUIDs
            if characteristic.uuid == rxCharacteristicUUID || characteristic.uuid == qorvoRxUUID {
                rxCharacteristic = characteristic
                addDebugLog("✅ Found RX characteristic")
            } else if characteristic.uuid == txCharacteristicUUID || characteristic.uuid == qorvoTxUUID {
                txCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                addDebugLog("✅ Found TX characteristic, enabled notifications")
            }
        }
        
        // Start UWB protocol after discovering characteristics
        if rxCharacteristic != nil && txCharacteristic != nil {
            addDebugLog("🚀 All characteristics ready - starting UWB protocol")
            protocolState = "Characteristics Ready"
            
            // Small delay to ensure everything is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startUWBProtocol()
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            addDebugLog("❌ Value update error: \(error)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        // Handle protocol messages
        handleReceivedData(data)
        
        // Read RSSI
        peripheral.readRSSI()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            addDebugLog("❌ Write failed: \(error)")
        } else {
            addDebugLog("✅ Write successful")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if error == nil {
            DispatchQueue.main.async {
                self.rssi = RSSI.intValue
            }
        }
    }
}

// MARK: - NISessionDelegate
extension BLEManager: NISessionDelegate {
    func session(_ session: NISession, didGenerateShareableConfigurationData shareableConfigurationData: Data, for object: NINearbyObject) {
        guard object.discoveryToken == accessoryDiscoveryToken else {
            addDebugLog("❌ Token mismatch in shareable config")
            return
        }
        
        protocolState = "Sending Shareable Config"
        addDebugLog("📤 iOS generated shareable config (\(shareableConfigurationData.count) bytes)")
        addDebugLog("📤 Sending CONFIGURE_AND_START (0x0B) with config...")
        
        sendMessage(.configureAndStart, data: shareableConfigurationData)
    }
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else { return }
        
        DispatchQueue.main.async {
            var updated = false
            
            if let distance = object.distance {
                self.uwbLocation.distance = distance
                updated = true
            }
            
            if let direction = object.direction {
                self.uwbLocation.direction = direction
                self.uwbLocation.azimuth = atan2(direction.x, direction.z) * 180 / .pi
                self.uwbLocation.elevation = asin(direction.y) * 180 / .pi
                updated = true
            }
            
            if updated {
                self.uwbLocation.timestamp = Date()
                self.uwbLocation.isValid = true
                self.addDebugLog("📍 D: \(String(format: "%.2f", self.uwbLocation.distance))m, Az: \(String(format: "%.0f", self.uwbLocation.azimuth))°")
            }
        }
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        addDebugLog("⚠️ Object removed - Reason: \(reason)")
        
        if reason == .timeout {
            protocolState = "Session Timeout"
            addDebugLog("⏰ Session timeout - reinitializing...")
            sendMessage(.initialize)
        }
    }
    
    func sessionWasSuspended(_ session: NISession) {
        protocolState = "Session Suspended"
        addDebugLog("⏸️ Session suspended")
        sendMessage(.stop)
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        protocolState = "Session Resumed"
        addDebugLog("▶️ Session resumed")
        sendMessage(.initialize)
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        protocolState = "Session Invalid"
        addDebugLog("❌ Session invalidated: \(error)")
        isRanging = false
        uwbLocation.isValid = false
    }
}

