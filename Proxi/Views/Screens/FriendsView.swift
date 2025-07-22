
import SwiftUI
import CoreBluetooth
import NearbyInteraction
import os.log

struct FriendsView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var friendsManager: FriendsManager
    @Binding var selectedTab: Int
    @State private var selectedFriendsTab: Int = 0
    @Binding var isSidebarOpen: Bool
    
    // Timer for checking device connection status
    @State private var timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State private var connectedDevicesCount = 0
    @State private var refreshTrigger = false // Force view refresh
    
    private let logger = os.Logger(subsystem: "com.qorvo.ni", category: "FriendsView")

    // Computed property that uses BLEManager connection status
    private var hasPairedProxi: Bool {
        bleManager.isConnected
    }
    
    // MARK: - Device Categorization (using BLEManager data)
    private var connectedDevices: [CBPeripheral] {
        return Array(bleManager.connectedPeripherals.values)
    }
    
    private var discoveredDevices: [CBPeripheral] {
        return bleManager.discoveredPeripherals.filter { peripheral in
            !bleManager.connectedPeripherals.keys.contains(peripheral.identifier)
        }
    }
    
    private var hostDevice: CBPeripheral? {
        // The host device is the first connected device
        return connectedDevices.first
    }
    
    private var otherConnectedDevices: [CBPeripheral] {
        // All connected devices except the host device
        if connectedDevices.count > 1 {
            return Array(connectedDevices.dropFirst())
        }
        return []
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBarView(selectedTab: $selectedTab, isSidebarOpen: $isSidebarOpen)
                if !hasPairedProxi {
                    unpairedStateView
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Combined host device section
                            hostDeviceSection
                            pairedFriendsSection
                            nearbyProxisSection
                            incomingRequestsSection
                        }
                        .padding()
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            updateDeviceCounts()
        }
        .onChange(of: connectedDevicesCount) { count in
            if count > 0 {
                // Device just connected - provide haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
        }
        .onChange(of: refreshTrigger) { _ in
            // Force view refresh when location data updates
        }
        .onAppear {
            startDeviceMonitoring()
        }
        .onDisappear {
            stopDeviceMonitoring()
        }
    }
    
    // MARK: - Device Monitoring
    private func startDeviceMonitoring() {
        // Update device counts every 2 seconds
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            updateDeviceCounts()
        }
        
        // Update UI more frequently for location data (every 500ms)
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            // Force UI refresh when location data changes
            DispatchQueue.main.async {
                self.refreshTrigger.toggle() // Toggle to force view refresh
            }
        }
    }
    
    private func stopDeviceMonitoring() {
        // Timer cleanup would go here if needed
    }
    
    // MARK: - Location Update Handler
    private func handleLocationUpdate() {
        // Force UI refresh when location data is updated
        DispatchQueue.main.async {
            self.refreshTrigger.toggle() // Toggle to force view refresh
        }
    }
    
    private func updateDeviceCounts() {
        connectedDevicesCount = connectedDevices.count
        
        // Debug: Print distance data for connected devices
        for (peripheralID, deviceData) in bleManager.connectedDevicesData {
            let deviceName = deviceData.deviceName
            let location = deviceData.uwbLocation
            let isRanging = deviceData.isRanging
            
            print("📏 FriendsView Debug - Device: \(deviceName), Distance: \(location.distance), Ranging: \(isRanging)")
            
            // Check if distance is 0 and provide more context
            if location.distance == 0 {
                print("⚠️ FriendsView Debug - Device \(deviceName) has 0 distance - this might indicate:")
                print("   - UWB ranging not started yet")
                print("   - Device too close for accurate measurement")
                print("   - NoUpdate flag: \(location.noUpdate)")
                print("   - Direction data: x=\(location.direction.x), y=\(location.direction.y), z=\(location.direction.z)")
                
                // Check if this device should be ranging but isn't
                if !isRanging {
                    print("🔍 FriendsView Debug - Device \(deviceName) is connected but not ranging - this might be a UWB session issue")
                }
            }
        }
        
        // Debug: Print all devices for comparison
        print("🔍 FriendsView Debug - Total connected devices: \(connectedDevices.count)")
        print("🔍 FriendsView Debug - Total discovered devices: \(discoveredDevices.count)")
        
        // Force refresh trigger to update UI
        DispatchQueue.main.async {
            self.refreshTrigger.toggle()
        }
    }

    // MARK: - Host Device Section
    private var hostDeviceSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Host Device")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Text("Connected")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
            }
            
            if let host = hostDevice {
                HostDeviceCard(peripheral: host, bleManager: bleManager)
            } else {
                emptyHostDeviceView
            }
        }
    }
    
    // MARK: - Paired Friends Section
    private var pairedFriendsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Connected Devices")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(otherConnectedDevices.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if otherConnectedDevices.isEmpty {
                emptyFriendsView(text: "No other devices connected.")
            } else {
                connectedDevicesList
            }
        }
    }
    
    private var connectedDevicesList: some View {
        VStack(spacing: 8) {
            ForEach(otherConnectedDevices, id: \.identifier) { peripheral in
                ConnectedDeviceCard(peripheral: peripheral, bleManager: bleManager, onDisconnect: { peripheralID in
                    bleManager.disconnect(peripheralID: peripheralID)
                })
            }
        }
    }
    
    // MARK: - Nearby Proxis Section
    private var nearbyProxisSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Nearby Devices")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(discoveredDevices.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if discoveredDevices.isEmpty {
                emptyFriendsView(text: "No nearby devices found.")
            } else {
                nearbyProxisList
            }
        }
    }
    
    private var nearbyProxisList: some View {
        VStack(spacing: 8) {
            ForEach(discoveredDevices, id: \.identifier) { peripheral in
                DiscoveredDeviceCard(peripheral: peripheral, onConnect: { peripheral in
                    bleManager.connect(to: peripheral)
                })
            }
        }
    }
    
    // MARK: - Incoming Requests
    private var incomingRequestsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Incoming Requests")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(friendsManager.incomingRequests.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            if friendsManager.incomingRequests.isEmpty {
                emptyFriendsView(text: "No incoming requests.")
            } else {
                // Incoming requests list would go here
                Text("Incoming requests feature coming soon...")
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
            }
        }
    }
    
    // MARK: - Empty State Views
    private var emptyHostDeviceView: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Host Device")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Connect an Arduino device in Settings to get started.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color("232229"))
        .cornerRadius(12)
    }
    
    private func emptyFriendsView(text: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text(text)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color("232229"))
        .cornerRadius(12)
    }
    
    // MARK: - Unpaired State View
    private var unpairedStateView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("Connect Arduino Device First")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("To connect with friends, you need to connect your Arduino UWB device first. This enables you to discover and connect with other users nearby.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                if bleManager.isScanning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Scanning for devices...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 8)
                }
            }
            
            Button(action: { selectedTab = 4 }) {
                HStack(spacing: 12) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 20))
                    Text("Connect Arduino")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Device Card Views
struct HostDeviceCard: View {
    let peripheral: CBPeripheral
    let bleManager: BLEManager
    @State private var refreshTrigger: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Connection status header
            HStack(spacing: 16) {
                // Proxi status indicator
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 16, height: 16)
                    
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .scaleEffect(1.2)
                        .opacity(0.8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arduino Connected")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Ready to discover friends")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
            }
            
            // Device info
            HStack(spacing: 16) {
                // Device icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(peripheral.name ?? "Unknown Device")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    
                    Text("Connected")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    
                    // Distance display with refresh trigger
                    if let deviceData = bleManager.getDeviceData(for: peripheral.identifier) {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("\(String(format: "%.2f", deviceData.uwbLocation.distance))m")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        .id(refreshTrigger) // Force refresh when trigger changes
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "location.slash")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                            Text("Distance unavailable")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                
                Spacer()
                
                // Host indicator
                VStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("HOST")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding()
        .background(Color("232229"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ConnectedDeviceCard: View {
    let peripheral: CBPeripheral
    let bleManager: BLEManager
    let onDisconnect: (UUID) -> Void
    @State private var refreshTrigger: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Device icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(peripheral.name ?? "Unknown Device")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
                
                Text("Connected")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                // Distance display with refresh trigger
                if let deviceData = bleManager.getDeviceData(for: peripheral.identifier) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(String(format: "%.2f", deviceData.uwbLocation.distance))m")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    .id(refreshTrigger) // Force refresh when trigger changes
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "location.slash")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        Text("Distance unavailable")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            
            Spacer()
            
            // Disconnect button
            Button(action: {
                onDisconnect(peripheral.identifier)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color("232229"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct DiscoveredDeviceCard: View {
    let peripheral: CBPeripheral
    let onConnect: (CBPeripheral) -> Void
    @State private var isConnecting = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Device icon
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(peripheral.name ?? "Unknown Device")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Discovered")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Connect button
            Button(action: {
                print("Connect button tapped for device: \(peripheral.name ?? "Unknown") (ID: \(peripheral.identifier))")
                isConnecting = true
                onConnect(peripheral)
                
                // Reset connecting state after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isConnecting = false
                }
            }) {
                if isConnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .disabled(isConnecting)
        }
        .padding()
        .background(Color("232229"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// Keep all the supporting views the same (FriendsListRowView, NearbyProxiRowView, etc.)

struct FriendsView_Previews: PreviewProvider {
    static var previews: some View {
        FriendsView(selectedTab: Binding.constant(2), isSidebarOpen: Binding.constant(false))
            .environmentObject(BLEManager())
            .environmentObject(FriendsManager())
    }
}

// MARK: - Supporting Views
struct FriendsListRowView: View {
    let friend: Friend
    var showLastActive: Bool = true
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Text(String(friend.name.prefix(1)))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(friend.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    if friend.isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color("232229"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct NearbyProxiRowView: View {
    let proxi: ProxiDevice
    let onSendRequest: () -> Void
    @State private var isRequesting = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Proxi icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(proxi.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    if proxi.isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text("\(proxi.distance)m away")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Send request button
            Button(action: {
                isRequesting = true
                onSendRequest()
                // Simulate request sending
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isRequesting = false
                }
            }) {
                HStack(spacing: 4) {
                    if isRequesting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14))
                    }
                    Text(isRequesting ? "Sending..." : "Add")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(8)
            }
            .disabled(isRequesting)
        }
        .padding()
        .background(Color("232229"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Sheet Views

struct FriendRequestsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Text("Friend Requests")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    Button("Done") { dismiss() }
                        .foregroundColor(.blue)
                }
                
                Text("Friend requests functionality coming soon...")
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Data Models
struct FriendProfile: Identifiable {
    let id: String
    let name: String
    let status: String
    let lastActive: Date
    let isOnline: Bool
    let avatar: String
}

struct ProxiDevice: Identifiable {
    let id: String
    let name: String
    let distance: Int
    let isOnline: Bool
    let lastSeen: Date
}


