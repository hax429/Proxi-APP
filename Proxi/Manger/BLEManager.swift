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
import ARKit
import simd
import CoreLocation

// MARK: - BLE Settings Helper (temporary)
class BLESettings {
    var isDirectionEnable: Bool {
        // Check device capabilities - iPhone 14+ supports directional features
        return true // You can implement actual device checking here
    }
}

// MARK: - BLE Message Protocol (Qorvo)
enum BLEMessageId: UInt8 {
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
    var horizontalAngle: Float = 0
    var verticalDirectionEstimate: Int = 0
    var isValid: Bool = false
    var timestamp: Date = Date()
    var noUpdate: Bool = false
    var isConverged: Bool = false
    var supportsDirectionMeasurement: Bool = false
    
    // Calibration offset for coordinate system alignment and device heading integration
    var azimuthOffset: Float = 0.0
    var deviceHeading: Float = 0.0  // Current device magnetic heading
    
    // IMPROVED: Enhanced direction calculations with device heading integration
    var enhancedAzimuth: Float {
        // For iPhone 14+, use horizontal angle when available and converged
        if !supportsDirectionMeasurement && isConverged && horizontalAngle != 0 {
            // Qorvo approach: Convert horizontal angle to degrees
            let targetAzimuth = horizontalAngle * 180 / .pi
            // Apply coordinate system correction (NI uses different reference than magnetic compass)
            let correctedAzimuth = targetAzimuth + 90.0  // NI angle correction
            return normalizeAngle(correctedAzimuth)
        }
        
        // Standard calculation for devices with direction support
        if direction.x != 0 || direction.z != 0 {
            // Calculate azimuth from 3D direction vector
            let targetAzimuth = atan2(direction.x, direction.z) * 180 / .pi
            // Apply coordinate system correction  
            let correctedAzimuth = targetAzimuth + 90.0  // NI angle correction
            return normalizeAngle(correctedAzimuth)
        }
        
        return 0
    }
    
    var enhancedElevation: Float {
        // For iPhone 14+, use vertical direction estimate when converged
        if !supportsDirectionMeasurement && isConverged {
            return Float(verticalDirectionEstimate)
        }
        
        // Standard calculation for full direction support
        if direction.y != 0 || (direction.x != 0 || direction.z != 0) {
            let elevationRad = atan2(direction.y, sqrt(direction.x * direction.x + direction.z * direction.z))
            return elevationRad * 180 / .pi
        }
        
        return 0
    }
    
    var calibratedAzimuth: Float {
        return enhancedAzimuth
    }
    
    // MARK: - Relative bearing calculation (target azimuth relative to device heading)
    var relativeBearing: Float {
        let targetAzimuth = enhancedAzimuth
        let deviceHeadingFloat = deviceHeading
        
        // Calculate relative bearing
        var bearing = targetAzimuth - deviceHeadingFloat
        
        // Normalize to -180 to 180 range
        return normalizeAngle(bearing)
    }
    
    // Normalize angle to -180 to 180 degrees
    private func normalizeAngle(_ angle: Float) -> Float {
        var normalized = angle
        while normalized > 180 {
            normalized -= 360
        }
        while normalized < -180 {
            normalized += 360
        }
        return normalized
    }
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
    
    // MARK: - AR Session Properties (for enhanced positioning)
    private var arSession: ARSession?
    private var isARSessionEnabled = false
    
    // MARK: - Location Manager for Device Heading
    private var locationManager: LocationManager?
    
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
    private var lastMessageSent: BLEMessageId?
    private var configurationAttempts = 0
    private var isConverged = false
    private var algorithmConvergenceStatus: String = "Not Started"
    
    // Device capabilities
    private var supportsDirectionMeasurement: Bool = false
    
    // MARK: - Computed Properties for Compatibility
    var connectedPeripheralID: UUID? {
        return peripheral?.identifier
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // Initialize location manager for device heading
        locationManager = LocationManager()
        
        checkDeviceCapabilities()
        addDebugLog("🚀 UWB BLE Manager initialized (Qorvo Protocol)")
    }
    
    private func checkDeviceCapabilities() {
        let capabilities = NISession.deviceCapabilities
        supportsDirectionMeasurement = capabilities.supportsDirectionMeasurement
        
        addDebugLog("📱 Device Capabilities:")
        addDebugLog("   Direction support: \(supportsDirectionMeasurement)")
        
        // Device type detection
        if !supportsDirectionMeasurement {
            addDebugLog("⚠️ iPhone 14+ detected - direction requires convergence")
            addDebugLog("   Will use horizontal angle when converged")
        } else {
            addDebugLog("✅ iPhone 11-13 detected - full direction support")
            addDebugLog("   Will use 3D direction vectors directly")
        }
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
        
        // Don't destroy AR session - keep it running for next connection
        // This prevents the 1-minute initialization gap
        if isARSessionEnabled {
            addDebugLog("📷 AR session kept running for next connection")
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
        
        addDebugLog("🔄 Retrying UWB initialization (attempt \(configurationAttempts + 1))...")
        
        // Clean up existing session completely
        if let niSession = niSession {
            niSession.invalidate()
            self.niSession = nil
        }
        
        // Reset AR session if it was problematic
        if isARSessionEnabled {
            isARSessionEnabled = false
            arSession?.pause()
            arSession = nil
            addDebugLog("📷 AR session reset for retry")
        }
        
        isRanging = false
        protocolState = "Retrying"
        
        // Wait a moment for cleanup to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startUWBProtocol()
        }
    }
    
    // MARK: - UWB Protocol Methods
    private func startUWBProtocol() {
        protocolState = "Initializing UWB"
        configurationAttempts += 1
        
        // Create new NI session
        niSession = NISession()
        niSession?.delegate = self
        addDebugLog("🎯 Created new NISession")
        
        // Start preparing AR session early to allow stabilization time
        if ARWorldTrackingConfiguration.isSupported {
            setupARSessionIfAvailable()
        }
        
        // Send initialize command
        addDebugLog("📤 Sending INITIALIZE (0x0A) to start protocol...")
        sendMessage(.initialize)
    }
    
    // MARK: - Enhanced AR Session Setup (following Qorvo best practices)
    private func setupARSessionIfAvailable() {
        guard ARWorldTrackingConfiguration.isSupported else {
            addDebugLog("⚠️ AR World Tracking not supported on this device")
            return
        }
        
        // Create AR session early but don't link until UWB is fully active
        // This prevents the INVALID_AR_SESSION_DESCRIPTION error
        if arSession == nil {
            arSession = ARSession()
            addDebugLog("📷 AR Session created for enhanced positioning")
            
            let configuration = ARWorldTrackingConfiguration()
            configuration.worldAlignment = .gravity  // Critical for direction accuracy
            configuration.isCollaborationEnabled = false
            configuration.userFaceTrackingEnabled = false
            configuration.initialWorldMap = nil
            configuration.isLightEstimationEnabled = true
            
            // Start AR session immediately to begin stabilization
            arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            addDebugLog("📷 AR Session started - will link after UWB confirmation...")
        }
    }
    
    // MARK: - Link AR to NI Session (called when NI session is ready)
    private func linkARSessionToNI() {
        guard let arSession = arSession, let niSession = niSession else {
            addDebugLog("⚠️ Cannot link - AR or NI session not available")
            return
        }
        
        // Only link if configuration is ready and we're not already linked
        guard !isARSessionEnabled && isRanging else {
            if isARSessionEnabled {
                addDebugLog("⚠️ AR Session already linked")
            } else if !isRanging {
                addDebugLog("⚠️ Cannot link AR - UWB not yet active")
            }
            return
        }
        
        // Ensure AR session has had time to stabilize
        addDebugLog("📷 Linking AR session to stabilized NI session...")
        
        do {
            // Link AR session to NI session with error handling
            niSession.setARSession(arSession)
            isARSessionEnabled = true
            addDebugLog("✅ AR Session successfully linked to NI Session")
        } catch {
            addDebugLog("❌ Failed to link AR session: \(error.localizedDescription)")
            // Continue without AR enhancement
        }
    }
    
    func enableAREnhancedPositioning(_ enable: Bool) {
        if enable && !isARSessionEnabled {
            setupARSessionIfAvailable()
        } else if !enable && isARSessionEnabled {
            arSession?.pause()
            arSession = nil
            isARSessionEnabled = false
            addDebugLog("📷 AR Session disabled")
            
            // Note: We don't call setARSession(nil) since it's not supported
            // The NI session will continue without AR enhancement
        }
    }
    
    // MARK: - Message Handling
    private func sendMessage(_ messageId: BLEMessageId, data: Data? = nil) {
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
        
        guard let messageId = BLEMessageId(rawValue: data[0]) else {
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
            
            // Now that UWB is confirmed active, link AR session if available and ready
            if ARWorldTrackingConfiguration.isSupported && !isARSessionEnabled && arSession != nil {
                addDebugLog("📷 UWB active - linking prepared AR session...")
                // Give a moment for any final AR stabilization
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.linkARSessionToNI()
                }
            } else if ARWorldTrackingConfiguration.isSupported && arSession == nil {
                addDebugLog("⚠️ AR session not ready - continuing with UWB only")
            }
            
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
            // Only enable camera assistance if AR session will be available
            configuration?.isCameraAssistanceEnabled = ARWorldTrackingConfiguration.isSupported
            accessoryDiscoveryToken = configuration?.accessoryDiscoveryToken
            
            if ARWorldTrackingConfiguration.isSupported {
                addDebugLog("📷 Camera assistance will be enabled")
            } else {
                addDebugLog("⚠️ Camera assistance disabled - AR not supported")
            }
            
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
    
    // MARK: - Helper Methods (Qorvo approach)
    private func getDirectionFromHorizontalAngle(rad: Float) -> simd_float3 {
        addDebugLog("🔄 Converting horizontal angle: \(String(format: "%.1f°", rad * 180 / .pi))")
        // Qorvo reference implementation
        return simd_float3(x: sin(rad), y: 0, z: cos(rad))
    }
    
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
    
    // MARK: - Public Properties for Enhanced Access
    var convergenceStatus: String {
        return algorithmConvergenceStatus
    }
    
    var enhancedUWBLocation: UWBLocation {
        return uwbLocation
    }
    
    var arEnhancedPositioning: Bool {
        return isARSessionEnabled
    }
    
    // MARK: - Enhanced Direction Access Methods
    func getRelativeBearing() -> Float {
        return uwbLocation.relativeBearing
    }
    
    func getAbsoluteAzimuth() -> Float {
        return uwbLocation.enhancedAzimuth
    }
    
    func getDeviceHeading() -> Float {
        return uwbLocation.deviceHeading
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
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
        
        // Keep AR session running (Qorvo approach) - prevents re-initialization delays
        if isARSessionEnabled {
            addDebugLog("📷 AR session kept running for reconnection")
        }
        arSession = nil
        isARSessionEnabled = false
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
        
        // ALWAYS log raw data for debugging
        let rawDistance = object.distance?.description ?? "nil"
        let rawDirection = object.direction?.debugDescription ?? "nil"
        let rawHorizontalAngle = object.horizontalAngle?.description ?? "nil"
        let rawVerticalEstimate = String(describing: object.verticalDirectionEstimate)
        
        addDebugLog("🔍 RAW DATA - Distance: \(rawDistance), Direction: \(rawDirection), HAngle: \(rawHorizontalAngle), VEstimate: \(rawVerticalEstimate)")
        
        DispatchQueue.main.async {
            // Always update distance
            if let distance = object.distance {
                self.uwbLocation.distance = distance
                self.addDebugLog("📏 Distance: \(String(format: "%.3f", distance))m")
            }
            
            // Update device capabilities and heading in location
            self.uwbLocation.supportsDirectionMeasurement = self.supportsDirectionMeasurement
            
            // Update device heading from location manager
            if let locationManager = self.locationManager {
                self.uwbLocation.deviceHeading = Float(locationManager.deviceHeading)
            }
            
            // Handle direction based on device capabilities and convergence
            if let direction = object.direction {
                // iPhone 11-13 with full direction support
                self.uwbLocation.direction = direction
                let oldAzimuth = self.uwbLocation.azimuth
                let oldElevation = self.uwbLocation.elevation
                
                self.uwbLocation.azimuth = self.uwbLocation.enhancedAzimuth
                self.uwbLocation.elevation = self.uwbLocation.enhancedElevation
                self.uwbLocation.noUpdate = false
                
                self.addDebugLog("📍 3D Direction: x=\(String(format: "%.6f", direction.x)), y=\(String(format: "%.6f", direction.y)), z=\(String(format: "%.6f", direction.z))")
                self.addDebugLog("📍 Direction Az: \(String(format: "%.1f", self.uwbLocation.azimuth))°, El: \(String(format: "%.1f", self.uwbLocation.elevation))° (was Az: \(String(format: "%.1f", oldAzimuth))°)")
                
            } else if self.isConverged, let horizontalAngle = object.horizontalAngle {
                // iPhone 14+ fallback when converged (Qorvo approach)
                self.uwbLocation.horizontalAngle = horizontalAngle
                
                // Use Qorvo's direction conversion approach
                let syntheticDirection = self.getDirectionFromHorizontalAngle(rad: horizontalAngle)
                self.uwbLocation.direction = syntheticDirection
                
                // Calculate azimuth and elevation using enhanced methods
                self.uwbLocation.azimuth = self.uwbLocation.enhancedAzimuth
                
                // Get vertical estimate (Qorvo approach)
                let verticalEstimate = object.verticalDirectionEstimate
                self.uwbLocation.verticalDirectionEstimate = verticalEstimate.rawValue
                self.uwbLocation.elevation = Float(verticalEstimate.rawValue)
                
                self.uwbLocation.noUpdate = false
                
                self.addDebugLog("📍 Converged Direction: HAngle: \(String(format: "%.3f", horizontalAngle))rad = \(String(format: "%.1f", horizontalAngle * 180 / .pi))°, VEst: \(verticalEstimate)")
                
            } else {
                // No direction available
                self.uwbLocation.noUpdate = true
                
                if !self.isConverged {
                    if self.uwbLocation.distance < 1.0 {
                        self.addDebugLog("📱 Move away from target - too close for direction")
                    } else {
                        self.addDebugLog("🚶 Move device in figure-8 patterns for convergence")
                    }
                } else {
                    self.addDebugLog("💡 Need better lighting conditions for direction")
                }
            }
            
            // Always update timestamp and validity if we have any data
            if !self.uwbLocation.noUpdate || self.uwbLocation.distance > 0 {
                self.uwbLocation.timestamp = Date()
                self.uwbLocation.isValid = true
                self.uwbLocation.isConverged = self.isConverged
                
                let azimuthDeg = self.uwbLocation.azimuth
                let elevationDeg = self.uwbLocation.elevation
                let relativeBearing = self.uwbLocation.relativeBearing
                let deviceHead = self.uwbLocation.deviceHeading
                
                self.addDebugLog("📍 Final: D: \(String(format: "%.2f", self.uwbLocation.distance))m, Az: \(String(format: "%.1f", azimuthDeg))°, El: \(String(format: "%.1f", elevationDeg))°")
                self.addDebugLog("🧭 Device: \(String(format: "%.1f", deviceHead))° → Target: \(String(format: "%.1f", azimuthDeg))° (Relative: \(String(format: "%.1f", relativeBearing))°)")
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
        addDebugLog("⏸️ Session suspended - app backgrounded or camera permission issue")
        // Don't automatically stop - let it resume naturally
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        protocolState = "Session Resumed"
        addDebugLog("▶️ Session resumed")
        sendMessage(.initialize)
    }
    
    func session(_ session: NISession, didUpdateAlgorithmConvergence convergence: NIAlgorithmConvergence, for object: NINearbyObject?) {
        guard object != nil else { return }
        
        DispatchQueue.main.async {
            switch convergence.status {
            case .converged:
                self.isConverged = true
                self.algorithmConvergenceStatus = "Converged"
                self.addDebugLog("✅ Algorithm converged - accurate direction available")
                self.protocolState = "UWB Converged"
                
                // Update UWB location with device capabilities
                self.uwbLocation.supportsDirectionMeasurement = self.supportsDirectionMeasurement
                
            case .notConverged(let reasons):
                self.isConverged = false
                
                if reasons.contains(.insufficientLighting) {
                    self.algorithmConvergenceStatus = "Need Better Lighting"
                    self.addDebugLog("💡 Move to brighter area for convergence")
                } else if reasons.contains(.insufficientMovement) {
                    self.algorithmConvergenceStatus = "Need Movement"
                    self.addDebugLog("🚶 Move device in slow figure-8 patterns")
                } else {
                    self.algorithmConvergenceStatus = "Converging..."
                    self.addDebugLog("🔄 Keep moving device slowly for convergence")
                }
                
                // Always update device capabilities
                self.uwbLocation.supportsDirectionMeasurement = self.supportsDirectionMeasurement
                
            @unknown default:
                self.algorithmConvergenceStatus = "Unknown"
                self.addDebugLog("❓ Unknown convergence status")
            }
        }
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        protocolState = "Session Invalid"
        addDebugLog("❌ Session invalidated: \(error)")
        isRanging = false
        isConverged = false
        uwbLocation.isValid = false
        
        // Handle specific error cases
        if let niError = error as? NIError {
            switch niError.code {
            case .userDidNotAllow:
                addDebugLog("🚫 User denied Nearby Interaction access")
                addDebugLog("💡 Enable location and camera permissions in Settings")
            case .invalidConfiguration:
                addDebugLog("⚙️ Invalid configuration - retrying initialization")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if self.isConnected {
                        self.retryUWBInitialization()
                    }
                }
            case .resourceUsageTimeout:
                addDebugLog("⏰ Resource timeout - will retry on reconnection")
            case .activeSessionsLimitExceeded:
                addDebugLog("📱 Too many active NI sessions - cleanup and retry")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.retryUWBInitialization()
                }
            default:
                addDebugLog("❌ NI Error (\(niError.code.rawValue)): \(niError.localizedDescription)")
                
                // For AR session errors, retry without AR
                if niError.localizedDescription.contains("AR") || niError.code.rawValue == -5883 {
                    addDebugLog("📷 AR session error detected - retrying UWB without AR...")
                    isARSessionEnabled = false
                    arSession?.pause()
                    arSession = nil
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if self.isConnected {
                            self.retryUWBInitialization()
                        }
                    }
                }
            }
        } else {
            addDebugLog("❌ Unknown session error: \(error.localizedDescription)")
        }
    }
}
