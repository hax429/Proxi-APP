

import SwiftUI
import CoreBluetooth
import NearbyInteraction
import os.log

struct FriendsView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var friendsManager: FriendsManager
    @StateObject var simulationManager = SimulationManager()
    @Binding var selectedTab: Int
    @State private var selectedFriendsTab: Int = 0
    @Binding var isSidebarOpen: Bool
    
    // Real-time updates for distance and status
    @State private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect() // Faster updates
    @State private var connectedDevicesCount = 0
    @State private var refreshTrigger = UUID() // Force view refresh with unique ID
    
    // Request simulation states
    @State private var pendingRequests: [PendingRequest] = []
    @State private var incomingRequests: [IncomingRequest] = [
        IncomingRequest(id: "katie_pilot", deviceName: "Katie's Pilot", senderName: "Katie", timestamp: Date())
    ]
    @State private var showApprovalPopup = false
    @State private var approvedRequestDeviceName = ""
    
    private let logger = os.Logger(subsystem: "com.qorvo.ni", category: "FriendsView")
    
    // Developer mode check
    private var isDeveloperModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: "isDeveloperModeEnabled")
    }

    // Computed property that uses BLEManager connection status or simulation
    private var hasPairedProxi: Bool {
        bleManager.isConnected || simulationManager.isSimulationEnabled
    }
    
    // MARK: - Device Categorization (using BLEManager data or simulation)
    private var connectedDevices: [CBPeripheral] {
        if simulationManager.isSimulationEnabled {
            // Return simulation devices as connected peripherals
            return simulationManager.getDeviceIds().compactMap { deviceId in
                if let fakeDevice = simulationManager.getDeviceData(for: deviceId) {
                    let mockPeripheral = simulationManager.createMockPeripheral(name: fakeDevice.name, id: deviceId)
                    // Convert MockPeripheral to CBPeripheral for compatibility
                    return nil
                }
                return nil
            }
        } else {
            return Array(bleManager.connectedPeripherals.values).filter { peripheral in
                peripheral.name != "Adafruit Bluefruit LE AA68"
            }
        }
    }
    
    private var discoveredDevices: [CBPeripheral] {
        if simulationManager.isSimulationEnabled {
            // In simulation mode, no discovered devices (all are connected)
            return []
        } else {
            return bleManager.discoveredPeripherals.filter { peripheral in
                !bleManager.connectedPeripherals.keys.contains(peripheral.identifier) &&
                peripheral.name != "Adafruit Bluefruit LE AA68"
            }
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
                            // Page title
                            HStack {
                                Text("Discover")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                            
                            // Simplified sections
                            connectedDevicesSection
                            incomingRequestsSection
                            availableDevicesSection
                        }
                        .padding()
                    }
                }
            }
        }
        .overlay(
            // Approval popup overlay
            approvalPopupOverlay
        )
        .onReceive(timer) { _ in
            updateDeviceCounts()
            // Force real-time UI updates for distance and status
            refreshTrigger = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UWBLocationUpdated"))) { _ in
            // Immediate refresh when location data changes
            refreshTrigger = UUID()
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
        
        // Update UI very frequently for real-time distance updates (every 100ms)
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // Force UI refresh when location data changes
            DispatchQueue.main.async {
                self.refreshTrigger = UUID() // New UUID to force view refresh
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
            self.refreshTrigger = UUID() // New UUID to force view refresh
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
        print("🔍 FriendsView Debug - Total discovered devices: \(discoveredDevices.count)")
        
        // Force refresh trigger to update UI
        DispatchQueue.main.async {
            self.refreshTrigger = UUID()
        }
    }

    // MARK: - Connected Devices Section
    private var connectedDevicesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("My Devices")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                // In developer mode, always show count; otherwise only when devices are connected
                if !connectedDevices.isEmpty || isDeveloperModeEnabled {
                    Text("\(connectedDevices.count) connected")
                        .font(.caption)
                        .foregroundColor(connectedDevices.count > 0 ? .green : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((connectedDevices.count > 0 ? Color.green : Color.orange).opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            // In developer mode, don't show empty state - always show device list
            if connectedDevices.isEmpty && !isDeveloperModeEnabled {
                emptyConnectedDevicesView
            } else {
                VStack(spacing: 8) {
                    ForEach(connectedDevices, id: \.identifier) { peripheral in
                        SimpleDeviceCard(
                            peripheral: peripheral,
                            bleManager: bleManager,
                            isConnected: true,
                            pendingRequests: pendingRequests,
                            onAction: { 
                                // Disconnect only this specific device
                                bleManager.disconnect(peripheralID: peripheral.identifier) 
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Incoming Requests Section
    private var incomingRequestsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Incoming Requests")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                if !incomingRequests.isEmpty {
                    Text("\(incomingRequests.count)")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            if incomingRequests.isEmpty {
                emptyIncomingRequestsView
            } else {
                VStack(spacing: 8) {
                    ForEach(incomingRequests, id: \.id) { request in
                        IncomingRequestCard(
                            request: request,
                            onAccept: { acceptRequest(request) },
                            onDecline: { declineRequest(request) }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Available Devices Section
    private var availableDevicesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Available Devices")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                if bleManager.isScanning {
                    HStack(spacing: 4) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.6)
                        Text("Scanning...")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                } else if !discoveredDevices.isEmpty {
                    Text("\(discoveredDevices.count) found")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            if discoveredDevices.isEmpty {
                emptyAvailableDevicesView
            } else {
                VStack(spacing: 8) {
                    ForEach(discoveredDevices, id: \.identifier) { peripheral in
                        SimpleDeviceCard(
                            peripheral: peripheral,
                            bleManager: bleManager,
                            isConnected: false,
                            pendingRequests: pendingRequests,
                            onAction: { sendConnectionRequest(to: peripheral) }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State Views
    private var emptyConnectedDevicesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 32))
                .foregroundColor(.gray)
            
            Text("No devices connected")
                .font(.subheadline)
                .foregroundColor(.white)
            
            Text("Connect a device to start sharing your location")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color("232229"))
        .cornerRadius(12)
    }
    
    private var emptyAvailableDevicesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.gray)
            
            Text("No devices found")
                .font(.subheadline)
                .foregroundColor(.white)
            
            Text("Make sure other devices are nearby and discoverable")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color("232229"))
        .cornerRadius(12)
    }
    
    private var emptyIncomingRequestsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.gray)
            
            Text("No incoming requests")
                .font(.subheadline)
                .foregroundColor(.white)
            
            Text("Connection requests from other users will appear here")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color("232229"))
        .cornerRadius(12)
    }
    
    // MARK: - Request Handling Methods
    private func acceptRequest(_ request: IncomingRequest) {
        // Remove from incoming requests
        incomingRequests.removeAll { $0.id == request.id }
        
        // Show approval popup
        approvedRequestDeviceName = request.deviceName
        showApprovalPopup = true
        
        // Hide popup after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showApprovalPopup = false
        }
        
        // Simulate connection (in real app, this would trigger actual BLE connection)
        print("Accepted connection request from \(request.senderName)")
    }
    
    private func declineRequest(_ request: IncomingRequest) {
        incomingRequests.removeAll { $0.id == request.id }
        print("Declined connection request from \(request.senderName)")
    }
    
    private func sendConnectionRequest(to peripheral: CBPeripheral) {
        // Add to pending requests
        let pendingRequest = PendingRequest(
            id: peripheral.identifier.uuidString,
            deviceName: peripheral.name ?? "Unknown Device",
            timestamp: Date()
        )
        pendingRequests.append(pendingRequest)
        
        // Connect immediately without disconnecting existing devices
        self.bleManager.connect(to: peripheral)
        
        // Simulate approval after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Remove from pending
            self.pendingRequests.removeAll { $0.id == pendingRequest.id }
            
            // Show approval popup
            self.approvedRequestDeviceName = pendingRequest.deviceName
            self.showApprovalPopup = true
            
            // Hide popup after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showApprovalPopup = false
            }
        }
    }
    
    // MARK: - Unpaired State View
    private var unpairedStateView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 64))
                    .foregroundColor(.blue.opacity(0.6))
                
                Text("Get Started")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Connect your device to start finding and connecting with friends nearby.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: { selectedTab = 4 }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Connect Device")
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
    
    // MARK: - Approval Popup Overlay
    private var approvalPopupOverlay: some View {
        Group {
            if showApprovalPopup {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        
                        Text("Request Approved!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Connection established with \(approvedRequestDeviceName)")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .background(Color("232229"))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 40)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: showApprovalPopup)
            }
        }
    }
}

// MARK: - Device Card Views
struct SimpleDeviceCard: View {
    let peripheral: CBPeripheral
    let bleManager: BLEManager
    let isConnected: Bool
    let onAction: () -> Void
    let pendingRequests: [PendingRequest]
    @State private var isProcessing = false
    
    init(peripheral: CBPeripheral, bleManager: BLEManager, isConnected: Bool, pendingRequests: [PendingRequest] = [], onAction: @escaping () -> Void) {
        self.peripheral = peripheral
        self.bleManager = bleManager
        self.isConnected = isConnected
        self.pendingRequests = pendingRequests
        self.onAction = onAction
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Device icon with status
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 20))
                    .foregroundColor(statusColor)
                
                // Connection indicator
                if isConnected {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .offset(x: 18, y: -18)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(peripheral.name ?? "Unknown Device")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(statusColor)
                }
                
                // Distance for connected devices
                if isConnected, let deviceData = bleManager.getDeviceData(for: peripheral.identifier) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Text("\(String(format: "%.1f", deviceData.uwbLocation.distance))m")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            
            Spacer()
            
            // Action button
            Button(action: {
                if !hasPendingRequest {
                    isProcessing = true
                    onAction()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        isProcessing = false
                    }
                }
            }) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: statusColor))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: actionIcon)
                        .font(.title3)
                        .foregroundColor(actionColor)
                }
            }
            .disabled(isProcessing || hasPendingRequest)
        }
        .padding()
        .background(Color("232229"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var hasPendingRequest: Bool {
        pendingRequests.contains { $0.id == peripheral.identifier.uuidString }
    }
    
    private var statusColor: Color {
        if hasPendingRequest {
            return .orange
        }
        return isConnected ? .green : .blue
    }
    
    private var statusText: String {
        if hasPendingRequest {
            return "Request Sent"
        }
        return isConnected ? "Connected" : "Available"
    }
    
    private var actionIcon: String {
        if hasPendingRequest {
            return "clock"
        }
        return isConnected ? "xmark.circle" : "plus.circle"
    }
    
    private var actionColor: Color {
        if hasPendingRequest {
            return .orange
        }
        return isConnected ? .red : .blue
    }
}

// MARK: - Incoming Request Card
struct IncomingRequestCard: View {
    let request: IncomingRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    @State private var isProcessing = false
    
    var body: some View {
        HStack(spacing: 16) {
            // User avatar
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(String(request.senderName.prefix(1)))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(request.senderName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("wants to connect")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(request.deviceName)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: {
                    isProcessing = true
                    onDecline()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isProcessing = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.red)
                }
                .disabled(isProcessing)
                
                Button(action: {
                    isProcessing = true
                    onAccept()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isProcessing = false
                    }
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                .disabled(isProcessing)
            }
        }
        .padding()
        .background(Color("232229"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
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

// MARK: - Request Data Models
struct IncomingRequest: Identifiable {
    let id: String
    let deviceName: String
    let senderName: String
    let timestamp: Date
}

struct PendingRequest: Identifiable {
    let id: String
    let deviceName: String
    let timestamp: Date
}


