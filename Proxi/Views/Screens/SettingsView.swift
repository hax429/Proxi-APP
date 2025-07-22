//
//  SettingsView.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/16/25.
//

/**
 * SettingsView - App Settings and Device Management Hub
 *
 * This is the central settings screen for the Proxi application, providing
 * comprehensive device management, user profile editing, and app configuration.
 * It serves as the main hub for all UWB device operations and user preferences.
 *
 * ## Responsibilities:
 * - UWB device scanning and connection management
 * - User profile editing and management
 * - App settings and preferences
 * - Developer mode and debug features
 * - Support and help resources
 *
 * ## Key Features:
 * - Real-time device discovery with automatic UI updates
 * - Centralized device connection management
 * - Profile picture and username editing
 * - Developer mode with enhanced debugging
 * - Comprehensive app settings interface
 *
 * ## Device Management:
 * - Start/stop device scanning
 * - Connect to discovered devices
 * - Monitor device connection status
 * - Display device information (with developer mode)
 * - Manage multiple device connections
 *
 * ## Profile Management:
 * - Profile picture editing with PhotosUI
 * - Username editing with validation
 * - Real-time profile synchronization
 * - Integration with UserManager
 *
 * ## Developer Features:
 * - Developer mode activation (5-tap version)
 * - Debug log access
 * - Device ID display
 * - Enhanced debugging information
 *
 * ## Usage:
 * ```swift
 * SettingsView(selectedTab: $selectedTab, isSidebarOpen: $isSidebarOpen)
 *     .environmentObject(bleManager)
 *     .environmentObject(userManager)
 * ```
 *
 * ## Architecture:
 * - SwiftUI-based interface
 * - Environment object integration
 * - Timer-based UI updates for device discovery
 * - Modular section-based layout
 * - Dark theme design
 *
 * ## Sections:
 * - Profile: User profile management
 * - Device Management: UWB device operations
 * - App Settings: General app preferences
 * - Support: Help and contact resources
 * - Debug: Developer tools (when enabled)
 * - About: App information and developer mode
 *
 * @author Gabriel Wang
 * @version 1.0.0
 * @since iOS 16.0
 */

import SwiftUI
import CoreBluetooth
import MessageUI
import NearbyInteraction
import os.log

struct SettingsView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var userManager: UserManager
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
    @State var showingDeveloperModeAlert = false
    
    // QorvoDemoViewController connection logic
    @StateObject private var dataChannel = DataCommunicationChannel()
    @StateObject private var sessionManager = NISessionManager()
    @State private var selectedAccessory = -1
    
    // Scanning state
    @State var isScanning = false
    @State var discoveredDevicesCount = 0
    @State var connectedDevicesCount = 0

    // Timer for UI updates
    @State private var timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
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
        .alert("Developer Mode Enabled", isPresented: $showingDeveloperModeAlert) {
            Button("OK") { }
        } message: {
            Text("Developer mode has been enabled. You now have access to debug features and device IDs.")
        }
        .onAppear {
            setupDataChannel()
            // Auto-start scanning when view appears
            if !isScanning {
                startScanning()
            }
        }
        .onReceive(timer) { _ in
            updateDeviceCounts()
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
        
        // Run configuration for this device (token caching is now handled internally)
        if let config = sessionManager.configuration {
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
    
    // MARK: - Timer Management for UI Updates
    // This function is removed as per the edit hint.
    // private func startDeviceUpdateTimer() {
    //     deviceUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
    //         DispatchQueue.main.async {
    //             updateDeviceCounts()
    //         }
    //     }
    // }

    // This function is removed as per the edit hint.
    // private func stopDeviceUpdateTimer() {
    //     deviceUpdateTimer?.invalidate()
    //     deviceUpdateTimer = nil
    // }

    // This function is removed as per the edit hint.
    // private func updateDeviceCounts() {
    //     let discovered = qorvoDevices.compactMap { $0 }.filter { $0.blePeripheralStatus == statusDiscovered }.count
    //     let connected = qorvoDevices.compactMap { $0 }.filter { $0.blePeripheralStatus == statusConnected || $0.blePeripheralStatus == statusRanging }.count
        
    //     if discovered != discoveredDevicesCount || connected != connectedDevicesCount {
    //         discoveredDevicesCount = discovered
    //         connectedDevicesCount = connected
    //         logger.info("Device counts updated - Discovered: \(discovered), Connected: \(connected)")
    //     }
    // }
    
    // MARK: - Device Count Updates
    private func updateDeviceCounts() {
        let discovered = qorvoDevices.compactMap { $0 }.filter { $0.blePeripheralStatus == statusDiscovered }.count
        let connected = qorvoDevices.compactMap { $0 }.filter { $0.blePeripheralStatus == statusConnected || $0.blePeripheralStatus == statusRanging }.count
        
        if discovered != discoveredDevicesCount || connected != connectedDevicesCount {
            discoveredDevicesCount = discovered
            connectedDevicesCount = connected
            logger.info("Device counts updated - Discovered: \(discovered), Connected: \(connected)")
        }
    }
    
    var hasDiscoveredDevices: Bool {
        discoveredDevicesCount > 0
    }
    
    var scanningStatusText: String {
        if connectedDevicesCount > 0 {
            return "UWB device connected and active"
        } else if isScanning {
            return "Scanning for Qorvo UWB devices..."
        } else if discoveredDevicesCount > 0 {
            return "Found \(discoveredDevicesCount) device(s)"
        } else {
            return "Not scanning - press 'Start Scanning' to find devices"
        }
    }
    
}

// MARK: - Section Views
extension SettingsView {
    
    var profileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Profile Image
                Button(action: { showingProfile = true }) {
                    HStack {
                        if let profileImage = userManager.getProfileImage() {
                            Image(uiImage: profileImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        } else {
                            Image("Profile placeholder")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(userManager.userProfile?.name ?? displayName)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Tap to edit profile")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding()
                    .background(Color(hex: "232229"))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    var deviceManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Device Management")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Combined Status and Connected Device - When device is connected
                if connectedDevicesCount > 0 {
                    ForEach(Array(qorvoDevices.compactMap { $0 }.filter { $0.blePeripheralStatus == statusConnected || $0.blePeripheralStatus == statusRanging }.enumerated()), id: \.element.bleUniqueID) { index, device in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.blePeripheralName)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(device.blePeripheralStatus ?? "Connected")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                if isDeveloperModeEnabled {
                                    Text("ID: \(device.bleUniqueID)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            
                            Spacer()
                            
                            // Connection Status Indicator
                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                            
                            // Disconnect Button
                            Button(action: { disconnectFromAccessory(device.bleUniqueID) }) {
                                Text("Disconnect")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.red)
                                    .cornerRadius(6)
                            }
                        }
                        .padding()
                        .background(Color(hex: "232229"))
                        .cornerRadius(12)
                    }
                } else {
                    // Scanning Status - When no devices are connected
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("UWB Device")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(scanningStatusText)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        // Connection Status Indicator
                        Circle()
                            .fill(discoveredDevicesCount > 0 ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                    }
                    .padding()
                    .background(Color(hex: "232229"))
                    .cornerRadius(12)
                }
                
                // Scanning Controls - Only show when no devices are connected
                if connectedDevicesCount == 0 {
                    HStack(spacing: 12) {
                        Button(action: startScanning) {
                            HStack {
                                Image(systemName: isScanning ? "stop.circle.fill" : "magnifyingglass")
                                Text(isScanning ? "Stop Scanning" : "Start Scanning")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                        
                        if hasDiscoveredDevices {
                            Button(action: connectToFirstDiscoveredDevice) {
                                HStack {
                                    Image(systemName: "link")
                                    Text("Connect")
                                }
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                
                // Discovered Devices List - Only show when no devices are connected
                if discoveredDevicesCount > 0 && connectedDevicesCount == 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Discovered Devices")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        ForEach(Array(qorvoDevices.compactMap { $0 }.filter { $0.blePeripheralStatus == statusDiscovered }.enumerated()), id: \.element.bleUniqueID) { index, device in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.blePeripheralName)
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                    if isDeveloperModeEnabled {
                                        Text("ID: \(device.bleUniqueID)")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: { connectToAccessory(device.bleUniqueID) }) {
                                    Text("Connect")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue)
                                        .cornerRadius(6)
                                }
                            }
                            .padding()
                            .background(Color(hex: "232229"))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
    
    var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("App Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 12) {
                Button(action: { showingNotifications = true }) {
                    SettingsRow(title: "Notifications", icon: "bell", showChevron: true)
                }
                
                Button(action: { showingPrivacy = true }) {
                    SettingsRow(title: "Privacy & Security", icon: "lock", showChevron: true)
                }
            }
        }
    }
    
    var supportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Support")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 12) {
                Button(action: { showingMailComposer = true }) {
                    SettingsRow(title: "Contact Support", icon: "envelope", showChevron: true)
                }
                
                if isDeveloperModeEnabled {
                    Button(action: { showingDebugLog = true }) {
                        SettingsRow(title: "Debug Log", icon: "doc.text", showChevron: true)
                    }
                }
            }
        }
    }
    
    var debugSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Debug Options")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Add debug-specific controls here
                Text("Debug options available")
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    var versionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("About")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    versionClickCount += 1
                    if versionClickCount >= 5 {
                        isDeveloperModeEnabled.toggle()
                        UserDefaults.standard.set(isDeveloperModeEnabled, forKey: "isDeveloperModeEnabled")
                        versionClickCount = 0
                        if isDeveloperModeEnabled {
                            showingDeveloperModeAlert = true
                        }
                    }
                }) {
                    SettingsRow(title: "Version 1.0.0", icon: "info.circle", showChevron: false)
                }
            }
        }
    }
}

// MARK: - Helper Views
struct SettingsRow: View {
    let title: String
    let icon: String
    let showChevron: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 20)
            
            Text(title)
                .foregroundColor(.white)
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding()
        .background(Color(hex: "232229"))
        .cornerRadius(12)
    }
}

// MARK: - Helper Methods
extension SettingsView {
    static func loadDisplayName() -> String {
        return UserDefaults.standard.string(forKey: "displayName") ?? "User"
    }
}

// MARK: - NISession handling is now managed by NISessionManager

