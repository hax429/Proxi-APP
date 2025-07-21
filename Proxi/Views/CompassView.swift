import SwiftUI
import CoreLocation

// MARK: - Location Manager for Real Device Heading
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var deviceHeading: Double = 0
    @Published var headingAccuracy: Double = 0
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Use magnetic heading, adjust for true heading if needed
        let heading = newHeading.magneticHeading
        if heading >= 0 {
            DispatchQueue.main.async {
                self.deviceHeading = heading
                self.headingAccuracy = newHeading.headingAccuracy
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
}

struct CompassView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var friendsManager: FriendsManager
    @StateObject private var locationManager = LocationManager()
    @State var selectedFriend: Friend? = nil
    @Binding var isSidebarOpen: Bool
    @State private var showDebugInfo = false
    
    // Use real device heading or simulated for testing
    private var deviceHeading: Double {
        locationManager.deviceHeading
    }
    
    // Computed property that uses BLE connection status
    var hasPairedProxi: Bool {
        bleManager.isConnected
    }
    
    // Computed property to check if UWB is ranging
    var isUWBRanging: Bool {
        bleManager.isRanging && bleManager.uwbLocation.isValid
    }
    
    // Computed property to check if user has friends
    var hasFriends: Bool {
        !friendsManager.friends.isEmpty
    }
    
    // Get friends for compass display
    var compassFriends: [Friend] {
        friendsManager.getCompassFriends()
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBarView(selectedTab: $selectedTab, isSidebarOpen: $isSidebarOpen)
                
                if !hasPairedProxi {
                    connectFirstCard
                } else if isUWBRanging {
                    // Priority: Show UWB if active
                    uwbCompassCard
                } else if hasFriends {
                    // Fallback: Show friends if UWB not active but friends exist
                    connectedProxiCard
                } else {
                    // Show waiting state
                    waitingForUWBCard
                }
                Spacer()
            }
        }
        .onTapGesture(count: 5) {
            // Double tap to toggle debug info
            showDebugInfo.toggle()
        }
        .onChange(of: bleManager.isConnected) { isConnected in
            if isConnected {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                if bleManager.isScanning {
                    bleManager.stopScanning()
                }
            }
        }
    }
}

// MARK: - Accurate UWB Arrow with Clear Direction
struct AccurateUWBArrow: View {
    let uwbLocation: UWBLocation
    let deviceHeading: Double
    let showDebug: Bool
    
    // Calculate the relative bearing from device heading to target
    private var relativeBearing: Double {
        let targetAzimuth = Double(uwbLocation.azimuth)
        let relative = (targetAzimuth - deviceHeading + 360).truncatingRemainder(dividingBy: 360)
        return relative
    }
    
    // Distance-based scaling for the arrow
    private var arrowDistance: Double {
        let distance = Double(uwbLocation.distance)
        let maxRadius: Double = 120 // Maximum radius for arrow placement
        let scaledDistance = min(distance * 15, maxRadius) // Scale factor: 15 pixels per meter
        return max(scaledDistance, 40) // Minimum distance of 40 pixels from center
    }
    
    var body: some View {
        ZStack {
            // Static compass background (never rotates)
            Image("compass")
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)
                .opacity(0.3)
            
            // Distance rings for reference
            ForEach([1, 2, 5, 10], id: \.self) { distance in
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    .frame(width: CGFloat(distance * 24), height: CGFloat(distance * 24))
            }
            
            // Main direction arrow - this rotates to point to target
            VStack {
                // Arrow pointing up (North when rotation = 0)
                ZStack {
                    // Arrow shadow/glow
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue.opacity(0.3))
                        .offset(x: 2, y: 2)
                    
                    // Main arrow
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                }
                
                // Distance indicator below arrow
                Text(String(format: "%.1fm", uwbLocation.distance))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    .offset(y: 10)
            }
            .offset(y: -arrowDistance) // Move arrow away from center based on distance
            .rotationEffect(.degrees(relativeBearing)) // Rotate to point toward target
            .animation(.easeInOut(duration: 0.3), value: relativeBearing)
            .animation(.easeInOut(duration: 0.3), value: arrowDistance)
            
            // Elevation indicator
            if abs(uwbLocation.elevation) > 5 {
                VStack {
                    if uwbLocation.elevation > 0 {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 28))
                        Text("↑ \(String(format: "%.0f°", uwbLocation.elevation))")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    } else {
                        Text("↓ \(String(format: "%.0f°", abs(uwbLocation.elevation)))")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 28))
                    }
                }
                .offset(x: 100, y: 0) // Place elevation indicator to the side
            }
            
            // Debug information overlay
            if showDebug {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debug Info:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                    Text("Device Heading: \(String(format: "%.1f°", deviceHeading))")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("Target Azimuth: \(String(format: "%.1f°", uwbLocation.azimuth))")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("Relative Bearing: \(String(format: "%.1f°", relativeBearing))")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("Arrow Distance: \(String(format: "%.0f px", arrowDistance))")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("UWB Direction: x=\(String(format: "%.2f", uwbLocation.direction.x)), z=\(String(format: "%.2f", uwbLocation.direction.z))")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                .padding(30)
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
                .offset(x: -120, y: -120)
            }
        }
    }
}

// MARK: - Cardinal Directions (Static)
struct CompassDirections: View {
    var body: some View {
        ZStack {
            ForEach(["N", "E", "S", "W"], id: \.self) { direction in
                Text(direction)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.9))
                    .offset(y: -160)
                    .rotationEffect(.degrees(Double(["N": 0, "E": 90, "S": 180, "W": 270][direction] ?? 0)))
            }
            
            // Add degree markings
            ForEach(0..<36, id: \.self) { index in
                let angle = Double(index * 10)
                Rectangle()
                    .fill(Color.white.opacity(index % 3 == 0 ? 0.6 : 0.3))
                    .frame(width: 2, height: index % 3 == 0 ? 20 : 10)
                    .offset(y: -140)
                    .rotationEffect(.degrees(angle))
            }
        }
    }
}

// MARK: - Enhanced UWB Status Card
struct EnhancedUWBStatusCard: View {
    let uwbLocation: UWBLocation
    let protocolState: String
    let rssi: Int
    let deviceHeading: Double
    let showDebug: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Arduino Stella Board")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(uwbLocation.isValid ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(protocolState)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            if uwbLocation.isValid {
                HStack(spacing: 16) {
                    VStack {
                        Text("Distance")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(String(format: "%.2fm", uwbLocation.distance))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    VStack {
                        Text("Bearing")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(String(format: "%.0f°", uwbLocation.azimuth))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    
                    if abs(uwbLocation.elevation) > 1 {
                        VStack {
                            Text("Elevation")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text(String(format: "%.0f°", uwbLocation.elevation))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if showDebug {
                        VStack {
                            Text("Device °")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text(String(format: "%.0f°", deviceHeading))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }
                    }
                }
            } else {
                Text("Waiting for UWB data...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text("Updated: \(uwbLocation.timestamp, formatter: timeFormatter)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                
            if showDebug {
                Text("Double-tap to hide debug • Heading accuracy: ±\(String(format: "%.0f°", LocationManager().headingAccuracy))")
                    .font(.caption)
                    .foregroundColor(.yellow.opacity(0.7))
            } else {
                Text("Double-tap anywhere to show debug info")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding()
        .background(Color(hex: "232229"))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }
}

// MARK: - Friend Arrow (for fallback friend mode)
struct FriendArrow: View {
    let friend: Friend
    let deviceHeading: Double
    let isSelected: Bool
    
    private var arrowRotation: Double {
        (friend.bearing - deviceHeading).truncatingRemainder(dividingBy: 360)
    }
    
    var body: some View {
        ZStack {
            Image("compass")
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)
                .rotationEffect(.degrees(arrowRotation))
                .opacity(isSelected ? 1.0 : 0.7)
        }
    }
}

// MARK: - Empty Compass View
struct EmptyCompassView: View {
    var body: some View {
        VStack(spacing: 32) {
            // Large compass icon
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 200, height: 200)
                
                // Center icon
                Image(systemName: "location.north.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(spacing: 16) {
                Text("No Friends Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Add friends on the Friends tab to start navigating and see their locations in real-time.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - CompassView Extensions
extension CompassView {
    var connectFirstCard: some View {
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
                Text("Connect to Arduino Stella")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Connect to your Arduino Stella board to start precise UWB positioning. The device will show up as 'TS_DCU040' when scanning.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                // Show connection status if scanning or attempting to connect
                if bleManager.isScanning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Scanning for Arduino...")
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
    
    var waitingForUWBCard: some View {
        VStack(spacing: 32) {
            // Show successful connection message
            VStack(spacing: 16) {
                Spacer()
                    .frame(height: 30)
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 80, height: 80)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                }
                Text("Arduino Connected!")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Initializing UWB positioning system...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                // Show protocol state
                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(1.2)
                    
                    Text(bleManager.protocolState)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.top, 16)
            }
            .padding(.top, 60)
            
            // Empty compass placeholder
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                    .frame(width: 300, height: 300)
                
                CompassDirections()
                
                VStack(spacing: 8) {
                    Image(systemName: "location.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("Waiting for UWB")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.bottom, 100)
        }
    }
    
    var uwbCompassCard: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            
            // Main compass display
            ZStack {
                // Static cardinal directions
                CompassDirections()
                
                // Accurate UWB arrow pointing to device
                AccurateUWBArrow(
                    uwbLocation: bleManager.uwbLocation,
                    deviceHeading: deviceHeading,
                    showDebug: showDebugInfo
                )
                
                // Center indicator (your position)
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 20, height: 20)
                    )
                    .overlay(
                        // User direction indicator
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 3, height: 15)
                            .offset(y: -10)
                            .rotationEffect(.degrees(-deviceHeading))
                    )
            }
            .frame(height: 380)
            .padding(.top, 24)
            
            Spacer(minLength: 0)
            
            // Enhanced UWB status information
            EnhancedUWBStatusCard(
                uwbLocation: bleManager.uwbLocation,
                protocolState: bleManager.protocolState,
                rssi: bleManager.rssi,
                deviceHeading: deviceHeading,
                showDebug: showDebugInfo
            )
            
            Spacer(minLength: 0)
        }
    }
    
    var connectedProxiCard: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            // Compass takes up most of the space
            ZStack {
                // Cardinal directions
                CompassDirections()
                
                // Only show selected friend's arrow
                if let friend = selectedFriend ?? compassFriends.first {
                    FriendArrow(
                        friend: friend,
                        deviceHeading: deviceHeading,
                        isSelected: true
                    )
                }
                // Center indicator
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 24, height: 24)
            }
            .frame(height: 380)
            .padding(.top, 24)
            Spacer(minLength: 0)
            // Friend selector chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(compassFriends) { friend in
                        Button(action: {
                            selectedFriend = friend
                        }) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(friend.color)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Text(String(friend.name.prefix(1)))
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                                Text(friend.name)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedFriend?.id == friend.id ? friend.color.opacity(0.3) : Color.white.opacity(0.08))
                            .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            // Selected friend info
            if let friend = selectedFriend ?? compassFriends.first {
                VStack(spacing: 6) {
                    Text(friend.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    HStack(spacing: 16) {
                        Label("\(friend.distance)m", systemImage: "location.north.fill")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.subheadline)
                        if friend.elevation != 0 {
                            Label("\(friend.elevation > 0 ? "+" : "")\(friend.elevation)m", systemImage: friend.elevation > 0 ? "arrow.up" : "arrow.down")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
    }
}


struct CompassView_Previews: PreviewProvider {
    static var previews: some View {
        CompassView(selectedTab: Binding.constant(1), isSidebarOpen: Binding.constant(false))
            .environmentObject(BLEManager())
            .environmentObject(FriendsManager())
    }
}
