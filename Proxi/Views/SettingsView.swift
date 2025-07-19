import SwiftUI
import CoreBluetooth

struct SettingsView: View {
    @StateObject private var bleManager = BLEManager()
    @State private var showingDebugLog = false
    @State private var selectedTab = 0
    @State private var showingProfile = false
    @State private var showingNotifications = false
    @State private var showingPrivacy = false
    @State private var showingAbout = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBarView()
                
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
                        
                        // Debug Section
                        debugSection
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
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
    
    // MARK: - Profile Section
    private var profileSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            Button(action: { showingProfile = true }) {
                HStack(spacing: 16) {
                    // Profile Avatar
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        Text("JD")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("John Doe")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("john.doe@email.com")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding()
                .background(Color(hex: "232229"))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Device Management Section
    private var deviceManagementSection: some View {
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
                if bleManager.isConnected {
                    dataDisplayCard
                }
                
                // Device List Card
                deviceListCard
                
                // Control Buttons
                controlButtonsCard
            }
        }
    }
    
    private var connectionStatusCard: some View {
        HStack(spacing: 16) {
            // Status Indicator
            ZStack {
                Circle()
                    .fill(bleManager.isConnected ? Color.green : Color.red)
                    .frame(width: 16, height: 16)
                
                if bleManager.isConnected {
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .scaleEffect(1.2)
                        .opacity(0.8)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(bleManager.connectionStatus)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if bleManager.isConnected {
                    Text("Connected to Arduino")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text("No active connection")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            if bleManager.isConnected && bleManager.rssi != 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Signal Strength")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(bleManager.rssi) dBm")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(signalStrengthColor)
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
    
    private var signalStrengthColor: Color {
        if bleManager.rssi >= -50 { return .green }
        else if bleManager.rssi >= -70 { return .yellow }
        else { return .red }
    }
    
    private var dataDisplayCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Live Data")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.blue)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Received Value")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(bleManager.receivedNumber)")
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Last Updated")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(Date().formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
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
    
    private var deviceListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Devices")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(bleManager.discoveredPeripherals.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if bleManager.discoveredPeripherals.isEmpty {
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
    
    private var emptyDeviceListView: some View {
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
    
    private var deviceList: some View {
        VStack(spacing: 8) {
            ForEach(bleManager.discoveredPeripherals, id: \.identifier) { peripheral in
                DeviceRowView(
                    peripheral: peripheral,
                    isConnected: bleManager.isConnected,
                    connectedPeripheralID: bleManager.connectedPeripheralID,
                    onConnect: {
                        bleManager.connect(to: peripheral)
                    }
                )
            }
        }
    }
    
    private var controlButtonsCard: some View {
        HStack(spacing: 12) {
            // Scan Button
            Button(action: {
                if bleManager.isScanning {
                    bleManager.stopScanning()
                } else {
                    bleManager.startScanning()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: bleManager.isScanning ? "stop.circle.fill" : "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                    Text(bleManager.isScanning ? "Stop" : "Scan")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if bleManager.isScanning {
                            Color.red
                        } else {
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .cornerRadius(12)
            }
            
            // Disconnect Button
            if bleManager.isConnected {
                Button(action: {
                    bleManager.disconnect()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Disconnect")
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
        }
    }
    
    // MARK: - App Settings Section
    private var appSettingsSection: some View {
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
    
    private func settingsRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
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
    private var supportSection: some View {
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
                    icon: "questionmark.circle.fill",
                    title: "Help & FAQ",
                    subtitle: "Get help with the app",
                    action: { }
                )
                
                settingsRow(
                    icon: "envelope.fill",
                    title: "Contact Support",
                    subtitle: "Send us a message",
                    action: { }
                )
                
                settingsRow(
                    icon: "info.circle.fill",
                    title: "About Proxi",
                    subtitle: "App version and info",
                    action: { showingAbout = true }
                )
            }
        }
    }
    
    // MARK: - Debug Section
    private var debugSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Developer")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
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
        }
    }
}

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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 
