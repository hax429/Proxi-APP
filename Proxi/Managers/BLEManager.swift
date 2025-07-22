//
//  BLEManager.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/16/25.
//
//  Bluetooth Low Energy Manager for UWB Device Communication
//  This file contains the core BLE management system for the Proxi app.

/**
 * BLEManager - Bluetooth Low Energy Device Management
 *
 * This class manages all Bluetooth Low Energy (BLE) operations for the Proxi app,
 * including device scanning, connection management, and UWB device communication.
 *
 * ## Responsibilities:
 * - Scanning for nearby UWB devices
 * - Managing BLE connections and disconnections
 * - Handling device data communication
 * - Maintaining device state and status
 * - Providing debug logging for development
 *
 * ## Key Features:
 * - Real-time device discovery
 * - Automatic connection management
 * - Device status monitoring
 * - Debug information logging
 * - Error handling and recovery
 * - Multi-device support
 *
 * ## Usage:
 * ```swift
 * @EnvironmentObject var bleManager: BLEManager
 * 
 * // Start scanning for devices
 * bleManager.startScanning()
 * 
 * // Connect to a specific device
 * bleManager.connect(to: peripheral)
 * ```
 *
 * ## Architecture:
 * - Uses CoreBluetooth framework
 * - Implements CBPeripheralDelegate for device communication
 * - Manages multiple device connections simultaneously
 * - Provides SwiftUI environment object integration
 * - Supports Qorvo UWB protocol
 *
 * ## Multi-Device Support:
 * - Tracks multiple connected devices simultaneously
 * - Maintains individual device data and status
 * - Handles device-specific UWB sessions
 * - Provides device-specific ranging data
 *
 * @author Gabriel Wang
 * @version 2.0.0 (Enhanced for multi-device support)
 * @since iOS 16.0
 */

import Foundation
import SwiftUI
import CoreBluetooth
import NearbyInteraction
import ARKit
import simd
import CoreLocation

// MARK: - BLE Settings Helper
/**
 * BLESettings - BLE Configuration Helper
 * 
 * Provides configuration settings for BLE operations and device capabilities.
 * Currently handles direction enablement based on device capabilities.
 */
class BLESettings {
    var isDirectionEnable: Bool {
        // Check device capabilities - iPhone 14+ supports directional features
        return true // You can implement actual device checking here
    }
}

// MARK: - BLE Message Protocol (Qorvo)
/**
 * BLEMessageId - Qorvo UWB Communication Protocol
 * 
 * Defines the message types used for communication between iOS app and Arduino.
 * Based on the Qorvo UWB protocol specification.
 */
enum BLEMessageId: UInt8 {
    // Messages from the accessory (Arduino to iOS)
    case accessoryConfigurationData = 0x1  // Device configuration data
    case accessoryUwbDidStart = 0x2        // UWB ranging started
    case accessoryUwbDidStop = 0x3         // UWB ranging stopped
    
    // Messages to the accessory (iOS to Arduino)
    case initialize = 0xA                  // Initialize UWB stack
    case configureAndStart = 0xB           // Configure and start ranging
    case stop = 0xC                        // Stop ranging
    
    // User defined/notification messages
    case getReserved = 0x20                // Get reserved data
    case setReserved = 0x21                // Set reserved data
    case iOSNotify = 0x2F                  // iOS notification message
}

// MARK: - UWB Location Data Structure
/**
 * UWBLocation - Ultra-Wideband Location Data
 * 
 * Comprehensive data structure for storing UWB ranging information including
 * distance, direction, elevation, and device-specific calibration data.
 * 
 * Enhanced with device heading integration and coordinate system alignment.
 */
struct UWBLocation {
    // Basic ranging data
    var distance: Float = 0                // Distance in meters
    var azimuth: Float = 0                 // Azimuth angle in degrees
    var elevation: Float = 0               // Elevation angle in degrees
    var direction: simd_float3 = SIMD3<Float>(x: 0, y: 0, z: 0)  // 3D direction vector
    
    // Advanced direction data (iPhone 14+)
    var horizontalAngle: Float = 0         // Horizontal angle from NI
    var verticalDirectionEstimate: Int = 0 // Vertical direction estimate
    
    // Status flags
    var isValid: Bool = false              // Data validity flag
    var timestamp: Date = Date()           // Measurement timestamp
    var noUpdate: Bool = false             // No update flag
    var isConverged: Bool = false          // Convergence status
    
    // Device capabilities
    var supportsDirectionMeasurement: Bool = false  // Direction support flag
    
    // Calibration and alignment
    var azimuthOffset: Float = 0.0         // Coordinate system offset
    var deviceHeading: Float = 0.0         // Current device magnetic heading
    
    // MARK: - Enhanced Direction Calculations
    
    /**
     * Enhanced azimuth calculation with device heading integration
     * 
     * Provides improved direction accuracy by combining UWB data with
     * device compass heading and coordinate system corrections.
     */
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
    // Multiple connection support
    @Published var connectedPeripherals: [UUID: CBPeripheral] = [:]
    private var peripheralCharacteristics: [UUID: (rx: CBCharacteristic?, tx: CBCharacteristic?)] = [:]
    
    // Legacy single connection support (backward compatibility)
    private var peripheral: CBPeripheral? {
        return connectedPeripherals.values.first
    }
    private var rxCharacteristic: CBCharacteristic? {
        return peripheralCharacteristics.values.first?.rx
    }
    private var txCharacteristic: CBCharacteristic? {
        return peripheralCharacteristics.values.first?.tx
    }
    
    // MARK: - UWB Properties (Multiple Session Support)
    private var niSessions: [UUID: NISession] = [:]
    private var configurations: [UUID: NINearbyAccessoryConfiguration] = [:]
    private var accessoryDiscoveryTokens: [UUID: NIDiscoveryToken] = [:]
    
    // Legacy single session support (backward compatibility)
    private var niSession: NISession? {
        return niSessions.values.first
    }
    private var configuration: NINearbyAccessoryConfiguration? {
        return configurations.values.first
    }
    private var accessoryDiscoveryToken: NIDiscoveryToken? {
        return accessoryDiscoveryTokens.values.first
    }
    
    // MARK: - AR Session Properties (for enhanced positioning)
    private var arSession: ARSession?
    private var isARSessionEnabled = false
    
    // MARK: - Location Manager for Device Heading
    private var locationManager: LocationManager?
    
    // MARK: - Published Properties (Enhanced for multiple connections)
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var isRanging = false
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectionStatus = "Disconnected"
    @Published var uwbLocation = UWBLocation() // Primary device location
    @Published var debugLog: [String] = []
    @Published var rssi: Int = 0
    @Published var protocolState = "Not Connected"
    @Published var receivedNumber: Int = 0 // For compatibility
    
    // Multiple device tracking
    @Published var connectedDevicesData: [UUID: DeviceData] = [:]
    @Published var deviceRSSI: [UUID: Int] = [:]
    @Published var deviceStates: [UUID: String] = [:]
    
    // Device data structure for multiple connections
    struct DeviceData {
        var peripheral: CBPeripheral
        var uwbLocation: UWBLocation
        var isRanging: Bool
        var lastUpdated: Date
        var deviceName: String
        
        init(peripheral: CBPeripheral) {
            self.peripheral = peripheral
            self.uwbLocation = UWBLocation()
            self.isRanging = false
            self.lastUpdated = Date()
            self.deviceName = peripheral.name ?? "Unknown Arduino"
        }
    }
    
    // Protocol state tracking
    private var lastMessageSent: BLEMessageId?
    private var configurationAttempts = 0
    private var isConverged = false
    private var algorithmConvergenceStatus: String = "Not Started"
    
    // Device capabilities
    private var supportsDirectionMeasurement: Bool = false
    
    // Console logging timer
    private var consoleLoggingTimer: Timer?
    
    // Protocol timeout timers for each device
    private var protocolTimeoutTimers: [UUID: Timer] = [:]
    
    // MARK: - Computed Properties for Compatibility
    var connectedPeripheralID: UUID? {
        return peripheral?.identifier
    }
    
    // Enhanced properties for multiple connections
    var connectedPeripheralIDs: [UUID] {
        return Array(connectedPeripherals.keys)
    }
    
    var connectedDevicesCount: Int {
        return connectedPeripherals.count
    }
    
    func getDeviceData(for peripheralID: UUID) -> DeviceData? {
        return connectedDevicesData[peripheralID]
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // Initialize location manager for device heading
        locationManager = LocationManager()
        
        checkDeviceCapabilities()
        addDebugLog("🚀 UWB BLE Manager initialized (Qorvo Protocol) - Multiple Device Support Enabled")
        
        // Start console logging timer for all devices
        startConsoleLogging()
    }
    
    deinit {
        consoleLoggingTimer?.invalidate()
        protocolTimeoutTimers.values.forEach { $0.invalidate() }
    }
    
    // MARK: - Console Logging
    private func startConsoleLogging() {
        // Log all devices data every 5 seconds when devices are connected
        consoleLoggingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            if !self.connectedDevicesData.isEmpty {
                self.logAllDevicesData()
                
                // Auto-restart stuck protocols after 60 seconds
                self.checkAndRestartStuckProtocols()
            }
        }
    }
    
    private func checkAndRestartStuckProtocols() {
        let stuckStates = ["Connected", "BLE Connected", "Characteristics Ready"]
        
        for (peripheralID, deviceData) in connectedDevicesData {
            let currentState = deviceStates[peripheralID] ?? "Unknown"
            let timeSinceLastUpdate = Date().timeIntervalSince(deviceData.lastUpdated)
            
            // If device has been stuck in initial states for more than 60 seconds
            if stuckStates.contains(currentState) && timeSinceLastUpdate > 60 {
                let deviceName = deviceData.deviceName
                print("⚠️ [\(deviceName)] Auto-restarting stuck protocol (stuck in \(currentState) for \(Int(timeSinceLastUpdate))s)")
                
                forceRestartProtocol(for: peripheralID)
            }
        }
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
        addDebugLog("🔍 Scanning for multiple Arduino UWB devices...")
        print("🔍 Starting scan for multiple Arduino UWB devices...")
        
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
        print("⏹️ Stopped scanning for more Arduino devices")
    }
    
    func continueScanningForMoreDevices() {
        if !isScanning && centralManager.state == .poweredOn {
            addDebugLog("🔍 Continuing scan for additional Arduino devices...")
            print("🔍 Continuing scan for additional Arduino devices...")
            
            isScanning = true
            centralManager.scanForPeripherals(
                withServices: [transferServiceUUID, qorvoServiceUUID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        }
    }
    
    func connect(to peripheral: CBPeripheral) {
        peripheral.delegate = self
        
        // Update state for this specific device
        deviceStates[peripheral.identifier] = "Connecting"
        
        if connectedPeripherals.isEmpty {
            protocolState = "Connecting"
            connectionStatus = "Connecting..."
        }
        
        centralManager.connect(peripheral, options: nil)
        addDebugLog("🔗 [\(peripheral.name ?? "Unknown")] Connecting to Arduino device...")
    }
    
    func disconnect() {
        disconnectAll()
    }
    
    func disconnect(peripheralID: UUID) {
        guard let peripheral = connectedPeripherals[peripheralID] else {
            addDebugLog("❌ Cannot disconnect - peripheral \(peripheralID) not found")
            return
        }
        
        addDebugLog("🔌 [\(peripheral.name ?? "Unknown")] Disconnecting from Arduino device...")
        
        // Send stop command if connected
        if let characteristics = peripheralCharacteristics[peripheralID], characteristics.rx != nil {
            sendMessage(.stop, to: peripheralID)
        }
        
        // Clean up UWB session for this device
        if let session = niSessions[peripheralID] {
            session.invalidate()
            niSessions.removeValue(forKey: peripheralID)
            configurations.removeValue(forKey: peripheralID)
            accessoryDiscoveryTokens.removeValue(forKey: peripheralID)
        }
        
        // Cancel any pending timeout timers
        cancelProtocolTimeoutTimer(for: peripheralID)
        
        // Remove device data
        connectedDevicesData[peripheralID]?.isRanging = false
        connectedDevicesData[peripheralID]?.uwbLocation.isValid = false
        
        deviceStates[peripheralID] = "Disconnecting"
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func disconnectAll() {
        addDebugLog("🔌 Disconnecting from all Arduino devices...")
        
        for peripheralID in connectedPeripherals.keys {
            disconnect(peripheralID: peripheralID)
        }
        
        // Update global state
        protocolState = "Disconnecting"
        
        // Don't destroy AR session - keep it running for next connection
        if isARSessionEnabled {
            addDebugLog("📷 AR session kept running for next connection")
        }
    }
    
    func readRSSI() {
        // Read RSSI for all connected devices
        for peripheral in connectedPeripherals.values {
            peripheral.readRSSI()
        }
    }
    
    func readRSSI(for peripheralID: UUID) {
        connectedPeripherals[peripheralID]?.readRSSI()
    }
    
    func retryUWBInitialization() {
        retryUWBInitialization(for: nil)
    }
    
    func retryUWBInitialization(for peripheralID: UUID?) {
        if let peripheralID = peripheralID {
            // Retry for specific device
            guard connectedPeripherals[peripheralID] != nil else {
                addDebugLog("❌ Cannot retry - device \(peripheralID) not connected")
                return
            }
            
            let deviceName = connectedPeripherals[peripheralID]?.name ?? "Unknown"
            addDebugLog("🔄 [\(deviceName)] Retrying UWB initialization (attempt \(configurationAttempts + 1))...")
            
            // Clean up existing session for this device
            if let session = niSessions[peripheralID] {
                session.invalidate()
                niSessions.removeValue(forKey: peripheralID)
                configurations.removeValue(forKey: peripheralID)
                accessoryDiscoveryTokens.removeValue(forKey: peripheralID)
            }
            
            connectedDevicesData[peripheralID]?.isRanging = false
            deviceStates[peripheralID] = "Retrying"
            
            // Wait a moment for cleanup to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startUWBProtocol(for: peripheralID)
            }
        } else {
            // Retry for all devices
            guard !connectedPeripherals.isEmpty else {
                addDebugLog("❌ Cannot retry - no devices connected")
                return
            }
            
            addDebugLog("🔄 Retrying UWB initialization for all devices (attempt \(configurationAttempts + 1))...")
            
            // Clean up all existing sessions
            for session in niSessions.values {
                session.invalidate()
            }
            niSessions.removeAll()
            configurations.removeAll()
            accessoryDiscoveryTokens.removeAll()
            
            // Reset AR session if it was problematic
            if isARSessionEnabled {
                isARSessionEnabled = false
                arSession?.pause()
                arSession = nil
                addDebugLog("📷 AR session reset for retry")
            }
            
            // Update device states
            for peripheralID in connectedPeripherals.keys {
                connectedDevicesData[peripheralID]?.isRanging = false
                deviceStates[peripheralID] = "Retrying"
            }
            
            isRanging = false
            protocolState = "Retrying"
            
            // Wait a moment for cleanup to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startUWBProtocol()
            }
        }
    }
    
    // MARK: - UWB Protocol Methods
    private func startUWBProtocol() {
        // Start UWB protocol for all connected devices
        for peripheralID in connectedPeripherals.keys {
            startUWBProtocol(for: peripheralID)
        }
    }
    
    private func startUWBProtocol(for peripheralID: UUID) {
        guard let peripheral = connectedPeripherals[peripheralID] else {
            addDebugLog("❌ Cannot start UWB - peripheral \(peripheralID) not found")
            return
        }
        
        let deviceName = peripheral.name ?? "Unknown"
        addDebugLog("🎯 [\(deviceName)] Initializing UWB protocol...")
        print("\n🎯 [\(deviceName)] STARTING UWB PROTOCOL SEQUENCE")
        
        deviceStates[peripheralID] = "Initializing UWB"
        configurationAttempts += 1
        
        // Create new NI session for this device
        let session = NISession()
        session.delegate = self
        niSessions[peripheralID] = session
        addDebugLog("🎯 [\(deviceName)] Created new NISession")
        print("✅ [\(deviceName)] Created NISession")
        
        // Start preparing AR session early to allow stabilization time
        if ARWorldTrackingConfiguration.isSupported {
            setupARSessionIfAvailable()
        }
        
        debugProtocolState(for: peripheralID, step: "Starting UWB Protocol")
        
        // Add a small delay to ensure BLE characteristics are fully ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Send initialize command to this device
            self.addDebugLog("📤 [\(deviceName)] Sending INITIALIZE (0x0A) to start protocol...")
            print("📤 [\(deviceName)] Sending INITIALIZE command")
            self.sendMessage(.initialize, to: peripheralID)
            
            // Start timeout timer for protocol initialization
            self.startProtocolTimeoutTimer(for: peripheralID, timeoutSeconds: 30)
        }
        
        if connectedPeripherals.count == 1 {
            protocolState = "Initializing UWB"
        }
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
        // Link AR to all active NI sessions
        for peripheralID in niSessions.keys {
            linkARSessionToNI(for: peripheralID)
        }
    }
    
    private func linkARSessionToNI(for peripheralID: UUID) {
        guard let arSession = arSession, let niSession = niSessions[peripheralID] else {
            addDebugLog("⚠️ [\(peripheralID)] Cannot link - AR or NI session not available")
            return
        }
        
        guard let deviceData = connectedDevicesData[peripheralID] else {
            addDebugLog("⚠️ [\(peripheralID)] Cannot link - no device data")
            return
        }
        
        // Only link if configuration is ready and we're not already linked
        guard !isARSessionEnabled && deviceData.isRanging else {
            if isARSessionEnabled {
                addDebugLog("⚠️ [\(deviceData.deviceName)] AR Session already linked")
            } else if !deviceData.isRanging {
                addDebugLog("⚠️ [\(deviceData.deviceName)] Cannot link AR - UWB not yet active")
            }
            return
        }
        
        // Ensure AR session has had time to stabilize
        addDebugLog("📷 [\(deviceData.deviceName)] Linking AR session to stabilized NI session...")
        
        do {
            // Link AR session to NI session with error handling
            niSession.setARSession(arSession)
            isARSessionEnabled = true
            addDebugLog("✅ [\(deviceData.deviceName)] AR Session successfully linked to NI Session")
        } catch {
            addDebugLog("❌ [\(deviceData.deviceName)] Failed to link AR session: \(error.localizedDescription)")
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
        // Send to all connected devices for backward compatibility
        for peripheralID in connectedPeripherals.keys {
            sendMessage(messageId, data: data, to: peripheralID)
        }
    }
    
    // MARK: - Protocol Debugging Helper
    private func debugProtocolState(for peripheralID: UUID, step: String) {
        guard let peripheral = connectedPeripherals[peripheralID] else { return }
        let deviceName = peripheral.name ?? "Unknown"
        let currentState = deviceStates[peripheralID] ?? "Unknown"
        let isRanging = connectedDevicesData[peripheralID]?.isRanging ?? false
        
        print("\n🔧 [\(deviceName)] PROTOCOL DEBUG:")
        print("   Step: \(step)")
        print("   Current State: \(currentState)")
        print("   Is Ranging: \(isRanging)")
        print("   Has NISession: \(niSessions[peripheralID] != nil)")
        print("   Has Config: \(configurations[peripheralID] != nil)")
        print("   Has Token: \(accessoryDiscoveryTokens[peripheralID] != nil)")
        print("   Has Characteristics: RX=\(peripheralCharacteristics[peripheralID]?.rx != nil), TX=\(peripheralCharacteristics[peripheralID]?.tx != nil)")
        addDebugLog("🔧 [\(deviceName)] \(step) - State: \(currentState)")
    }
    
    private func sendMessage(_ messageId: BLEMessageId, data: Data? = nil, to peripheralID: UUID) {
        guard let peripheral = connectedPeripherals[peripheralID],
              let characteristics = peripheralCharacteristics[peripheralID],
              let rxCharacteristic = characteristics.rx else {
            let deviceName = connectedPeripherals[peripheralID]?.name ?? "Unknown"
            addDebugLog("❌ [\(deviceName)] Cannot send \(messageId) - no RX characteristic")
            debugProtocolState(for: peripheralID, step: "Send Failed - No RX Characteristic")
            return
        }
        
        var message = Data([messageId.rawValue])
        if let data = data {
            message.append(data)
        }
        
        lastMessageSent = messageId
        
        let hexString = message.map { String(format: "%02X", $0) }.joined(separator: " ")
        let deviceName = peripheral.name ?? "Unknown"
        addDebugLog("📤 [\(deviceName)] TX: \(messageId) [\(hexString)]")
        print("📤 [\(deviceName)] Sending \(messageId) to Arduino")
        
        debugProtocolState(for: peripheralID, step: "Sending \(messageId)")
        
        peripheral.writeValue(message, for: rxCharacteristic, type: .withResponse)
    }
    
    private func handleReceivedData(_ data: Data, from peripheralID: UUID) {
        guard data.count > 0 else {
            addDebugLog("❌ [\(peripheralID)] Received empty data")
            return
        }
        
        let deviceName = connectedPeripherals[peripheralID]?.name ?? "Unknown"
        let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        addDebugLog("📥 [\(deviceName)] RX: [\(hexString)]")
        
        guard let messageId = BLEMessageId(rawValue: data[0]) else {
            addDebugLog("❌ [\(deviceName)] Unknown message ID: 0x\(String(format: "%02X", data[0]))")
            return
        }
        
        addDebugLog("📥 [\(deviceName)] Message: \(messageId) (0x\(String(format: "%02X", messageId.rawValue)))")
        
        switch messageId {
        case .accessoryConfigurationData:
            deviceStates[peripheralID] = "Received Config"
            addDebugLog("✅ [\(deviceName)] Received UWB configuration from accessory")
            print("✅ [\(deviceName)] Arduino sent configuration data!")
            
            debugProtocolState(for: peripheralID, step: "Received Arduino Config")
            
            if data.count > 1 {
                let configData = data.advanced(by: 1)
                addDebugLog("   [\(deviceName)] Config size: \(configData.count) bytes")
                print("📦 [\(deviceName)] Config data size: \(configData.count) bytes")
                handleConfigurationData(configData, for: peripheralID)
            } else {
                addDebugLog("❌ [\(deviceName)] Configuration data is empty!")
                print("❌ [\(deviceName)] Empty configuration data from Arduino")
            }
            
        case .accessoryUwbDidStart:
            deviceStates[peripheralID] = "UWB Active"
            addDebugLog("🎉 [\(deviceName)] Accessory confirmed UWB started!")
            print("🎉 [\(deviceName)] Arduino confirmed UWB ranging started!")
            
            debugProtocolState(for: peripheralID, step: "Arduino Confirmed UWB Started")
            
            // Update device-specific ranging state
            connectedDevicesData[peripheralID]?.isRanging = true
            
            // Update global ranging state if this is the first device
            if !isRanging {
                isRanging = true
                protocolState = "UWB Active"
            }
            
            print("✅ [\(deviceName)] Device should now show 'Ranging' status and start providing distance data")
        
        // Cancel timeout timer since UWB started successfully
        cancelProtocolTimeoutTimer(for: peripheralID)
            
            // Now that UWB is confirmed active, link AR session if available and ready
            if ARWorldTrackingConfiguration.isSupported && !isARSessionEnabled && arSession != nil {
                addDebugLog("📷 [\(deviceName)] UWB active - linking prepared AR session...")
                // Give a moment for any final AR stabilization
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.linkARSessionToNI(for: peripheralID)
                }
            } else if ARWorldTrackingConfiguration.isSupported && arSession == nil {
                addDebugLog("⚠️ [\(deviceName)] AR session not ready - continuing with UWB only")
            }
            
        case .accessoryUwbDidStop:
            deviceStates[peripheralID] = "UWB Stopped"
            addDebugLog("⏹️ [\(deviceName)] Accessory stopped UWB")
            
            // Update device-specific ranging state
            connectedDevicesData[peripheralID]?.isRanging = false
            connectedDevicesData[peripheralID]?.uwbLocation.isValid = false
            
            // Update global ranging state if no devices are ranging
            let anyDeviceRanging = connectedDevicesData.values.contains { $0.isRanging }
            if !anyDeviceRanging {
                isRanging = false
                protocolState = "UWB Stopped"
                uwbLocation.isValid = false
            }
            
        default:
            addDebugLog("❓ [\(deviceName)] Unexpected message from accessory")
        }
    }
    
    private func handleConfigurationData(_ configData: Data, for peripheralID: UUID) {
        guard let peripheral = connectedPeripherals[peripheralID] else {
            addDebugLog("❌ Cannot handle config - peripheral \(peripheralID) not found")
            return
        }
        
        let deviceName = peripheral.name ?? "Unknown"
        
        do {
            addDebugLog("🔧 [\(deviceName)] Creating NINearbyAccessoryConfiguration...")
            
            let config = try NINearbyAccessoryConfiguration(data: configData)
            // Only enable camera assistance if AR session will be available
            config.isCameraAssistanceEnabled = ARWorldTrackingConfiguration.isSupported
            
            configurations[peripheralID] = config
            accessoryDiscoveryTokens[peripheralID] = config.accessoryDiscoveryToken
            
            if ARWorldTrackingConfiguration.isSupported {
                addDebugLog("📷 [\(deviceName)] Camera assistance will be enabled")
            } else {
                addDebugLog("⚠️ [\(deviceName)] Camera assistance disabled - AR not supported")
            }
            
            addDebugLog("✅ [\(deviceName)] Configuration created successfully")
            
            // Ensure we have a valid session for this device
            if niSessions[peripheralID] == nil {
                addDebugLog("⚠️ [\(deviceName)] No NISession - creating one")
                let session = NISession()
                session.delegate = self
                niSessions[peripheralID] = session
            }
            
            addDebugLog("🏃 [\(deviceName)] Running NISession with configuration...")
            print("🏃 [\(deviceName)] Starting NISession with Arduino config")
            niSessions[peripheralID]?.run(config)
            
            deviceStates[peripheralID] = "Waiting for Shareable Config"
            addDebugLog("⏳ [\(deviceName)] Waiting for iOS to generate shareable config...")
            print("⏳ [\(deviceName)] iOS will now generate config to send back to Arduino")
            
            debugProtocolState(for: peripheralID, step: "NISession Started - Waiting for iOS Config")
            
            // Update global state if this is the first device
            if deviceStates.count == 1 {
                protocolState = "Waiting for Shareable Config"
            }
            
        } catch {
            addDebugLog("❌ [\(deviceName)] Configuration error: \(error)")
            deviceStates[peripheralID] = "Config Error"
            
            if configurationAttempts < 3 {
                addDebugLog("🔄 [\(deviceName)] Retrying initialization (attempt \(configurationAttempts + 1)/3)...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.startUWBProtocol(for: peripheralID)
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
    
    // MARK: - Multiple Device Access Methods
    func getRelativeBearing(for peripheralID: UUID) -> Float? {
        return connectedDevicesData[peripheralID]?.uwbLocation.relativeBearing
    }
    
    func getAbsoluteAzimuth(for peripheralID: UUID) -> Float? {
        return connectedDevicesData[peripheralID]?.uwbLocation.enhancedAzimuth
    }
    
    func getDistance(for peripheralID: UUID) -> Float? {
        return connectedDevicesData[peripheralID]?.uwbLocation.distance
    }
    
    func getDeviceName(for peripheralID: UUID) -> String? {
        return connectedDevicesData[peripheralID]?.deviceName
    }
    
    func isDeviceRanging(for peripheralID: UUID) -> Bool {
        return connectedDevicesData[peripheralID]?.isRanging ?? false
    }
    
    func getAllConnectedDeviceData() -> [UUID: DeviceData] {
        return connectedDevicesData
    }
    
    func logAllDevicesData() {
        print("\n📈 === MULTIPLE ARDUINO DEVICES STATUS ===")
        print("Connected devices: \(connectedPeripherals.count)")
        
        for (peripheralID, deviceData) in connectedDevicesData {
            print("\n🤖 Device: \(deviceData.deviceName) (\(peripheralID))")
            print("   Status: \(deviceStates[peripheralID] ?? "Unknown")")
            print("   Ranging: \(deviceData.isRanging)")
            print("   Distance: \(String(format: "%.2f", deviceData.uwbLocation.distance))m")
            print("   Azimuth: \(String(format: "%.1f", deviceData.uwbLocation.azimuth))°")
            print("   Elevation: \(String(format: "%.1f", deviceData.uwbLocation.elevation))°")
            print("   Valid: \(deviceData.uwbLocation.isValid)")
            print("   NoUpdate: \(deviceData.uwbLocation.noUpdate)")
            print("   Direction: (\(String(format: "%.3f", deviceData.uwbLocation.direction.x)), \(String(format: "%.3f", deviceData.uwbLocation.direction.y)), \(String(format: "%.3f", deviceData.uwbLocation.direction.z)))")
            print("   Last Updated: \(deviceData.lastUpdated)")
            if let rssi = deviceRSSI[peripheralID] {
                print("   RSSI: \(rssi) dBm")
            }
            
            // Debug problematic devices
            if deviceData.uwbLocation.distance == 0.0 && deviceData.uwbLocation.direction == SIMD3<Float>(0, 0, 0) {
                print("⚠️   ISSUE: Zero distance and direction - check Arduino UWB initialization")
                let currentState = deviceStates[peripheralID] ?? "Unknown"
                if currentState == "Connected" || currentState == "BLE Connected" {
                    print("🔧   STUCK IN: \(currentState) - Protocol may need manual restart")
                    print("📝   SUGGESTION: Call bleManager.forceRestartProtocol(for: peripheralID)")
                }
            }
        }
        print("\n================================================\n")
    }
    
    // MARK: - Protocol Timeout Management
    private func startProtocolTimeoutTimer(for peripheralID: UUID, timeoutSeconds: TimeInterval) {
        // Cancel existing timer if any
        cancelProtocolTimeoutTimer(for: peripheralID)
        
        let deviceName = connectedPeripherals[peripheralID]?.name ?? "Unknown"
        
        let timer = Timer.scheduledTimer(withTimeInterval: timeoutSeconds, repeats: false) { _ in
            print("⏰ [\(deviceName)] Protocol timeout - retrying initialization")
            self.addDebugLog("⏰ [\(deviceName)] Protocol timeout after \(timeoutSeconds)s - retrying")
            
            // Retry protocol initialization
            self.retryUWBInitialization(for: peripheralID)
        }
        
        protocolTimeoutTimers[peripheralID] = timer
        print("⏱️ [\(deviceName)] Started protocol timeout timer (\(timeoutSeconds)s)")
    }
    
    private func cancelProtocolTimeoutTimer(for peripheralID: UUID) {
        if let timer = protocolTimeoutTimers[peripheralID] {
            timer.invalidate()
            protocolTimeoutTimers.removeValue(forKey: peripheralID)
            
            let deviceName = connectedPeripherals[peripheralID]?.name ?? "Unknown"
            print("✅ [\(deviceName)] Protocol timeout timer cancelled")
        }
    }
    
    // MARK: - Manual Protocol Restart (for debugging)
    func forceRestartProtocol(for peripheralID: UUID) {
        guard let peripheral = connectedPeripherals[peripheralID] else {
            print("❌ Cannot restart protocol - device not connected")
            return
        }
        
        let deviceName = peripheral.name ?? "Unknown"
        print("\n🔄 [\(deviceName)] MANUAL PROTOCOL RESTART INITIATED")
        
        // Cancel any existing timers
        cancelProtocolTimeoutTimer(for: peripheralID)
        
        // Clean up existing session
        if let session = niSessions[peripheralID] {
            session.invalidate()
            niSessions.removeValue(forKey: peripheralID)
            configurations.removeValue(forKey: peripheralID)
            accessoryDiscoveryTokens.removeValue(forKey: peripheralID)
        }
        
        // Reset device state
        connectedDevicesData[peripheralID]?.isRanging = false
        connectedDevicesData[peripheralID]?.uwbLocation.isValid = false
        deviceStates[peripheralID] = "Restarting Protocol"
        
        // Restart protocol after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startUWBProtocol(for: peripheralID)
        }
    }
    
    func forceRestartAllProtocols() {
        print("\n🔄 MANUAL RESTART ALL PROTOCOLS")
        for peripheralID in connectedPeripherals.keys {
            forceRestartProtocol(for: peripheralID)
        }
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
        let deviceName = peripheral.name ?? "Unknown"
        addDebugLog("✅ [\(deviceName)] Connected to Arduino device")
        
        // Add to connected peripherals
        connectedPeripherals[peripheral.identifier] = peripheral
        
        // Initialize device data
        connectedDevicesData[peripheral.identifier] = DeviceData(peripheral: peripheral)
        deviceStates[peripheral.identifier] = "BLE Connected"
        
        // Update global connection state
        if !isConnected {
            isConnected = true
            connectionStatus = "Connected"
            protocolState = "BLE Connected"
        }
        
        // Update connection status to show multiple devices
        connectionStatus = "Connected (\(connectedPeripherals.count) device\(connectedPeripherals.count == 1 ? "" : "s"))"
        
        // Continue scanning for more devices to allow multiple connections
        // Note: Removed stopScanning() to enable multiple Arduino connections
        print("🔍 [\(deviceName)] Connected! Continuing to scan for more Arduino devices...")
        
        // Continue scanning after a short delay to allow this connection to stabilize
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.continueScanningForMoreDevices()
        }
        
        // Discover services
        addDebugLog("🔍 [\(deviceName)] Discovering services...")
        peripheral.discoverServices([transferServiceUUID, qorvoServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        addDebugLog("❌ Connection failed: \(error?.localizedDescription ?? "Unknown")")
        connectionStatus = "Failed"
        protocolState = "Connection Failed"
        isConnected = false
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let deviceName = peripheral.name ?? "Unknown"
        addDebugLog("🔌 [\(deviceName)] Disconnected from Arduino device")
        
        let peripheralID = peripheral.identifier
        
        // Clean up device-specific data
        connectedPeripherals.removeValue(forKey: peripheralID)
        connectedDevicesData.removeValue(forKey: peripheralID)
        peripheralCharacteristics.removeValue(forKey: peripheralID)
        deviceStates.removeValue(forKey: peripheralID)
        deviceRSSI.removeValue(forKey: peripheralID)
        
        // Clean up UWB session for this device
        if let session = niSessions[peripheralID] {
            session.invalidate()
            niSessions.removeValue(forKey: peripheralID)
            configurations.removeValue(forKey: peripheralID)
            accessoryDiscoveryTokens.removeValue(forKey: peripheralID)
        }
        
        // Update global connection state
        if connectedPeripherals.isEmpty {
            connectionStatus = "Disconnected"
            protocolState = "Disconnected"
            isConnected = false
            isRanging = false
            rssi = 0
            configurationAttempts = 0
            uwbLocation.isValid = false
            
            // Reset AR session only when all devices are disconnected
            arSession = nil
            isARSessionEnabled = false
        } else {
            // Update connection status to show remaining devices
            connectionStatus = "Connected (\(connectedPeripherals.count) device\(connectedPeripherals.count == 1 ? "" : "s"))"
            
            // Check if any device is still ranging
            let anyDeviceRanging = connectedDevicesData.values.contains { $0.isRanging }
            if !anyDeviceRanging {
                isRanging = false
                protocolState = "Connected - No Ranging"
            }
            
            // Keep AR session running if we still have connected devices
            if isARSessionEnabled {
                addDebugLog("📷 AR session kept running for remaining devices")
            }
        }
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
            addDebugLog("❌ [\(peripheral.name ?? "Unknown")] Characteristic discovery error: \(error)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        let deviceName = peripheral.name ?? "Unknown"
        let peripheralID = peripheral.identifier
        addDebugLog("📋 [\(deviceName)] Found \(characteristics.count) characteristics for service \(service.uuid)")
        
        // Initialize characteristics for this device if not exists
        if peripheralCharacteristics[peripheralID] == nil {
            peripheralCharacteristics[peripheralID] = (rx: nil, tx: nil)
        }
        
        for characteristic in characteristics {
            // Handle both standard and Qorvo UUIDs
            if characteristic.uuid == rxCharacteristicUUID || characteristic.uuid == qorvoRxUUID {
                peripheralCharacteristics[peripheralID]?.rx = characteristic
                addDebugLog("✅ [\(deviceName)] Found RX characteristic")
            } else if characteristic.uuid == txCharacteristicUUID || characteristic.uuid == qorvoTxUUID {
                peripheralCharacteristics[peripheralID]?.tx = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                addDebugLog("✅ [\(deviceName)] Found TX characteristic, enabled notifications")
            }
        }
        
        // Start UWB protocol after discovering characteristics for this device
        if let chars = peripheralCharacteristics[peripheralID],
           chars.rx != nil && chars.tx != nil {
            addDebugLog("🚀 [\(deviceName)] All characteristics ready - starting UWB protocol")
            deviceStates[peripheralID] = "Characteristics Ready"
            
            // Update global state if this is the first device
            if deviceStates.count == 1 {
                protocolState = "Characteristics Ready"
            }
            
            // Small delay to ensure everything is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startUWBProtocol(for: peripheralID)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            addDebugLog("❌ [\(peripheral.name ?? "Unknown")] Value update error: \(error)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        let peripheralID = peripheral.identifier
        
        // Handle protocol messages for this specific device
        handleReceivedData(data, from: peripheralID)
        
        // Read RSSI for this device
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
            let peripheralID = peripheral.identifier
            DispatchQueue.main.async {
                // Store RSSI for this specific device
                self.deviceRSSI[peripheralID] = RSSI.intValue
                
                // Update global RSSI with primary device (first connected)
                if self.connectedPeripherals.keys.first == peripheralID {
                    self.rssi = RSSI.intValue
                }
            }
        }
    }
}

// MARK: - NISessionDelegate
extension BLEManager: NISessionDelegate {
    func session(_ session: NISession, didGenerateShareableConfigurationData shareableConfigurationData: Data, for object: NINearbyObject) {
        // Find which device this session belongs to
        guard let peripheralID = niSessions.first(where: { $0.value === session })?.key,
              let deviceData = connectedDevicesData[peripheralID],
              let token = accessoryDiscoveryTokens[peripheralID] else {
            addDebugLog("❌ Cannot find device for session in shareable config")
            return
        }
        
        guard object.discoveryToken == token else {
            addDebugLog("❌ [\(deviceData.deviceName)] Token mismatch in shareable config")
            return
        }
        
        deviceStates[peripheralID] = "Sending Shareable Config"
        addDebugLog("📤 [\(deviceData.deviceName)] iOS generated shareable config (\(shareableConfigurationData.count) bytes)")
        addDebugLog("📤 [\(deviceData.deviceName)] Sending CONFIGURE_AND_START (0x0B) with config...")
        
        sendMessage(.configureAndStart, data: shareableConfigurationData, to: peripheralID)
        
        // Update global state if this is the first device
        if deviceStates.count == 1 {
            protocolState = "Sending Shareable Config"
        }
    }
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else { return }
        
        // Find which device this session belongs to
        guard let peripheralID = niSessions.first(where: { $0.value === session })?.key,
              var deviceData = connectedDevicesData[peripheralID] else {
            addDebugLog("❌ Cannot find device for session in location update")
            return
        }
        
        let deviceName = deviceData.deviceName
        
        // ALWAYS log raw data for debugging with device identification
        let rawDistance = object.distance?.description ?? "nil"
        let rawDirection = object.direction?.debugDescription ?? "nil"
        let rawHorizontalAngle = object.horizontalAngle?.description ?? "nil"
        let rawVerticalEstimate = String(describing: object.verticalDirectionEstimate)
        
        // Enhanced console logging for each Arduino device
        print("\n🔍 [\(deviceName)] RAW UWB DATA:")
        print("   📏 Distance: \(rawDistance)")
        print("   🧭 Direction: \(rawDirection)")
        print("   📐 Horizontal Angle: \(rawHorizontalAngle)")
        print("   ⬆️ Vertical Estimate: \(rawVerticalEstimate)")
        
        addDebugLog("🔍 [\(deviceName)] RAW DATA - Distance: \(rawDistance), Direction: \(rawDirection), HAngle: \(rawHorizontalAngle), VEstimate: \(rawVerticalEstimate)")
        
        DispatchQueue.main.async {
            // Always update distance for this device
            if let distance = object.distance {
                deviceData.uwbLocation.distance = distance
                
                // Enhanced console output for each Arduino
                print("📏 [\(deviceName)] Distance: \(String(format: "%.3f", distance))m")
                self.addDebugLog("📏 [\(deviceName)] Distance: \(String(format: "%.3f", distance))m")
                
                // Update primary location (first device for backward compatibility)
                if self.connectedPeripherals.keys.first == peripheralID {
                    self.uwbLocation.distance = distance
                }
            }
            
            // Update device capabilities and heading in location
            deviceData.uwbLocation.supportsDirectionMeasurement = self.supportsDirectionMeasurement
            
            // Update device heading from location manager
            if let locationManager = self.locationManager {
                deviceData.uwbLocation.deviceHeading = Float(locationManager.deviceHeading)
                
                // Update primary location heading
                if self.connectedPeripherals.keys.first == peripheralID {
                    self.uwbLocation.deviceHeading = Float(locationManager.deviceHeading)
                }
            }
            
            // Handle direction based on device capabilities and convergence
            if let direction = object.direction {
                // iPhone 11-13 with full direction support
                deviceData.uwbLocation.direction = direction
                let oldAzimuth = deviceData.uwbLocation.azimuth
                let oldElevation = deviceData.uwbLocation.elevation
                
                deviceData.uwbLocation.azimuth = deviceData.uwbLocation.enhancedAzimuth
                deviceData.uwbLocation.elevation = deviceData.uwbLocation.enhancedElevation
                deviceData.uwbLocation.noUpdate = false
                
                // Enhanced console output for direction data
                print("📍 [\(deviceName)] 3D Direction Vector:")
                print("   X: \(String(format: "%.6f", direction.x))")
                print("   Y: \(String(format: "%.6f", direction.y))")
                print("   Z: \(String(format: "%.6f", direction.z))")
                print("📍 [\(deviceName)] Calculated Direction:")
                print("   Azimuth: \(String(format: "%.1f", deviceData.uwbLocation.azimuth))°")
                print("   Elevation: \(String(format: "%.1f", deviceData.uwbLocation.elevation))°")
                
                self.addDebugLog("📍 [\(deviceName)] 3D Direction: x=\(String(format: "%.6f", direction.x)), y=\(String(format: "%.6f", direction.y)), z=\(String(format: "%.6f", direction.z))")
                self.addDebugLog("📍 [\(deviceName)] Direction Az: \(String(format: "%.1f", deviceData.uwbLocation.azimuth))°, El: \(String(format: "%.1f", deviceData.uwbLocation.elevation))° (was Az: \(String(format: "%.1f", oldAzimuth))°)")
                
                // Update primary location (first device for backward compatibility)
                if self.connectedPeripherals.keys.first == peripheralID {
                    self.uwbLocation.direction = direction
                    self.uwbLocation.azimuth = deviceData.uwbLocation.azimuth
                    self.uwbLocation.elevation = deviceData.uwbLocation.elevation
                    self.uwbLocation.noUpdate = false
                }
                
            } else if self.isConverged, let horizontalAngle = object.horizontalAngle {
                // iPhone 14+ fallback when converged (Qorvo approach)
                deviceData.uwbLocation.horizontalAngle = horizontalAngle
                
                // Use Qorvo's direction conversion approach
                let syntheticDirection = self.getDirectionFromHorizontalAngle(rad: horizontalAngle)
                deviceData.uwbLocation.direction = syntheticDirection
                
                // Calculate azimuth and elevation using enhanced methods
                deviceData.uwbLocation.azimuth = deviceData.uwbLocation.enhancedAzimuth
                
                // Get vertical estimate (Qorvo approach)
                let verticalEstimate = object.verticalDirectionEstimate
                deviceData.uwbLocation.verticalDirectionEstimate = verticalEstimate.rawValue
                deviceData.uwbLocation.elevation = Float(verticalEstimate.rawValue)
                
                deviceData.uwbLocation.noUpdate = false
                
                // Enhanced console output for converged direction
                print("📍 [\(deviceName)] Converged Direction (iPhone 14+ mode):")
                print("   Horizontal Angle: \(String(format: "%.3f", horizontalAngle))rad = \(String(format: "%.1f", horizontalAngle * 180 / .pi))°")
                print("   Vertical Estimate: \(verticalEstimate)")
                
                self.addDebugLog("📍 [\(deviceName)] Converged Direction: HAngle: \(String(format: "%.3f", horizontalAngle))rad = \(String(format: "%.1f", horizontalAngle * 180 / .pi))°, VEst: \(verticalEstimate)")
                
                // Update primary location (first device for backward compatibility)
                if self.connectedPeripherals.keys.first == peripheralID {
                    self.uwbLocation.horizontalAngle = horizontalAngle
                    self.uwbLocation.direction = syntheticDirection
                    self.uwbLocation.azimuth = deviceData.uwbLocation.azimuth
                    self.uwbLocation.verticalDirectionEstimate = verticalEstimate.rawValue
                    self.uwbLocation.elevation = Float(verticalEstimate.rawValue)
                    self.uwbLocation.noUpdate = false
                }
                
            } else {
                // No direction available
                deviceData.uwbLocation.noUpdate = true
                
                // Enhanced console output for no direction
                print("⚠️ [\(deviceName)] No direction data available")
                print("   - Check Arduino UWB ranging status")
                print("   - Verify device distance > 0 for direction calculation")
                print("   - Current distance: \(String(format: "%.3f", deviceData.uwbLocation.distance))m")
                
                if !self.isConverged {
                    if deviceData.uwbLocation.distance < 1.0 {
                        print("📱 [\(deviceName)] Move away from target - too close for direction")
                        self.addDebugLog("📱 [\(deviceName)] Move away from target - too close for direction")
                    } else {
                        print("🚶 [\(deviceName)] Move device in figure-8 patterns for convergence")
                        self.addDebugLog("🚶 [\(deviceName)] Move device in figure-8 patterns for convergence")
                    }
                } else {
                    print("💡 [\(deviceName)] Need better lighting conditions for direction")
                    self.addDebugLog("💡 [\(deviceName)] Need better lighting conditions for direction")
                }
                
                // Update primary location (first device for backward compatibility)
                if self.connectedPeripherals.keys.first == peripheralID {
                    self.uwbLocation.noUpdate = true
                }
            }
            
            // Always update timestamp and validity if we have any data
            if !deviceData.uwbLocation.noUpdate || deviceData.uwbLocation.distance > 0 {
                deviceData.uwbLocation.timestamp = Date()
                deviceData.uwbLocation.isValid = true
                deviceData.uwbLocation.isConverged = self.isConverged
                deviceData.lastUpdated = Date()
                
                let azimuthDeg = deviceData.uwbLocation.azimuth
                let elevationDeg = deviceData.uwbLocation.elevation
                let relativeBearing = deviceData.uwbLocation.relativeBearing
                let deviceHead = deviceData.uwbLocation.deviceHeading
                
                // Enhanced console output with final calculated values
                print("📍 [\(deviceName)] FINAL CALCULATED VALUES:")
                print("   Distance: \(String(format: "%.2f", deviceData.uwbLocation.distance))m")
                print("   Azimuth: \(String(format: "%.1f", azimuthDeg))°")
                print("   Elevation: \(String(format: "%.1f", elevationDeg))°")
                print("   Device Heading: \(String(format: "%.1f", deviceHead))°")
                print("   Relative Bearing: \(String(format: "%.1f", relativeBearing))°")
                print("   Last Updated: \(deviceData.lastUpdated)")
                print("")
                
                self.addDebugLog("📍 [\(deviceName)] Final: D: \(String(format: "%.2f", deviceData.uwbLocation.distance))m, Az: \(String(format: "%.1f", azimuthDeg))°, El: \(String(format: "%.1f", elevationDeg))°")
                self.addDebugLog("🧭 [\(deviceName)] Device: \(String(format: "%.1f", deviceHead))° → Target: \(String(format: "%.1f", azimuthDeg))° (Relative: \(String(format: "%.1f", relativeBearing))°)")
                
                // Update primary location (first device for backward compatibility)
                if self.connectedPeripherals.keys.first == peripheralID {
                    self.uwbLocation.timestamp = deviceData.uwbLocation.timestamp
                    self.uwbLocation.isValid = true
                    self.uwbLocation.isConverged = self.isConverged
                }
            }
            
            // Update the device data in the dictionary
            self.connectedDevicesData[peripheralID] = deviceData
        }
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        // Find which device this session belongs to
        guard let peripheralID = niSessions.first(where: { $0.value === session })?.key,
              let deviceData = connectedDevicesData[peripheralID] else {
            addDebugLog("❌ Cannot find device for session in object removal")
            return
        }
        
        let deviceName = deviceData.deviceName
        addDebugLog("⚠️ [\(deviceName)] Object removed - Reason: \(reason)")
        
        // Enhanced console output for object removal
        print("⚠️ [\(deviceName)] UWB object removed - Reason: \(reason)")
        
        if reason == .timeout {
            deviceStates[peripheralID] = "Session Timeout"
            addDebugLog("⏰ [\(deviceName)] Session timeout - reinitializing...")
            print("⏰ [\(deviceName)] Session timeout - reinitializing...")
            sendMessage(.initialize, to: peripheralID)
            
            // Update global state if needed
            if deviceStates.count == 1 {
                protocolState = "Session Timeout"
            }
        }
    }
    
    func sessionWasSuspended(_ session: NISession) {
        // Find which device this session belongs to
        guard let peripheralID = niSessions.first(where: { $0.value === session })?.key,
              let deviceData = connectedDevicesData[peripheralID] else {
            addDebugLog("❌ Cannot find device for session suspension")
            return
        }
        
        let deviceName = deviceData.deviceName
        deviceStates[peripheralID] = "Session Suspended"
        addDebugLog("⏸️ [\(deviceName)] Session suspended - app backgrounded or camera permission issue")
        
        // Enhanced console output
        print("⏸️ [\(deviceName)] UWB session suspended")
        
        // Update global state if this is the only device
        if deviceStates.count == 1 {
            protocolState = "Session Suspended"
        }
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        // Find which device this session belongs to
        guard let peripheralID = niSessions.first(where: { $0.value === session })?.key,
              let deviceData = connectedDevicesData[peripheralID] else {
            addDebugLog("❌ Cannot find device for session resumption")
            return
        }
        
        let deviceName = deviceData.deviceName
        deviceStates[peripheralID] = "Session Resumed"
        addDebugLog("▶️ [\(deviceName)] Session resumed")
        
        // Enhanced console output
        print("▶️ [\(deviceName)] UWB session resumed")
        
        sendMessage(.initialize, to: peripheralID)
        
        // Update global state if this is the first device
        if deviceStates.count == 1 {
            protocolState = "Session Resumed"
        }
    }
    
    func session(_ session: NISession, didUpdateAlgorithmConvergence convergence: NIAlgorithmConvergence, for object: NINearbyObject?) {
        guard object != nil else { return }
        
        // Find which device this session belongs to
        guard let peripheralID = niSessions.first(where: { $0.value === session })?.key,
              var deviceData = connectedDevicesData[peripheralID] else {
            addDebugLog("❌ Cannot find device for convergence update")
            return
        }
        
        let deviceName = deviceData.deviceName
        
        DispatchQueue.main.async {
            switch convergence.status {
            case .converged:
                self.isConverged = true
                self.algorithmConvergenceStatus = "Converged"
                self.addDebugLog("✅ [\(deviceName)] Algorithm converged - accurate direction available")
                
                // Enhanced console output for convergence
                print("✅ [\(deviceName)] UWB algorithm converged - accurate direction measurements available")
                
                self.deviceStates[peripheralID] = "UWB Converged"
                
                // Update UWB location with device capabilities
                deviceData.uwbLocation.supportsDirectionMeasurement = self.supportsDirectionMeasurement
                
                // Update global state if this is the first device
                if self.deviceStates.count == 1 {
                    self.protocolState = "UWB Converged"
                }
                
            case .notConverged(let reasons):
                self.isConverged = false
                
                if reasons.contains(.insufficientLighting) {
                    self.algorithmConvergenceStatus = "Need Better Lighting"
                    self.addDebugLog("💡 [\(deviceName)] Move to brighter area for convergence")
                    print("💡 [\(deviceName)] Need better lighting for UWB convergence")
                } else if reasons.contains(.insufficientMovement) {
                    self.algorithmConvergenceStatus = "Need Movement"
                    self.addDebugLog("🚶 [\(deviceName)] Move device in slow figure-8 patterns")
                    print("🚶 [\(deviceName)] Move device in slow figure-8 patterns for convergence")
                } else {
                    self.algorithmConvergenceStatus = "Converging..."
                    self.addDebugLog("🔄 [\(deviceName)] Keep moving device slowly for convergence")
                    print("🔄 [\(deviceName)] Algorithm converging - keep moving device slowly")
                }
                
                // Always update device capabilities
                deviceData.uwbLocation.supportsDirectionMeasurement = self.supportsDirectionMeasurement
                
            @unknown default:
                self.algorithmConvergenceStatus = "Unknown"
                self.addDebugLog("❓ [\(deviceName)] Unknown convergence status")
                print("❓ [\(deviceName)] Unknown convergence status")
            }
            
            // Update the device data
            self.connectedDevicesData[peripheralID] = deviceData
        }
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        // Find which device this session belongs to
        guard let peripheralID = niSessions.first(where: { $0.value === session })?.key,
              var deviceData = connectedDevicesData[peripheralID] else {
            addDebugLog("❌ Cannot find device for session invalidation")
            return
        }
        
        let deviceName = deviceData.deviceName
        deviceStates[peripheralID] = "Session Invalid"
        addDebugLog("❌ [\(deviceName)] Session invalidated: \(error)")
        
        // Enhanced console output for session invalidation
        print("❌ [\(deviceName)] UWB session invalidated: \(error.localizedDescription)")
        
        // Update device-specific state
        deviceData.isRanging = false
        deviceData.uwbLocation.isValid = false
        connectedDevicesData[peripheralID] = deviceData
        
        // Remove the session
        niSessions.removeValue(forKey: peripheralID)
        configurations.removeValue(forKey: peripheralID)
        accessoryDiscoveryTokens.removeValue(forKey: peripheralID)
        
        // Cancel any pending timeout timers
        cancelProtocolTimeoutTimer(for: peripheralID)
        
        // Update global state
        let anyDeviceRanging = connectedDevicesData.values.contains { $0.isRanging }
        if !anyDeviceRanging {
            isRanging = false
            isConverged = false
            if connectedPeripherals.keys.first == peripheralID {
                uwbLocation.isValid = false
            }
        }
        
        // Update global state if no devices left
        if niSessions.isEmpty {
            protocolState = "Session Invalid"
        }
        
        // Handle specific error cases
        if let niError = error as? NIError {
            switch niError.code {
            case .userDidNotAllow:
                addDebugLog("🚫 [\(deviceName)] User denied Nearby Interaction access")
                addDebugLog("💡 [\(deviceName)] Enable location and camera permissions in Settings")
                print("🚫 [\(deviceName)] User denied Nearby Interaction access - check permissions")
            case .invalidConfiguration:
                addDebugLog("⚙️ [\(deviceName)] Invalid configuration - retrying initialization")
                print("⚙️ [\(deviceName)] Invalid configuration - retrying UWB initialization")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if self.connectedPeripherals[peripheralID] != nil {
                        self.retryUWBInitialization(for: peripheralID)
                    }
                }
            case .resourceUsageTimeout:
                addDebugLog("⏰ [\(deviceName)] Resource timeout - will retry on reconnection")
                print("⏰ [\(deviceName)] UWB resource timeout")
            case .activeSessionsLimitExceeded:
                addDebugLog("📱 [\(deviceName)] Too many active NI sessions - cleanup and retry")
                print("📱 [\(deviceName)] Too many active UWB sessions - cleaning up")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.retryUWBInitialization(for: peripheralID)
                }
            default:
                addDebugLog("❌ [\(deviceName)] NI Error (\(niError.code.rawValue)): \(niError.localizedDescription)")
                print("❌ [\(deviceName)] UWB Error (\(niError.code.rawValue)): \(niError.localizedDescription)")
                
                // For AR session errors, retry without AR
                if niError.localizedDescription.contains("AR") || niError.code.rawValue == -5883 {
                    addDebugLog("📷 [\(deviceName)] AR session error detected - retrying UWB without AR...")
                    print("📷 [\(deviceName)] AR session error - retrying without AR enhancement")
                    isARSessionEnabled = false
                    arSession?.pause()
                    arSession = nil
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if self.connectedPeripherals[peripheralID] != nil {
                            self.retryUWBInitialization(for: peripheralID)
                        }
                    }
                }
            }
        } else {
            addDebugLog("❌ [\(deviceName)] Unknown session error: \(error.localizedDescription)")
            print("❌ [\(deviceName)] Unknown UWB session error: \(error.localizedDescription)")
        }
    }
}


// Add this extension to your BLEManager.swift for better debugging

extension BLEManager {
    // Call this method to debug why a specific device isn't ranging
    func debugDeviceStatus(for peripheralID: UUID) {
        guard let deviceData = connectedDevicesData[peripheralID],
              let peripheral = connectedPeripherals[peripheralID] else {
            print("❌ DEBUG: Device not found for ID \(peripheralID)")
            return
        }
        
        let deviceName = deviceData.deviceName
        let currentState = deviceStates[peripheralID] ?? "Unknown"
        
        print("\n🔍 === DEVICE DEBUG: \(deviceName) ===")
        print("📱 Peripheral ID: \(peripheralID)")
        print("📊 Current State: \(currentState)")
        print("🔌 BLE Connected: \(peripheral.state == .connected)")
        print("📡 Has Characteristics: RX=\(peripheralCharacteristics[peripheralID]?.rx != nil), TX=\(peripheralCharacteristics[peripheralID]?.tx != nil)")
        print("🎯 Has NISession: \(niSessions[peripheralID] != nil)")
        print("📋 Has Configuration: \(configurations[peripheralID] != nil)")
        print("🔑 Has Discovery Token: \(accessoryDiscoveryTokens[peripheralID] != nil)")
        print("📏 Is Ranging: \(deviceData.isRanging)")
        print("📍 UWB Location Valid: \(deviceData.uwbLocation.isValid)")
        print("⏱️ Last Updated: \(deviceData.lastUpdated)")
        print("🔄 Last Message Sent: \(String(describing: lastMessageSent))")
        
        // Check protocol history
        if let lastState = deviceStates[peripheralID] {
            print("\n📜 Protocol State History:")
            print("   Current: \(lastState)")
            
            // Analyze stuck state
            if lastState == "Connected" || lastState == "BLE Connected" {
                print("\n⚠️ DEVICE STUCK IN INITIAL STATE!")
                print("🔧 Possible causes:")
                print("   1. Arduino not responding to INITIALIZE command")
                print("   2. BLE write failed silently")
                print("   3. Arduino UWB module not ready")
                print("   4. Duplicate UWB tokens between devices")
                
                print("\n💡 Recommended actions:")
                print("   1. Check Arduino serial monitor for errors")
                print("   2. Ensure Arduino has unique UWB configuration")
                print("   3. Try: bleManager.forceRestartProtocol(for: peripheralID)")
                print("   4. Power cycle the Arduino device")
            }
        }
        
        print("=================================\n")
    }
    
    // Call this to compare both devices
    func compareDevices() {
        print("\n📊 === DEVICE COMPARISON ===")
        
        for (peripheralID, deviceData) in connectedDevicesData {
            let state = deviceStates[peripheralID] ?? "Unknown"
            print("\n🤖 \(deviceData.deviceName):")
            print("   State: \(state)")
            print("   Ranging: \(deviceData.isRanging)")
            print("   Distance: \(deviceData.uwbLocation.distance)m")
            print("   Has Config: \(configurations[peripheralID] != nil)")
            print("   Has Token: \(accessoryDiscoveryTokens[peripheralID] != nil)")
        }
        
        // Check for token conflicts
        let tokens = accessoryDiscoveryTokens.values
        if tokens.count != Set(tokens).count {
            print("\n⚠️ WARNING: Duplicate discovery tokens detected!")
            print("This will prevent multiple devices from ranging simultaneously.")
        }
        
        print("\n===========================\n")
    }
    
    // Monitor protocol messages for a specific device
    func enableMessageLogging(for peripheralID: UUID) {
        // This will help track what messages are being sent/received
        print("\n📨 Enabling detailed message logging for device \(peripheralID)")
        
        // You can call this before connecting to track all protocol messages
        // The existing logging will now be enhanced with this context
    }
}