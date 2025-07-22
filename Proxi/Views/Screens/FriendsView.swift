
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
    
    // QorvoDemoViewController connection logic (similar to SettingsView)
    @StateObject private var dataChannel = DataCommunicationChannel()
    @StateObject private var sessionManager = NISessionManager()
    @State private var selectedAccessory = -1
    
    private let logger = os.Logger(subsystem: "com.qorvo.ni", category: "FriendsView")

    // Computed property that uses Arduino connection status
    private var hasPairedProxi: Bool {
        connectedDevicesCount > 0
    }
    
    // MARK: - Device Categorization
    private var hostDevice: qorvoDevice? {
        // The host device is the one connected in SettingsView (first connected device)
        qorvoDevices.compactMap { $0 }.first { device in
            device.blePeripheralStatus == statusConnected || device.blePeripheralStatus == statusRanging
        }
    }
    
    private var otherConnectedDevices: [qorvoDevice] {
        // All connected devices except the host device
        let connectedDevices = qorvoDevices.compactMap { $0 }.filter { device in
            device.blePeripheralStatus == statusConnected || device.blePeripheralStatus == statusRanging
        }
        
        // If we have a host device, exclude it from the list
        if let host = hostDevice {
            return connectedDevices.filter { $0.bleUniqueID != host.bleUniqueID }
        }
        
        return connectedDevices
    }
    
    private var discoveredNotConnectedDevices: [qorvoDevice] {
        // All discovered devices that are not connected
        qorvoDevices.compactMap { $0 }.filter { device in
            device.blePeripheralStatus == statusDiscovered
        }
    }
    
    // MARK: - Device Count Updates
    private func updateDeviceCounts() {
        let connected = qorvoDevices.compactMap { $0 }.filter { $0.blePeripheralStatus == statusConnected || $0.blePeripheralStatus == statusRanging }.count
        connectedDevicesCount = connected
        
        // Debug: Print distance data for connected devices
        for device in qorvoDevices.compactMap({ $0 }) {
            if device.blePeripheralStatus == statusConnected || device.blePeripheralStatus == statusRanging {
                if let location = device.uwbLocation {
                    print("📏 FriendsView Debug - Device: \(device.blePeripheralName), Distance: \(location.distance), Status: \(device.blePeripheralStatus ?? "Unknown"), NoUpdate: \(location.noUpdate)")
                    
                    // Check if distance is 0 and provide more context
                    if location.distance == 0 {
                        print("⚠️ FriendsView Debug - Device \(device.blePeripheralName) has 0 distance - this might indicate:")
                        print("   - UWB ranging not started yet")
                        print("   - Device too close for accurate measurement")
                        print("   - NoUpdate flag: \(location.noUpdate)")
                        print("   - Direction data: x=\(location.direction.x), y=\(location.direction.y), z=\(location.direction.z)")
                    }
                } else {
                    print("❌ FriendsView Debug - Device: \(device.blePeripheralName), No UWB location data")
                }
            }
        }
        
        // Debug: Print all devices for comparison
        print("🔍 FriendsView Debug - Total devices: \(qorvoDevices.compactMap({ $0 }).count)")
        for (index, device) in qorvoDevices.compactMap({ $0 }).enumerated() {
            print("   Device \(index): \(device.blePeripheralName) - Status: \(device.blePeripheralStatus ?? "Unknown") - Has UWB: \(device.uwbLocation != nil)")
        }
        
        // Force refresh trigger to update UI
        DispatchQueue.main.async {
            self.refreshTrigger.toggle()
        }
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
            setupDataChannel()
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
    private func handleLocationUpdate(_ deviceID: Int) {
        print("📍 FriendsView: Location update received for device ID: \(deviceID)")
        
        // Find the device and log its current state
        if let device = qorvoDevices.compactMap({ $0 }).first(where: { $0.bleUniqueID == deviceID }) {
            if let location = device.uwbLocation {
                print("📍 FriendsView: Device \(device.blePeripheralName) - Distance: \(location.distance), Status: \(device.blePeripheralStatus ?? "Unknown")")
            } else {
                print("📍 FriendsView: Device \(device.blePeripheralName) - No location data available")
            }
        } else {
            print("📍 FriendsView: Device with ID \(deviceID) not found")
        }
        
        // Force UI refresh when location data is updated
        DispatchQueue.main.async {
            self.refreshTrigger.toggle() // Toggle to force view refresh
            print("🔄 FriendsView: Refresh trigger toggled for device \(deviceID)")
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
        
        logger.info("DataCommunicationChannel initialized in FriendsView")
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
            // Location data has been updated - trigger UI refresh
            self.handleLocationUpdate(deviceID)
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
                HostDeviceCard(device: host)
            } else {
                emptyHostDeviceView
            }
        }
    }
    
    private var emptyHostDeviceView: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.4))
            
            Text("No Host Device")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Connect a device in Settings to start")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color("232229"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Paired Friends (Other Connected Devices)
    private var pairedFriendsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Currently Paired")
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
                VStack(spacing: 8) {
                    ForEach(otherConnectedDevices, id: \.bleUniqueID) { device in
                        ConnectedDeviceCard(device: device, onDisconnect: { deviceID in
                            self.disconnectFromAccessory(deviceID)
                        })
                    }
                }
            }
        }
    }
    
    // MARK: - Nearby Proxis (Discovered but not connected)
    private var nearbyProxisSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Nearby Proxis")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(discoveredNotConnectedDevices.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if discoveredNotConnectedDevices.isEmpty {
                emptyNearbyView
            } else {
                nearbyProxisList
            }
        }
    }
    
    private var emptyNearbyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.4))
            
            Text("No Proxis Nearby")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Move around to discover other Proxi users")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color("232229"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var nearbyProxisList: some View {
        VStack(spacing: 8) {
            ForEach(discoveredNotConnectedDevices, id: \.bleUniqueID) { device in
                DiscoveredDeviceCard(device: device, onConnect: { deviceID in
                    self.connectToAccessory(deviceID)
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
                VStack(spacing: 8) {
                    ForEach(friendsManager.incomingRequests) { friend in
                        HStack(alignment: .center) {
                            FriendsListRowView(friend: friend)
                            VStack(spacing: 8) {
                                Button(action: {
                                    friendsManager.acceptFriendRequest(friend)
                                }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                        .padding(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                Button(action: {
                                    friendsManager.declineFriendRequest(friend)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                        .padding(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    private func emptyFriendsView(text: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.4))
            Text(text)
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color("232229"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Unpaired State
    private var unpairedStateView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)
                
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
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
    
    // MARK: - Connection Management
    func connectToAccessory(_ deviceID: Int) {
        print("🔗 FriendsView: connectToAccessory called with deviceID: \(deviceID)")
        logger.info("Attempting to connect to device ID: \(deviceID)")
        
        // Check if device exists
        guard let device = qorvoDevices.compactMap({ $0 }).first(where: { $0.bleUniqueID == deviceID }) else {
            print("❌ FriendsView: Device with ID \(deviceID) not found in qorvoDevices array")
            logger.error("Device with ID \(deviceID) not found in qorvoDevices array")
            return
        }
        
        print("✅ FriendsView: Found device: \(device.blePeripheralName) with status: \(device.blePeripheralStatus ?? "nil")")
        logger.info("Found device: \(device.blePeripheralName) with status: \(device.blePeripheralStatus ?? "nil")")
        
        do {
            try dataChannel.connectPeripheral(deviceID)
            print("✅ FriendsView: Connection attempt initiated for device \(deviceID)")
            logger.info("Connection attempt initiated for device \(deviceID)")
        } catch {
            print("❌ FriendsView: Failed to connect to accessory: \(error)")
            logger.error("Failed to connect to accessory: \(error)")
        }
    }
    
    func disconnectFromAccessory(_ deviceID: Int) {
        print("🔌 FriendsView: disconnectFromAccessory called with deviceID: \(deviceID)")
        logger.info("Attempting to disconnect from device ID: \(deviceID)")
        
        // Check if device exists
        guard let device = qorvoDevices.compactMap({ $0 }).first(where: { $0.bleUniqueID == deviceID }) else {
            print("❌ FriendsView: Device with ID \(deviceID) not found in qorvoDevices array")
            logger.error("Device with ID \(deviceID) not found in qorvoDevices array")
            return
        }
        
        print("✅ FriendsView: Found device to disconnect: \(device.blePeripheralName)")
        logger.info("Found device to disconnect: \(device.blePeripheralName)")
        
        // Disconnect the BLE peripheral
        do {
            try dataChannel.disconnectPeripheral(deviceID)
            print("✅ FriendsView: BLE disconnection successful for device \(deviceID)")
            logger.info("BLE disconnection successful for device \(deviceID)")
        } catch {
            print("❌ FriendsView: Failed to disconnect BLE peripheral: \(error)")
            logger.error("Failed to disconnect BLE peripheral: \(error)")
        }
        
        // Invalidate the NI session for this device
        sessionManager.invalidateSession(for: deviceID)
        
        print("✅ FriendsView: Disconnection initiated for device \(deviceID)")
        logger.info("Disconnection initiated for device \(deviceID)")
    }
    
    func sendDataToAccessory(_ data: Data, _ deviceID: Int) {
        do {
            try dataChannel.sendData(data, deviceID)
        } catch {
            logger.error("Failed to send data to accessory: \(error)")
        }
    }
    
    // MARK: - DataChannel Handler Methods
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
    
    func accessorySynch(_ index: Int, _ insert: Bool) {
        // Update device list in friends view
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
}

// MARK: - Device Card Views
struct HostDeviceCard: View {
    let device: qorvoDevice
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
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text("Active")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            
            // Device details
            HStack(spacing: 16) {
                // Host device icon
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
                        Text(device.blePeripheralName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    
                    Text(device.blePeripheralStatus ?? "Connected")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    
                    // Distance display with refresh trigger
                    if let location = device.uwbLocation {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("\(String(format: "%.2f", location.distance))m")
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
                        .font(.title2)
                        .foregroundColor(.yellow)
                    Text("Host")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding()
        .background(Color("232229"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ConnectedDeviceCard: View {
    let device: qorvoDevice
    let onDisconnect: (Int) -> Void
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
                    Text(device.blePeripheralName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
                
                Text(device.blePeripheralStatus ?? "Connected")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                // Distance display with refresh trigger and debugging
                if let location = device.uwbLocation {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(String(format: "%.2f", location.distance))m")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    .id(refreshTrigger) // Force refresh when trigger changes
                    .onAppear {
                        print("🔍 ConnectedDeviceCard Debug - Device: \(device.blePeripheralName), Distance: \(location.distance), Status: \(device.blePeripheralStatus ?? "Unknown")")
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "location.slash")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        Text("Distance unavailable")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .onAppear {
                        print("❌ ConnectedDeviceCard Debug - Device: \(device.blePeripheralName), No UWB location data")
                    }
                }
            }
            
            Spacer()
            
            // Disconnect button
            Button(action: {
                print("🔌 Disconnect button tapped for device: \(device.blePeripheralName) (ID: \(device.bleUniqueID))")
                onDisconnect(device.bleUniqueID)
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
    let device: qorvoDevice
    let onConnect: (Int) -> Void
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
                Text(device.blePeripheralName)
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
                print("Connect button tapped for device: \(device.blePeripheralName) (ID: \(device.bleUniqueID))")
                isConnecting = true
                onConnect(device.bleUniqueID)
                
                // Reset connecting state after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isConnecting = false
                }
            }) {
                HStack(spacing: 4) {
                    if isConnecting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "link")
                            .font(.system(size: 14))
                    }
                    Text(isConnecting ? "Connecting..." : "Connect")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isConnecting ? Color.gray : Color.blue)
                .cornerRadius(8)
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


