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
    @State var isDeveloperModeEnabled: Bool = UserDefaults.standard.bool(forKey: "isDeveloperModeEnabled")
    @State var showingDeveloperModeAlert = false
    @State var forcedElevationValue: String = UserDefaults.standard.string(forKey: "forcedElevationValue") ?? "DISABLED"
    @State var forcedDistanceValue: String = UserDefaults.standard.string(forKey: "forcedDistanceValue") ?? ""
    @State var isDistanceOverrideEnabled: Bool = UserDefaults.standard.bool(forKey: "isDistanceOverrideEnabled")
    @State var showingDirectionOverride = false
    @State var showingCalibration = false
    
    // Scanning state
    @State var discoveredDevicesCount = 0
    @State var connectedDevicesCount = 0

    // Timer for real-time UI updates
    @State private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
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
        .sheet(isPresented: $showingDirectionOverride) {
            DirectionOverrideView()
        }
        .sheet(isPresented: $showingCalibration) {
            CalibrationView()
        }
        .alert("Developer Mode Enabled", isPresented: $showingDeveloperModeAlert) {
            Button("OK") { }
        } message: {
            Text("Developer mode has been enabled. You now have access to debug features and device IDs.")
        }
        .onAppear {
            // Auto-start scanning when view appears
            if !bleManager.isScanning {
                bleManager.startScanning()
            }
        }
        .onReceive(timer) { _ in
            updateDeviceCounts()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UWBLocationUpdated"))) { _ in
            // Immediate refresh when UWB location data changes
            updateDeviceCounts()
        }
    }
    
    // MARK: - Scanning and Connection Methods
    func startScanning() {
        if bleManager.isScanning {
            // Stop scanning
            bleManager.stopScanning()
            logger.info("Stopping device scanning")
        } else {
            // Start scanning
            bleManager.startScanning()
            logger.info("Starting device scanning")
        }
    }
    
    func connectToFirstDiscoveredDevice() {
        let discoveredDevices = bleManager.discoveredPeripherals
        
        if let firstDevice = discoveredDevices.first {
            logger.info("Attempting to connect to device: \(firstDevice.name ?? "Unknown") (ID: \(firstDevice.identifier))")
            
            // Make sure scanning is running
            if !bleManager.isScanning {
                bleManager.startScanning()
            }
            
            // Attempt connection
            bleManager.connect(to: firstDevice)
            
            // Stop scanning since we're connecting
            bleManager.stopScanning()
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
        let discovered = bleManager.discoveredPeripherals.count
        let connected = bleManager.connectedPeripherals.count
        
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
        } else if bleManager.isScanning {
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
                // In developer mode, always show devices regardless of connection status
                if connectedDevicesCount > 0 || isDeveloperModeEnabled {
                    ForEach(Array(bleManager.connectedPeripherals.values), id: \.identifier) { peripheral in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(peripheral.name ?? "Unknown Device")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(bleManager.isDeviceRanging(for: peripheral.identifier) ? "Ranging" : "Connected")
                                    .font(.caption)
                                    .foregroundColor(bleManager.isDeviceRanging(for: peripheral.identifier) ? .green : .blue)
                                if isDeveloperModeEnabled {
                                    Text("ID: \(peripheral.identifier)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            
                            Spacer()
                            
                            // Connection Status Indicator (shows ranging status)
                            Circle()
                                .fill(bleManager.isDeviceRanging(for: peripheral.identifier) ? Color.green : Color.blue)
                                .frame(width: 12, height: 12)
                                .animation(.easeInOut(duration: 0.2), value: bleManager.isDeviceRanging(for: peripheral.identifier))
                            
                            // Disconnect Button
                            Button(action: { bleManager.disconnect(peripheralID: peripheral.identifier) }) {
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
                
                // Scanning Controls - Only show when no devices are connected (unless developer mode)
                if connectedDevicesCount == 0 && !isDeveloperModeEnabled {
                    HStack(spacing: 12) {
                        Button(action: startScanning) {
                            HStack {
                                Image(systemName: bleManager.isScanning ? "stop.circle.fill" : "magnifyingglass")
                                Text(bleManager.isScanning ? "Stop Scanning" : "Start Scanning")
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
                
                // Discovered Devices List - Only show when no devices are connected (unless developer mode)
                if discoveredDevicesCount > 0 && (connectedDevicesCount == 0 && !isDeveloperModeEnabled) {
                    VStack(alignment: .leading, spacing: 8) {
                        
                        Text("Discovered Devices")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        ForEach(bleManager.discoveredPeripherals, id: \.identifier) { peripheral in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(peripheral.name ?? "Unknown Device")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                    if isDeveloperModeEnabled {
                                        Text("ID: \(peripheral.identifier)")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: { bleManager.connect(to: peripheral) }) {
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
                
                // Elevation Force Picker
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Force Elevation Value")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text("Override all elevation values with selected option")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Picker("Force Elevation", selection: $forcedElevationValue) {
                        Text("Disabled").tag("DISABLED")
                        Text("Same Level").tag("SAME LEVEL")
                        Text("Above").tag("ABOVE")
                        Text("Below").tag("BELOW")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: forcedElevationValue) { value in
                        UserDefaults.standard.set(value, forKey: "forcedElevationValue")
                    }
                }
                .padding()
                .background(Color(hex: "232229"))
                .cornerRadius(12)
                
                // Force Distance Override
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Force Distance Override")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text("Override distance display with custom value")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    HStack(spacing: 12) {
                        Toggle("Enable Override", isOn: $isDistanceOverrideEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .onChange(of: isDistanceOverrideEnabled) { value in
                                UserDefaults.standard.set(value, forKey: "isDistanceOverrideEnabled")
                            }
                        
                        if isDistanceOverrideEnabled {
                            TextField("Distance (e.g., 23)", text: $forcedDistanceValue)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                                .frame(width: 120)
                                .onChange(of: forcedDistanceValue) { value in
                                    UserDefaults.standard.set(value, forKey: "forcedDistanceValue")
                                }
                        }
                    }
                }
                .padding()
                .background(Color(hex: "232229"))
                .cornerRadius(12)
                
                // Direction Override Control
                Button(action: { showingDirectionOverride = true }) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Force Direction Override")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Text("Override compass direction with custom angle")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        HStack {
                            Image(systemName: "location.north.circle")
                                .foregroundColor(.blue)
                            Text("Configure Direction")
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding()
                    .background(Color(hex: "232229"))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // UWB Debug Window Toggle
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowUWBDebugWindow"), object: nil)
                }) {
                    HStack {
                        Image(systemName: "terminal.fill")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show UWB Debug Window")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Text("Display real-time UWB tracking data")
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
                
                // Distance Calibration
                Button(action: { showingCalibration = true }) {
                    HStack {
                        Image(systemName: "ruler.fill")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Distance Calibration")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Text("Adjust distance readings by fixed amount")
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
                
                // Device Switcher Control
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("QorvoView Device Switcher")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text("Enable device switching tabs in QorvoView for multi-device connections")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    HStack {
                        Image(systemName: "switch.2")
                            .foregroundColor(.blue)
                        
                        Text("Show Device Switcher in QorvoView")
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Toggle("", isOn: .constant(true))
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .disabled(true)
                    }
                }
                .padding()
                .background(Color(hex: "232229"))
                .cornerRadius(12)
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

