import SwiftUI
import CoreBluetooth
import MessageUI
import NearbyInteraction
import os.log

struct SettingsView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var bleManager: BLEManager
    @State var showingDebugLog = false
    @State var showingProfile = false
    @State var showingNotifications = false
    @State var showingPrivacy = false
    @State var showingMailComposer = false
    @State var displayName: String = SettingsView.loadDisplayName()
    @State var editingDisplayName: Bool = false
    @State var tempDisplayName: String = ""
    @FocusState var isEditingName: Bool
    @Binding var isSidebarOpen: Bool
    
    // Developer options state
    @State var versionClickCount: Int = 0
//    @State private var isDeveloperModeEnabled: Bool = UserDefaults.standard.bool(forKey: "isDeveloperModeEnabled")
    @State var isDeveloperModeEnabled: Bool = false
    
    // QorvoDemoViewController connection logic
    @StateObject private var dataChannel = DataCommunicationChannel()
    @StateObject private var sessionManager = NISessionManager()
    @State private var selectedAccessory = -1
    
    // Scanning state
    @State var isScanning = false
    
    private let logger = os.Logger(subsystem: "com.qorvo.ni", category: "SettingsView")

    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBarView(selectedTab: $selectedTab, isSidebarOpen:$isSidebarOpen)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Section
                        profileSection
                        
                        // Device Management Section
                        deviceManagementSection
                        
                        // App Settings Section
                        appSettingsSection
                        
                        // Support Section
                        supportSection
                        
                        // Debug Section (conditionally shown)
                        if isDeveloperModeEnabled {
                            debugSection
                        }
                        
                        // Version Section
                        versionSection
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingDebugLog) {
            DebugLogView(debugLog: bleManager.debugLog)
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView()
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacyView()
        }
        .sheet(isPresented: $showingMailComposer) {
            if MFMailComposeViewController.canSendMail() {
                MailComposeView(
                    recipients: ["superkatiebros@gmail.com"],
                    subject: "Proxi Support"
                )
            } else {
                MailUnavailableView()
            }
        }
        .onAppear {
            setupDataChannel()
            // Auto-start scanning when view appears
            if !isScanning {
                startScanning()
            }
        }
    }
    
    // MARK: - QorvoDemoViewController Connection Logic Integration
    private func setupDataChannel() {
        dataChannel.accessoryDataHandler = accessorySharedData
        dataChannel.accessorySynchHandler = accessorySynch
        dataChannel.accessoryConnectedHandler = accessoryConnected
        dataChannel.accessoryDisconnectedHandler = accessoryDisconnected
        dataChannel.start()
        
        // Setup session manager callbacks
        setupSessionManagerCallbacks()
        
        logger.info("DataCommunicationChannel initialized in SettingsView")
    }
    
    private func setupSessionManagerCallbacks() {
        sessionManager.onSessionConfigured = { deviceID in
            // Handle session configuration completion
            self.logger.info("Session configured for device \(deviceID)")
        }
        
        sessionManager.onUwbStarted = { deviceID in
            self.logger.info("UWB started for device \(deviceID)")
        }
        
        sessionManager.onUwbStopped = { deviceID in
            self.logger.info("UWB stopped for device \(deviceID)")
        }
        
        sessionManager.onLocationUpdate = { deviceID in
            // Location data has been updated
            // UI will automatically refresh due to @Published properties
        }
        
        sessionManager.onSendData = { data, deviceID in
            // Send data to accessory through data channel
            // This will be handled by the dataChannel directly
            do {
                try self.dataChannel.sendData(data, deviceID)
            } catch {
                self.logger.error("Failed to send data to accessory: \(error)")
            }
        }
    }
}

// MARK: - DataChannel Handler Methods (from QorvoDemoViewController)
extension SettingsView {
    
    func accessorySharedData(data: Data, accessoryName: String, deviceID: Int) {
        // The accessory begins each message with an identifier byte.
        // Ensure the message length is within a valid range.
        if data.count < 1 {
            logger.error("Received invalid data from accessory")
            return
        }
        
        // Assign the first byte which is the message identifier.
        guard let messageId = MessageId(rawValue: data.first!) else {
            logger.error("\(data.first!) is not a valid MessageId.")
            return
        }
        
        // Handle the data portion of the message based on the message identifier.
        switch messageId {
        case .accessoryConfigurationData:
            // Access the message data by skipping the message identifier.
            assert(data.count > 1)
            let message = data.advanced(by: 1)
            setupAccessory(message, name: accessoryName, deviceID: deviceID)
        case .accessoryUwbDidStart:
            handleAccessoryUwbDidStart(deviceID)
        case .accessoryUwbDidStop:
            handleAccessoryUwbDidStop(deviceID)
        case .configureAndStart:
            logger.error("Accessory should not send 'configureAndStart'.")
        case .initialize:
            logger.error("Accessory should not send 'initialize'.")
        case .stop:
            logger.error("Accessory should not send 'stop'.")
        // User defined/notification messages
        case .getReserved:
            logger.debug("Get not implemented in this version")
        case .setReserved:
            logger.debug("Set not implemented in this version")
        case .iOSNotify:
            logger.debug("Notification not implemented in this version")
        }
    }
    
    func accessorySynch(_ index: Int,_ insert: Bool ) {
        // Update device list in settings
        logger.info("Device synch: index \(index), insert: \(insert)")
    }
    
    func accessoryConnected(deviceID: Int) {
        logger.info("Accessory connected: \(deviceID)")
        
        // If no device is selected, select the new device
        if selectedAccessory == -1 {
            selectedAccessory = deviceID
        }
        
        // Create a NISession for the new device using the session manager
        _ = sessionManager.createSession(for: deviceID)
        
        logger.info("Sending initialize message to accessory")
        let msg = Data([MessageId.initialize.rawValue])
        sendDataToAccessory(msg, deviceID)
    }
    
    func accessoryDisconnected(deviceID: Int) {
        logger.info("Accessory disconnected: \(deviceID)")
        sessionManager.invalidateSession(for: deviceID)
        
        if selectedAccessory == deviceID {
            selectedAccessory = -1
        }
    }
    
    // MARK: - Accessory messages handling
    func setupAccessory(_ configData: Data, name: String, deviceID: Int) {
        logger.info("Received configuration data from '\(name)'. Running session.")
        do {
            let config = try NINearbyAccessoryConfiguration(data: configData)
            config.isCameraAssistanceEnabled = true
            sessionManager.configuration = config
        }
        catch {
            logger.error("Failed to create NINearbyAccessoryConfiguration for '\(name)'. Error: \(error)")
            return
        }
        
        // Cache the token to correlate updates with this accessory.
        if let config = sessionManager.configuration {
            sessionManager.cacheToken(config.accessoryDiscoveryToken, accessoryName: name)
            sessionManager.runConfiguration(config, for: deviceID)
        }
        
        logger.info("Session configured for device \(deviceID)")
    }
    
    func handleAccessoryUwbDidStart(_ deviceID: Int) {
        logger.info("Accessory UWB started: \(deviceID)")
        
        // Update the device Status
        if let startedDevice = dataChannel.getDeviceFromUniqueID(deviceID) {
            startedDevice.blePeripheralStatus = statusRanging
        }
    }
    
    func handleAccessoryUwbDidStop(_ deviceID: Int) {
        logger.info("Accessory UWB stopped: \(deviceID)")
        
        // Disconnect from device
        disconnectFromAccessory(deviceID)
    }
    
    // MARK: - Helper Methods
    func connectToAccessory(_ deviceID: Int) {
         logger.info("Attempting to connect to device ID: \(deviceID)")
         
         // Check if device exists
         guard let device = qorvoDevices.compactMap({ $0 }).first(where: { $0.bleUniqueID == deviceID }) else {
             logger.error("Device with ID \(deviceID) not found in qorvoDevices array")
             return
         }
         
         logger.info("Found device: \(device.blePeripheralName) with status: \(device.blePeripheralStatus ?? "nil")")
         
         do {
             try dataChannel.connectPeripheral(deviceID)
             logger.info("Connection attempt initiated for device \(deviceID)")
         } catch {
             logger.error("Failed to connect to accessory: \(error)")
         }
    }
    
    func disconnectFromAccessory(_ deviceID: Int) {
         do {
             try dataChannel.disconnectPeripheral(deviceID)
         } catch {
             logger.error("Failed to disconnect from accessory: \(error)")
         }
     }
    
    func sendDataToAccessory(_ data: Data,_ deviceID: Int) {
         do {
             try dataChannel.sendData(data, deviceID)
         } catch {
             logger.error("Failed to send data to accessory: \(error)")
         }
     }
    
    // MARK: - Scanning and Connection Methods
    func startScanning() {
        if isScanning {
            // Stop scanning
            isScanning = false
            do {
                try dataChannel.stop()
                logger.info("Stopping device scanning")
            } catch {
                logger.error("Failed to stop scanning: \(error)")
            }
        } else {
            // Start scanning
            isScanning = true
            dataChannel.start()
            logger.info("Starting device scanning")
        }
    }
    
    func connectToFirstDiscoveredDevice() {
        let discoveredDevices = qorvoDevices.compactMap { $0 }.filter { $0.blePeripheralStatus == statusDiscovered }
        
        if let firstDevice = discoveredDevices.first {
            logger.info("Attempting to connect to device: \(firstDevice.blePeripheralName) (ID: \(firstDevice.bleUniqueID))")
            
            // Make sure data channel is running
            if !isScanning {
                dataChannel.start()
            }
            
            // Attempt connection
            connectToAccessory(firstDevice.bleUniqueID)
            
            // Stop scanning since we're connecting
            isScanning = false
        } else {
            logger.warning("No discovered devices available to connect")
        }
    }
    
    var hasDiscoveredDevices: Bool {
        qorvoDevices.compactMap { $0 }.contains { $0.blePeripheralStatus == statusDiscovered }
    }
    
    var scanningStatusText: String {
        if isScanning {
            return "Scanning for Qorvo UWB devices..."
        } else if hasDiscoveredDevices {
            return "Found \(qorvoDevices.compactMap { $0 }.filter { $0.blePeripheralStatus == statusDiscovered }.count) device(s)"
        } else if qorvoDevices.compactMap { $0 }.contains(where: { $0.blePeripheralStatus == statusConnected || $0.blePeripheralStatus == statusRanging }) {
            return "Device connected"
        } else {
            return "Not scanning - press 'Start Scanning' to find devices"
        }
    }
    
}

// MARK: - NISession handling is now managed by NISessionManager

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(selectedTab: Binding.constant(4), isSidebarOpen: Binding.constant(false))
    }
}

