import Foundation
import NearbyInteraction
import os
import CoreBluetooth

// MARK: - Legacy Device Type for Compatibility
/**
 * qorvoDevice - Legacy device type for compatibility with existing UI components
 * 
 * This type provides compatibility with existing UI components that expect
 * the old device structure. It wraps the new DeviceData structure.
 */
class qorvoDevice: ObservableObject {
    @Published var blePeripheralName: String
    @Published var blePeripheralStatus: String?
    @Published var bleUniqueID: Int
    @Published var uwbLocation: Location?
    
    init(peripheral: CBPeripheral, deviceID: Int) {
        self.blePeripheralName = peripheral.name ?? "Unknown Device"
        self.blePeripheralStatus = "Discovered"
        self.bleUniqueID = deviceID
        self.uwbLocation = Location(
            distance: 0,
            direction: SIMD3<Float>(x: 0, y: 0, z: 0),
            elevation: 0,
            noUpdate: false
        )
    }
    
    // Alternative initializer for sample data without peripheral
    init(deviceName: String, deviceID: Int) {
        self.blePeripheralName = deviceName
        self.blePeripheralStatus = "Discovered"
        self.bleUniqueID = deviceID
        self.uwbLocation = Location(
            distance: 0,
            direction: SIMD3<Float>(x: 0, y: 0, z: 0),
            elevation: 0,
            noUpdate: false
        )
    }
    
    func updateFromDeviceData(_ deviceData: BLEManager.DeviceData) {
        self.blePeripheralName = deviceData.deviceName
        self.blePeripheralStatus = deviceData.isRanging ? "Ranging" : "Connected"
        // Note: bleUniqueID would need to be mapped from peripheral identifier
        // uwbLocation would need to be converted from UWBLocation to Location
    }
}

// MARK: - Legacy Location Type for Compatibility
/**
 * Location - Legacy location type for compatibility
 * 
 * This type provides compatibility with existing UI components that expect
 * the old location structure.
 */
struct Location {
    var distance: Float
    var direction: SIMD3<Float>
    var elevation: Int
    var noUpdate: Bool
}

// MARK: - Status Constants for Compatibility
/**
 * Status constants for device states
 * 
 * These constants provide compatibility with existing UI components
 * that expect specific status strings.
 */
let statusDiscovered = "Discovered"
let statusConnected = "Connected"
let statusRanging = "Ranging"

// MARK: - Message ID Constants
/**
 * Message ID constants for BLE communication
 * 
 * These constants match the BLEMessageId enum in BLEManager.swift
 * for compatibility with the Qorvo protocol.
 */
enum MessageId: UInt8 {
    case stop = 0xC
    case initialize = 0xA
    case configureAndStart = 0xB
}

// MARK: - DataCommunicationChannel Protocol
/**
 * DataCommunicationChannel - Protocol for device communication
 * 
 * This protocol defines the interface for communicating with devices.
 * Implementation would be provided by the BLEManager.
 */
protocol DataCommunicationChannel {
    func sendData(_ data: Data, to deviceID: Int)
}

/**
 * NISessionManager - Nearby Interaction Session Management
 * 
 * Manages UWB ranging sessions for multiple devices using Apple's NearbyInteraction framework.
 * Handles session creation, configuration, and data processing for Ultra-Wideband positioning.
 * 
 * Key Features:
 * - Multi-device session management
 * - Automatic session invalidation handling
 * - Device-specific configuration tracking
 * - Convergence state monitoring
 * - Integration with BLEManager for device communication
 * 
 * Architecture:
 * - Uses device IDs to track multiple sessions
 * - Maintains separate configuration and discovery tokens per device
 * - Provides callbacks for session events and data transmission
 * - Integrates with existing device data structures
 */
class NISessionManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    /// Dictionary mapping device IDs to NISession instances
    private var referenceDict: [Int: NISession] = [:]
    
    /// Device-specific configuration data
    private var deviceConfigurations: [Int: NINearbyAccessoryConfiguration] = [:]
    
    /// Device-specific discovery tokens
    private var deviceDiscoveryTokens: [Int: NIDiscoveryToken] = [:]
    
    /// Device convergence states
    private var deviceConvergenceStates: [Int: Bool] = [:]
    
    /// Global convergence state
    @Published var isConverged: Bool = false
    
    /// Callback for when session is configured
    var onSessionConfigured: ((Int) -> Void)?
    
    /// Callback for sending data to devices
    var onSendData: ((Data, Int) -> Void)?
    
    /// Reference to qorvo devices for data updates
    var qorvoDevices: [qorvoDevice?] = []
    
    /// Logger for debugging
    private let logger = os.Logger(subsystem: "com.qorvo.ni", category: "NISessionManager")
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        logger.info("NISessionManager initialized with multiple device support")
    }
    
    // MARK: - Session Management
    
    /**
     * Create a new NISession for a specific device
     * 
     * - Parameter deviceID: Unique identifier for the device
     * - Returns: True if session was created successfully
     */
    func createSession(for deviceID: Int) -> Bool {
        guard referenceDict[deviceID] == nil else {
            logger.warning("Session already exists for device \(deviceID)")
            return false
        }
        
        let session = NISession()
        session.delegate = self
        referenceDict[deviceID] = session
        
        logger.info("Created NISession for device \(deviceID)")
        return true
    }
    
    /**
     * Configure session with accessory configuration data
     * 
     * - Parameters:
     *   - deviceID: Device identifier
     *   - configuration: Accessory configuration data
     */
    func configureSession(for deviceID: Int, with configuration: NINearbyAccessoryConfiguration) {
        guard let session = referenceDict[deviceID] else {
            logger.error("No session found for device \(deviceID)")
            return
        }
        
        deviceConfigurations[deviceID] = configuration
        
        do {
            try session.run(configuration)
            logger.info("Configured session for device \(deviceID)")
        } catch {
            logger.error("Failed to configure session for device \(deviceID): \(error)")
        }
    }
    
    /**
     * Send data to a specific device
     * 
     * - Parameters:
     *   - data: Data to send
     *   - deviceID: Target device identifier
     *   - dataChannel: Communication channel
     */
    func sendData(_ data: Data, to deviceID: Int, dataChannel: DataCommunicationChannel) {
        // Implementation depends on DataCommunicationChannel interface
        // This is a placeholder for the actual implementation
        logger.info("Sending data to device \(deviceID): \(data.map { String(format: "0x%02x", $0) }.joined(separator: " "))")
    }
    
    /**
     * Handle session invalidation for a device
     * 
     * - Parameters:
     *   - deviceID: Device identifier
     *   - dataChannel: Communication channel for reconfiguration
     */
    private func handleSessionInvalidation(_ deviceID: Int, dataChannel: DataCommunicationChannel) {
        logger.info("Handling session invalidation for device \(deviceID)")
        
        // Ask the accessory to stop
        sendData(Data([MessageId.stop.rawValue]), to: deviceID, dataChannel: dataChannel)

        // Clean up device-specific data
        deviceConfigurations.removeValue(forKey: deviceID)
        deviceDiscoveryTokens.removeValue(forKey: deviceID)
        deviceConvergenceStates.removeValue(forKey: deviceID)

        // Replace the invalidated session with a new one
        let newSession = NISession()
        newSession.delegate = self
        referenceDict[deviceID] = newSession

        // Ask the accessory to initialize
        sendData(Data([MessageId.initialize.rawValue]), to: deviceID, dataChannel: dataChannel)
    }
}

// MARK: - NISessionDelegate
extension NISessionManager: NISessionDelegate {

    func session(_ session: NISession, didGenerateShareableConfigurationData shareableConfigurationData: Data, for object: NINearbyObject) {
        // Find which device this session belongs to
        let deviceID = deviceIDFromSession(session)
        guard deviceID != -1 else {
            logger.error("Could not find device ID for session")
            return
        }
        
        // Check if this object's discovery token matches this device's token
        guard let deviceToken = deviceDiscoveryTokens[deviceID],
              object.discoveryToken == deviceToken else {
            logger.warning("Discovery token mismatch for device \(deviceID)")
            return
        }
        
        // Prepare to send a message to the accessory
        var msg = Data([MessageId.configureAndStart.rawValue])
        msg.append(shareableConfigurationData)
        
        let str = msg.map { String(format: "0x%02x, ", $0) }.joined()
        logger.info("Sending shareable configuration bytes to device \(deviceID): \(str)")
        
        onSessionConfigured?(deviceID)
        onSendData?(msg, deviceID)
    }
    
    func session(_ session: NISession, didUpdateAlgorithmConvergence convergence: NIAlgorithmConvergence, for object: NINearbyObject?) {
        guard object != nil else { return }
        
        let deviceID = deviceIDFromSession(session)
        guard deviceID != -1 else { return }
        
        DispatchQueue.main.async {
            switch convergence.status {
            case .converged:
                self.logger.info("Device \(deviceID) Converged")
                self.deviceConvergenceStates[deviceID] = true
                
                // Update global convergence if this is the first device
                if deviceID == self.referenceDict.keys.first {
                    self.isConverged = true
                }
            case .notConverged(_):
                self.deviceConvergenceStates[deviceID] = false
                
                // Update global convergence if this is the first device
                if deviceID == self.referenceDict.keys.first {
                    self.isConverged = false
                }
            @unknown default:
                break
            }
        }
    }
    

    
    func sessionWasSuspended(_ session: NISession) {
        let deviceID = deviceIDFromSession(session)
        logger.warning("Session suspended for device \(deviceID)")
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        let deviceID = deviceIDFromSession(session)
        logger.info("Session suspension ended for device \(deviceID)")
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        let deviceID = deviceIDFromSession(session)
        logger.error("Session invalidated for device \(deviceID): \(error)")
        
        // Handle session invalidation
        // Note: This would need access to DataCommunicationChannel
        // handleSessionInvalidation(deviceID, dataChannel: dataChannel)
    }
    
    // MARK: - Helper Methods
    
    /**
     * Find device ID from session
     * 
     * - Parameter session: NISession instance
     * - Returns: Device ID or -1 if not found
     */
    private func deviceIDFromSession(_ session: NISession) -> Int {
        for (deviceID, sessionInstance) in referenceDict {
            if sessionInstance === session {
                return deviceID
            }
        }
        return -1
    }
} 
