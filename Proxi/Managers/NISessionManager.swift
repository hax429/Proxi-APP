import Foundation
import NearbyInteraction
import os.log
import Combine

class NISessionManager: NSObject, ObservableObject {
    
    // MARK: - Device-specific storage for multiple connections
    // Store configurations per device
    private var deviceConfigurations = [Int: NINearbyAccessoryConfiguration]()
    // Store discovery tokens per device
    private var deviceDiscoveryTokens = [Int: NIDiscoveryToken]()
    // Dictionary to associate each NI Session to the qorvoDevice using the uniqueID
    private var referenceDict = [Int:NISession]()
    // Store convergence state per device
    private var deviceConvergenceStates = [Int: Bool]()
    
    // Legacy single device support (for backward compatibility)
    @Published var configuration: NINearbyAccessoryConfiguration? {
        didSet {
            // When single configuration is set, also update the first device's configuration
            if let firstDeviceID = referenceDict.keys.first {
                deviceConfigurations[firstDeviceID] = configuration
                if let token = configuration?.accessoryDiscoveryToken {
                    deviceDiscoveryTokens[firstDeviceID] = token
                }
            }
        }
    }
    @Published var isConverged = false
    
    private let logger = os.Logger(subsystem: "com.qorvo.ni", category: "NISessionManager")
    
    // Callbacks to communicate with SettingsView
    var onSessionConfigured: ((Int) -> Void)?
    var onUwbStarted: ((Int) -> Void)?
    var onUwbStopped: ((Int) -> Void)?
    var onLocationUpdate: ((Int) -> Void)?
    var onSendData: ((Data, Int) -> Void)?
    
    override init() {
        super.init()
        logger.info("NISessionManager initialized with multiple device support")
    }
    
    // MARK: - Public Methods
    func createSession(for deviceID: Int) -> NISession? {
        let session = NISession()
        session.delegate = self
        referenceDict[deviceID] = session
        deviceConvergenceStates[deviceID] = false
        logger.info("Created NI session for device \(deviceID)")
        return session
    }
    
    func invalidateSession(for deviceID: Int) {
        referenceDict[deviceID]?.invalidate()
        referenceDict.removeValue(forKey: deviceID)
        deviceConfigurations.removeValue(forKey: deviceID)
        deviceDiscoveryTokens.removeValue(forKey: deviceID)
        deviceConvergenceStates.removeValue(forKey: deviceID)
        logger.info("Invalidated NI session for device \(deviceID)")
    }
    
    func runConfiguration(_ config: NINearbyAccessoryConfiguration, for deviceID: Int) {
        // Store configuration for this specific device
        deviceConfigurations[deviceID] = config
        deviceDiscoveryTokens[deviceID] = config.accessoryDiscoveryToken
        
        // Run the session with the configuration
        referenceDict[deviceID]?.run(config)
        
        logger.info("Running configuration for device \(deviceID)")
    }
    
    func sendData(_ data: Data, to deviceID: Int, dataChannel: DataCommunicationChannel) {
        do {
            try dataChannel.sendData(data, deviceID)
        } catch {
            logger.error("Failed to send data to accessory \(deviceID): \(error)")
        }
    }
    
    // MARK: - Private Helper Methods
    private func deviceIDFromSession(_ session: NISession) -> Int {
        for (key, value) in referenceDict {
            if value === session {  // Use === for reference equality
                return key
            }
        }
        return -1
    }
    
    private func deviceIDFromDiscoveryToken(_ token: NIDiscoveryToken) -> Int? {
        for (deviceID, storedToken) in deviceDiscoveryTokens {
            if storedToken == token {
                return deviceID
            }
        }
        return nil
    }
    
    private func shouldRetry(_ deviceID: Int) -> Bool {
        guard let qorvoDevice = qorvoDevices.compactMap({ $0 }).first(where: { $0.bleUniqueID == deviceID }) else {
            return false
        }
        
        return qorvoDevice.blePeripheralStatus != statusDiscovered
    }
    
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
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let accessory = nearbyObjects.first else {
            logger.warning("No nearby objects in session update")
            return
        }
        
        let deviceID = deviceIDFromSession(session)
        guard deviceID != -1 else {
            logger.error("Could not find device ID for session update")
            return
        }
        
        // Check if distance is available
        if let distance = accessory.distance {
            print("📍 NISessionManager: Distance update - DeviceID: \(deviceID), Distance: \(distance)")
            
            if let updatedDevice = qorvoDevices.compactMap({ $0 }).first(where: { $0.bleUniqueID == deviceID }) {
                // Ensure uwbLocation exists
                if updatedDevice.uwbLocation == nil {
                    print("⚠️ NISessionManager: uwbLocation was nil for device \(updatedDevice.blePeripheralName), creating new Location")
                    updatedDevice.uwbLocation = Location(
                        distance: 0,
                        direction: SIMD3<Float>(x: 0, y: 0, z: 0),
                        elevation: NINearbyObject.VerticalDirectionEstimate.unknown.rawValue,
                        noUpdate: false
                    )
                }
                
                // Update distance
                updatedDevice.uwbLocation?.distance = distance
                print("✅ NISessionManager: Updated distance for \(updatedDevice.blePeripheralName) to \(distance)")
        
                // Update direction data
                if let direction = accessory.direction {
                    updatedDevice.uwbLocation?.direction = direction
                    updatedDevice.uwbLocation?.noUpdate = false
                    print("📍 NISessionManager: Updated direction for \(updatedDevice.blePeripheralName)")
                }
                else if deviceConvergenceStates[deviceID] == true {
                    guard let horizontalAngle = accessory.horizontalAngle else {
                        logger.warning("No horizontal angle available for converged session")
                        return
                    }
                    updatedDevice.uwbLocation?.direction = getDirectionFromHorizontalAngle(rad: horizontalAngle)
                    updatedDevice.uwbLocation?.elevation = accessory.verticalDirectionEstimate.rawValue
                    updatedDevice.uwbLocation?.noUpdate = false
                    print("📍 NISessionManager: Updated converged direction for \(updatedDevice.blePeripheralName)")
                }
                else {
                    updatedDevice.uwbLocation?.noUpdate = true
                    print("📍 NISessionManager: Set noUpdate=true for \(updatedDevice.blePeripheralName)")
                }
        
                // Update status to ranging
                updatedDevice.blePeripheralStatus = statusRanging
            } else {
                print("❌ NISessionManager: Device with ID \(deviceID) not found in qorvoDevices")
            }
        } else {
            // Distance not available - device might be too close or ranging not fully established
            print("⚠️ NISessionManager: No distance available for device \(deviceID) - checking if device exists")
            
            if let updatedDevice = qorvoDevices.compactMap({ $0 }).first(where: { $0.bleUniqueID == deviceID }) {
                print("⚠️ NISessionManager: Device \(updatedDevice.blePeripheralName) found but no distance - possible ranging initialization")
                
                // Initialize uwbLocation if it doesn't exist
                if updatedDevice.uwbLocation == nil {
                    print("⚠️ NISessionManager: Creating initial uwbLocation for \(updatedDevice.blePeripheralName)")
                    updatedDevice.uwbLocation = Location(
                        distance: 0,
                        direction: SIMD3<Float>(x: 0, y: 0, z: 0),
                        elevation: NINearbyObject.VerticalDirectionEstimate.unknown.rawValue,
                        noUpdate: true
                    )
                }
                
                // Keep device in ranging status but mark no distance update
                updatedDevice.blePeripheralStatus = statusRanging
                updatedDevice.uwbLocation?.noUpdate = true
                print("⚠️ NISessionManager: Device \(updatedDevice.blePeripheralName) marked as ranging but no distance available")
            }
        }
        
        onLocationUpdate?(deviceID)
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        let deviceID = deviceIDFromSession(session)
        guard deviceID != -1 else { return }
        
        switch reason {
        case .timeout:
            logger.info("Session timeout for device \(deviceID)")
            
            // Mark device as having no distance data due to timeout
            if let device = qorvoDevices.compactMap({ $0 }).first(where: { $0.bleUniqueID == deviceID }) {
                device.uwbLocation?.distance = 0
                device.uwbLocation?.noUpdate = true
                print("⚠️ NISessionManager: Device \(device.blePeripheralName) session timed out - clearing distance")
            }
            
            // Consult helper function to decide whether or not to retry
            if shouldRetry(deviceID) {
                logger.info("Will retry session for device \(deviceID)")
            }
        case .peerEnded:
            logger.info("Peer ended session for device \(deviceID)")
        @unknown default:
            logger.info("Unknown reason for session removal: \(reason.rawValue)")
        }
    }
    
    func sessionWasSuspended(_ session: NISession) {
        logger.info("Session suspended")
        let deviceID = deviceIDFromSession(session)
        // Handle through callback if needed
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        logger.info("Session suspension ended")
        let deviceID = deviceIDFromSession(session)
        // Handle through callback if needed
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        let deviceID = deviceIDFromSession(session)
        guard deviceID != -1 else { return }
        
        switch error {
        case NIError.invalidConfiguration:
            logger.error("Invalid NI configuration for device \(deviceID)")
        case NIError.userDidNotAllow:
            logger.error("User did not allow NI access")
        default:
            logger.error("Session invalidated for device \(deviceID): \(error)")
            // Handle through callback if needed
        }
        
        // Clean up device-specific data
        deviceConfigurations.removeValue(forKey: deviceID)
        deviceDiscoveryTokens.removeValue(forKey: deviceID)
        deviceConvergenceStates.removeValue(forKey: deviceID)
    }
    
    // MARK: - Helper method from original code
    private func getDirectionFromHorizontalAngle(rad: Float) -> simd_float3 {
        return simd_float3(x: sin(rad), y: 0, z: cos(rad))
    }
}
