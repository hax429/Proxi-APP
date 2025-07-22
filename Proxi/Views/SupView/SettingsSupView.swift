//
//  SettingsSupView.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/20/25.
//

import SwiftUI
import PhotosUI
import MessageUI

// MARK: - Placeholder Views for Sheets
struct ProfileView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Text("Profile Settings")
                    .font(.title)
                    .foregroundColor(.white)
                Text("Profile management coming soon...")
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

struct NotificationsView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Text("Notifications")
                    .font(.title)
                    .foregroundColor(.white)
                Text("Notification settings coming soon...")
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

struct PrivacyView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Text("Privacy & Security")
                    .font(.title)
                    .foregroundColor(.white)
                Text("Privacy settings coming soon...")
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("About Proxi")
                    .font(.title)
                    .foregroundColor(.white)
                
                VStack(spacing: 8) {
                    Text("Version 1.0.0")
                        .foregroundColor(.white.opacity(0.7))
                    Text("© 2024 Proxi Team")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}

//MARK: Profile selection


struct ProfileSettingsView: View {
    @StateObject private var userManager = UserManager()
    @State private var editingName = false
    @State private var tempName = ""
    @State private var selectedImage: PhotosPickerItem?
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Image Section
            VStack {
                PhotosPicker(selection: $selectedImage,
                            matching: .images,
                            photoLibrary: .shared()) {
                    if let profileImage = userManager.getProfileImage() {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 3)
                            )
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 120, height: 120)
                            
                            VStack {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray)
                                Text("Add Photo")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .onChange(of: selectedImage) { newItem in
                    Task {
                        if let newItem = newItem {
                            if let data = try? await newItem.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                DispatchQueue.main.async {
                                    _ = userManager.setProfileImage(image)
                                }
                            }
                        }
                    }
                }
                
                Text("Tap to change photo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Name Section
            VStack(alignment: .leading) {
                Text("Name")
                    .font(.headline)
                
                if editingName {
                    HStack {
                        TextField("Enter your name", text: $tempName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Save") {
                            userManager.updateProfile(name: tempName)
                            editingName = false
                        }
                        .disabled(tempName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        Button("Cancel") {
                            tempName = userManager.userProfile?.name ?? ""
                            editingName = false
                        }
                    }
                } else {
                    HStack {
                        Text(userManager.userProfile?.name ?? "")
                            .font(.body)
                        
                        Spacer()
                        
                        Button("Edit") {
                            tempName = userManager.userProfile?.name ?? ""
                            editingName = true
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Profile Settings")
        .onAppear {
            tempName = userManager.userProfile?.name ?? ""
        }
    }
}


// MARK: - Mail Composer Views
struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setToRecipients(recipients)
        mailComposer.setSubject(subject)
        return mailComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct MailUnavailableView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.red)
                
                Text("Mail Not Available")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Please configure your Mail app or contact us directly at:")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Text("superkatiebros@gmail.com")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        UIPasteboard.general.string = "superkatiebros@gmail.com"
                    }
                
                Text("Tap email to copy")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}


//MARK: Setting Extensions

extension SettingsView {
    // MARK: - Profile Section
    var profileSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            HStack(spacing: 16) {
                
                VStack(alignment: .leading, spacing: 4) {
                    if editingDisplayName {
                        HStack(spacing: 8) {
                            TextField("Display Name", text: $tempDisplayName)
                                .font(.headline)
                                .foregroundColor(.white)
                                .disableAutocorrection(true)
                                .focused($isEditingName)
                                .padding(6)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                            Button("Save") {
                                let trimmed = tempDisplayName.trimmingCharacters(in: .whitespaces)
                                if !trimmed.isEmpty {
                                    displayName = trimmed
                                    saveDisplayName(trimmed)
                                }
                                editingDisplayName = false
                            }
                            .foregroundColor(.blue)
                            .disabled(tempDisplayName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text(displayName)
                                .font(.headline)
                                .foregroundColor(.white)
                                .onTapGesture {
                                    tempDisplayName = displayName
                                    editingDisplayName = true
                                    isEditingName = true
                                }
                            Button(action: {
                                tempDisplayName = displayName
                                editingDisplayName = true
                                isEditingName = true
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    Text("Click to edit display name")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            .padding()
            .background(Color(hex: "232229"))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Display Name Helpers
    static func loadDisplayName() -> String {
        if let saved = UserDefaults.standard.string(forKey: "displayName") {
            return saved
        } else {
            let randomId = Int.random(in: 1000...9999)
            let generated = "User\(randomId)"
            UserDefaults.standard.set(generated, forKey: "displayName")
            return generated
        }
    }
    func saveDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        UserDefaults.standard.set(trimmed, forKey: "displayName")
    }
    func initials(for name: String) -> String {
        let comps = name.split(separator: " ")
        if comps.count >= 2 {
            return String(comps[0].prefix(1)) + String(comps[1].prefix(1))
        } else if let first = comps.first {
            return String(first.prefix(2))
        } else {
            return "U"
        }
    }
    
    // MARK: - Device Management Section
    var deviceManagementSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Device Management")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Connection Status Card
                connectionStatusCard
                
                // Data Display Card
                //Todo: Only enable in dev setting
                if isDeveloperModeEnabled && qorvoConnectionStatus.isConnected {
                    dataDisplayCard
                }
                
                // Device List Card
                deviceListCard
                
                // Control Buttons
                controlButtonsCard
            }
        }
    }
    
    var connectionStatusCard: some View {
        HStack(spacing: 16) {
            // Status Indicator
            ZStack {
                Circle()
                    .fill(qorvoConnectionStatus.isConnected ? Color.green : Color.red)
                    .frame(width: 16, height: 16)
                
                if qorvoConnectionStatus.isConnected {
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .scaleEffect(1.2)
                        .opacity(0.8)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(qorvoConnectionStatus.statusText)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if qorvoConnectionStatus.isConnected {
                    Text("Connected to \(qorvoConnectionStatus.deviceName)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text("No active connection")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            if qorvoConnectionStatus.isConnected && qorvoConnectionStatus.deviceCount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Active Devices")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(qorvoConnectionStatus.deviceCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(hex: "232229"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var qorvoConnectionStatus: (isConnected: Bool, statusText: String, deviceName: String, deviceCount: Int) {
        let connectedDevices = qorvoDevices.compactMap { $0 }.filter { $0.blePeripheralStatus == statusRanging }
        let isConnected = !connectedDevices.isEmpty
        
        if isConnected {
            let deviceName = connectedDevices.first?.blePeripheralName ?? "Unknown"
            return (true, "Connected", deviceName, connectedDevices.count)
        } else {
            return (false, "Disconnected", "", 0)
        }
    }
    
    var signalStrengthColor: Color {
        if bleManager.rssi >= -50 { return .green }
        else if bleManager.rssi >= -70 { return .yellow }
        else { return .red }
    }
    
    var dataDisplayCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("UWB Data")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "wave.3.right")
                    .foregroundColor(.blue)
            }
            
            if let selectedDevice = qorvoDevices.compactMap({ $0 }).first(where: { $0.blePeripheralStatus == statusRanging }) {
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Distance")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            if let distance = selectedDevice.uwbLocation?.distance {
                                Text(String(format: "%.3f m", distance))
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundColor(.green)
                            } else {
                                Text("--")
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Status")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text(selectedDevice.blePeripheralStatus ?? "Unknown")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if let direction = selectedDevice.uwbLocation?.direction {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Direction (x,y,z)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text("(\(String(format: "%.3f", direction.x)), \(String(format: "%.3f", direction.y)), \(String(format: "%.3f", direction.z)))")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.blue)
                        }
                    }
                }
            } else {
                Text("No ranging data available")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(Color(hex: "232229"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    var deviceListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Devices")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(qorvoDevices.compactMap { $0 }.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if qorvoDevices.compactMap({ $0 }).isEmpty {
                emptyDeviceListView
            } else {
                deviceList
            }
        }
        .padding()
        .background(Color(hex: "232229"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    var emptyDeviceListView: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.4))
            
            Text("No devices found")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            
            Text("Tap 'Scan' to discover nearby devices")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    var deviceList: some View {
        VStack(spacing: 8) {
            ForEach(qorvoDevices.compactMap { $0 }, id: \.bleUniqueID) { qorvoDevice in
                QorvoDeviceRowView(
                    qorvoDevice: qorvoDevice,
                    onConnect: {
                        // Use QorvoDemoViewController connection logic via parent
                        connectToAccessory(qorvoDevice.bleUniqueID)
                    },
                    onDisconnect: {
                        disconnectFromAccessory(qorvoDevice.bleUniqueID)
                    },
                    isDeveloperMode: isDeveloperModeEnabled
                )
            }
        }
    }
    
    var controlButtonsCard: some View {
        VStack(spacing: 12) {
            // Scan Button
            Button(action: {
                startScanning()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isScanning ? "stop.circle.fill" : "magnifyingglass.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(isScanning ? "Stop Scanning" : "Start Scanning")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isScanning ? Color.orange : Color.blue)
                .cornerRadius(12)
            }
            
            // Connect to discovered devices
            if hasDiscoveredDevices && !isScanning {
                Button(action: {
                    connectToFirstDiscoveredDevice()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Connect to Device")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(12)
                }
            }
            
            // Disconnect button for connected devices
            if hasConnectedDevices {
                Button(action: {
                    disconnectAllDevices()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Disconnect All")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .cornerRadius(12)
                }
            }
            
            // Status text
            Text(scanningStatusText)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
    
    private var hasConnectedDevices: Bool {
        qorvoDevices.compactMap { $0 }.contains { device in
            device.blePeripheralStatus == statusRanging || device.blePeripheralStatus == statusConnected
        }
    }
    
    private func disconnectAllDevices() {
        qorvoDevices.compactMap { $0 }.forEach { device in
            if device.blePeripheralStatus == statusRanging || device.blePeripheralStatus == statusConnected {
                disconnectFromAccessory(device.bleUniqueID)
            }
        }
    }
    
    // MARK: - App Settings Section
    var appSettingsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("App Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 8) {
                settingsRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    subtitle: "Manage push notifications",
                    action: { showingNotifications = true }
                )
                
                settingsRow(
                    icon: "lock.fill",
                    title: "Privacy & Security",
                    subtitle: "Data protection settings",
                    action: { showingPrivacy = true }
                )
                
                settingsRow(
                    icon: "gear",
                    title: "General",
                    subtitle: "App preferences",
                    action: { }
                )
            }
        }
    }
    
    func settingsRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding()
            .background(Color(hex: "232229"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Support Section
    var supportSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Support")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 8) {
                settingsRow(
                    icon: "info.circle.fill",
                    title: "Contact Proxi",
                    subtitle: "Meet the Team",
                    action: { showingMailComposer = true }
                )
            }
        }
    }
        
        // MARK: - Debug Section
        var debugSection: some View {
            VStack(spacing: 16) {
                HStack {
                    Text("Developer")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    if isDeveloperModeEnabled {
                        Text("ENABLED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
                
                Button(action: { showingDebugLog = true }) {
                    HStack(spacing: 16) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Debug Log")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Text("View connection logs")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding()
                    .background(Color(hex: "232229"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Reset Developer Mode Button
                Button(action: {
                    isDeveloperModeEnabled = false
                    versionClickCount = 0
                    UserDefaults.standard.set(false, forKey: "isDeveloperModeEnabled")
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Disable Developer Mode")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Text("Hide developer options")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding()
                    .background(Color(hex: "232229"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        
        // MARK: - Version Section
        var versionSection: some View {
            VStack(spacing: 12) {
                Spacer(minLength: 20)
                
                Button(action: {
                    versionClickCount += 1
                    
                    if versionClickCount >= 5 && !isDeveloperModeEnabled {
                        isDeveloperModeEnabled = true
                        UserDefaults.standard.set(true, forKey: "isDeveloperModeEnabled")
                        
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        // Reset click count
                        versionClickCount = 0
                    }
                }) {
                    VStack(spacing: 4) {
                        Text("Proxi")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("Version 0.8")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                        
                        //                    if versionClickCount > 0 && versionClickCount < 5 && !isDeveloperModeEnabled {
                        //                        Text("\(5 - versionClickCount) more taps to enable developer mode")
                        //                            .font(.caption2)
                        //                            .foregroundColor(.blue.opacity(0.7))
                        //                            .padding(.top, 4)
                        //                    }
                        
                        if isDeveloperModeEnabled {
                            Text("Developer Mode Enabled")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .padding(.top, 4)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer(minLength: 20)
            }
        }
    }
    
