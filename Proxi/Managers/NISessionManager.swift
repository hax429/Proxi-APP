import Foundation
import NearbyInteraction
import os.log
import Combine

class NISessionManager: NSObject, ObservableObject {
    
    @Published var configuration: NINearbyAccessoryConfiguration?
    @Published var isConverged = false
    
    // Dictionary to associate each NI Session to the qorvoDevice using the uniqueID
    private var referenceDict = [Int:NISession]()
    // A mapping from a discovery token to a name.
    private var accessoryMap = [NIDiscoveryToken: String]()
    
    private let logger = os.Logger(subsystem: "com.qorvo.ni", category: "NISessionManager")
    
    // Callbacks to communicate with SettingsView
    var onSessionConfigured: ((Int) -> Void)?
    var onUwbStarted: ((Int) -> Void)?
    var onUwbStopped: ((Int) -> Void)?
    var onLocationUpdate: ((Int) -> Void)?
    var onSendData: ((Data, Int) -> Void)?
    
    override init() {
        super.init()
        logger.info("NISessionManager initialized")
    }
    
    // MARK: - Public Methods
    func createSession(for deviceID: Int) -> NISession? {
        let session = NISession()
        session.delegate = self
        referenceDict[deviceID] = session
        logger.info("Created NI session for device \(deviceID)")
        return session
    }
    
    func invalidateSession(for deviceID: Int) {
        referenceDict[deviceID]?.invalidate()
        referenceDict.removeValue(forKey: deviceID)
        logger.info("Invalidated NI session for device \(deviceID)")
    }
    
    func runConfiguration(_ config: NINearbyAccessoryConfiguration, for deviceID: Int) {
        referenceDict[deviceID]?.run(config)
    }
    
    func cacheToken(_ token: NIDiscoveryToken, accessoryName: String) {
        accessoryMap[token] = accessoryName
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
        var deviceID = -1
        
        for (key, value) in referenceDict {
            if value == session {
                deviceID = key
            }
        }
        
        return deviceID
    }
    
    private func shouldRetry(_ deviceID: Int) -> Bool {
        guard let qorvoDevice = qorvoDevices.compactMap({ $0 }).first(where: { $0.bleUniqueID == deviceID }) else {
            return false
        }
        
        return qorvoDevice.blePeripheralStatus != statusDiscovered
    }
    
    private func handleSessionInvalidation(_ deviceID: Int, dataChannel: DataCommunicationChannel) {
        logger.info("Handling session invalidation for device \(deviceID)")
        // Ask the accessory to stop.
        sendData(Data([MessageId.stop.rawValue]), to: deviceID, dataChannel: dataChannel)

        // Replace the invalidated session with a new one.
        let newSession = NISession()
        newSession.delegate = self
        referenceDict[deviceID] = newSession

        // Ask the accessory to initialize.
        sendData(Data([MessageId.initialize.rawValue]), to: deviceID, dataChannel: dataChannel)
    }
}

// MARK: - NISessionDelegate
extension NISessionManager: NISessionDelegate {

    func session(_ session: NISession, didGenerateShareableConfigurationData shareableConfigurationData: Data, for object: NINearbyObject) {
        guard object.discoveryToken == configuration?.accessoryDiscoveryToken else { return }
        
        // Prepare to send a message to the accessory.
        var msg = Data([MessageId.configureAndStart.rawValue])
        msg.append(shareableConfigurationData)
        
        let str = msg.map { String(format: "0x%02x, ", $0) }.joined()
        logger.info("Sending shareable configuration bytes: \(str)")
        
        let deviceID = deviceIDFromSession(session)
        onSessionConfigured?(deviceID)
        onSendData?(msg, deviceID)
    }
    
    func session(_ session: NISession, didUpdateAlgorithmConvergence convergence: NIAlgorithmConvergence, for object: NINearbyObject?) {
        guard object != nil else { return}
    
        DispatchQueue.main.async {
            switch convergence.status {
            case .converged:
                self.logger.info("Device Converged")
                self.isConverged = true
            case .notConverged(_):
                self.isConverged = false
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let accessory = nearbyObjects.first else { return }
        guard let distance  = accessory.distance else { return }
        
        let deviceID = deviceIDFromSession(session)
    
        if let updatedDevice = qorvoDevices.compactMap({ $0 }).first(where: { $0.bleUniqueID == deviceID }) {
            // set updated values
            updatedDevice.uwbLocation?.distance = distance
    
            if let direction = accessory.direction {
                updatedDevice.uwbLocation?.direction = direction
                updatedDevice.uwbLocation?.noUpdate  = false
            }
            else if isConverged {
                guard let horizontalAngle = accessory.horizontalAngle else {return}
                updatedDevice.uwbLocation?.direction = getDirectionFromHorizontalAngle(rad: horizontalAngle)
                updatedDevice.uwbLocation?.elevation = accessory.verticalDirectionEstimate.rawValue
                updatedDevice.uwbLocation?.noUpdate  = false
            }
            else {
                updatedDevice.uwbLocation?.noUpdate  = true
            }
    
            updatedDevice.blePeripheralStatus = statusRanging
        }
        
        onLocationUpdate?(deviceID)
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        // Retry the session only if the peer timed out.
        guard reason == .timeout else { return }
        logger.info("Session timeout for device")
        
        // The session runs with one accessory.
        guard let accessory = nearbyObjects.first else { return }
        
        // Clear the app's accessory state.
        accessoryMap.removeValue(forKey: accessory.discoveryToken)
        
        // Get the deviceID associated to the NISession
        let deviceID = deviceIDFromSession(session)
        
        // Consult helper function to decide whether or not to retry.
        if shouldRetry(deviceID) {
            // Retry will be handled through callbacks
        }
    }
    
    func sessionWasSuspended(_ session: NISession) {
        logger.info("Session suspended")
        let deviceID = deviceIDFromSession(session)
        // Handle through callback
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        logger.info("Session suspension ended")
        let deviceID = deviceIDFromSession(session)
        // Handle through callback
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        let deviceID = deviceIDFromSession(session)
        
        switch error {
        case NIError.invalidConfiguration:
            logger.error("Invalid NI configuration")
        case NIError.userDidNotAllow:
            logger.error("User did not allow NI access")
        default:
            logger.error("Session invalidated: \(error)")
            // Handle through callback if needed
        }
    }
}