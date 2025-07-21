import SwiftUI
import CoreLocation

struct CompassView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var friendsManager: FriendsManager
    @StateObject private var locationManager = LocationManager()
    @State var selectedFriend: Friend? = nil
    @Binding var isSidebarOpen: Bool
    @State private var showDebugInfo = false
    
    // Onboarding states
    @State private var onboarding = false
    @State private var tapCount = 0
    
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
    
    // Check if user is close to device
    var isCloseToDevice: Bool {
        bleManager.uwbLocation.distance < 5.0
    }
    
    var body: some View {
        ZStack {
            // Dynamic background color
            (isUWBRanging && isCloseToDevice ? Color.green.opacity(0.2) : Color.black)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: isCloseToDevice)
            
            VStack(spacing: 0) {
                TopBarView(selectedTab: $selectedTab, isSidebarOpen: $isSidebarOpen)
                
                if !hasPairedProxi {
                    connectFirstCard
                } else if isUWBRanging {
                    // Priority: Show UWB if active
                    simpleUWBCompassCard
                } else if hasFriends {
                    // Fallback: Show friends if UWB not active but friends exist
                    connectedProxiCard
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                tapCount += 1
                                if tapCount >= 3 {
                                    onboarding = true
                                    tapCount = 0
                                }
                            }
                        }
                } else {
                    // Show waiting state
                    waitingForUWBCard
                }
                Spacer()
            }
            
            // Onboarding overlay
            if onboarding {
                OnboardingOverlay(isPresented: $onboarding)
            }
        }
        .onTapGesture(count: 3) {
            // Three taps to toggle debug info
            showDebugInfo.toggle()
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
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

// MARK: - Updated Onboarding Overlay
struct OnboardingOverlay: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    
    let steps = [
        OnboardingStep(
            title: "Distance Display",
            description: "The large number at the top shows how far away your Arduino device is in meters. This updates in real-time as you move.",
            icon: "ruler",
            color: .blue
        ),
        OnboardingStep(
            title: "Direction Arrow",
            description: "The blue arrow in the center always points toward your Arduino device. Turn your phone until the arrow points up, then walk forward.",
            icon: "location.north.fill",
            color: .blue
        ),
        OnboardingStep(
            title: "Close Range Mode",
            description: "When you're within 5 meters of the device, the background will turn green to let you know you're getting close!",
            icon: "checkmark.circle.fill",
            color: .green
        ),
        OnboardingStep(
            title: "How to Navigate",
            description: "1. Turn until the arrow points up\n2. Walk forward toward the device\n3. Watch the distance decrease\n4. Look for the green background when close!",
            icon: "figure.walk",
            color: .orange
        )
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss on tap outside
                }
            
            VStack(spacing: 32) {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.top, 60)
                
                // Step content
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(steps[currentStep].color.opacity(0.2))
                            .frame(width: 80, height: 80)
                        Image(systemName: steps[currentStep].icon)
                            .font(.system(size: 32))
                            .foregroundColor(steps[currentStep].color)
                    }
                    
                    Text(steps[currentStep].title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(steps[currentStep].description)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(minHeight: 200)
                
                Spacer()
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Previous")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(12)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if currentStep < steps.count - 1 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep += 1
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented = false
                                currentStep = 0
                            }
                        }
                    }) {
                        HStack {
                            Text(currentStep < steps.count - 1 ? "Next" : "Got it!")
                            if currentStep < steps.count - 1 {
                                Image(systemName: "chevron.right")
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
        }
    }
}

struct OnboardingStep {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

// MARK: - Enhanced Direction Arrow
struct SimpleDirectionArrow: View {
    let uwbLocation: UWBLocation
    let deviceHeading: Double
    let showDebug: Bool
    
    // Enhanced direction calculation using improved Qorvo algorithms
    private var arrowRotation: Double {
        // Use enhanced azimuth calculation from UWBLocation
        let enhancedAzimuth = Double(uwbLocation.enhancedAzimuth)
        
        // Apply device heading correction for true north
        let correctedAzimuth = enhancedAzimuth - deviceHeading
        let normalizedRotation = (correctedAzimuth + 360).truncatingRemainder(dividingBy: 360)
        
        return normalizedRotation
    }
    
    // Visual feedback based on positioning accuracy
    private var arrowColor: LinearGradient {
        if !uwbLocation.isValid {
            return LinearGradient(colors: [.gray, .gray.opacity(0.6)], startPoint: .top, endPoint: .bottom)
        } else if uwbLocation.noUpdate {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
        } else if uwbLocation.isConverged {
            return LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
        } else {
            return LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom)
        }
    }
    
    // Dynamic arrow size based on distance for better UX
    private var arrowSize: CGFloat {
        let distance = uwbLocation.distance
        if distance < 2.0 {
            return 80 // Larger when very close
        } else if distance < 10.0 {
            return 60 // Medium size for moderate distance
        } else {
            return 50 // Smaller for far distances
        }
    }
    
    // Static formatter for debug timestamps
    private static var debugTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    var body: some View {
        ZStack {
            // Simple circular background
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                .frame(width: 200, height: 200)
            
            // Enhanced direction arrow with dynamic properties
            VStack {
                Image(systemName: uwbLocation.isConverged ? "location.north.fill" : "location.north")
                    .font(.system(size: arrowSize))
                    .foregroundStyle(arrowColor)
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 2, y: 2)
                    .scaleEffect(uwbLocation.isValid ? 1.0 : 0.7)
                    .opacity(uwbLocation.isValid ? 1.0 : 0.5)
                
                // Accuracy indicator
                if uwbLocation.isConverged {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 4, height: 4)
                        .offset(y: -5)
                }
            }
            .rotationEffect(.degrees(arrowRotation))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: arrowRotation)
            .animation(.easeInOut(duration: 0.3), value: uwbLocation.isValid)
            .animation(.easeInOut(duration: 0.3), value: uwbLocation.isConverged)
            
            // Enhanced debug information overlay
            if showDebug {
                VStack(alignment: .leading, spacing: 2) {
                        Text("🔍 RAW DEBUG DATA (3-tap to hide)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                        
                        Divider().background(Color.white.opacity(0.3))
                        
                        Group {
                            Text("📍 Distance: \(String(format: "%.4f", uwbLocation.distance))m")
                            Text("🧭 Device Heading: \(String(format: "%.2f", deviceHeading))°")
                            Text("🎯 Raw Direction: x=\(String(format: "%.6f", uwbLocation.direction.x)), y=\(String(format: "%.6f", uwbLocation.direction.y)), z=\(String(format: "%.6f", uwbLocation.direction.z))")
                        }
                        .font(.caption2)
                        .foregroundColor(.white)
                        
                        Divider().background(Color.white.opacity(0.3))
                        
                        Group {
                            Text("📐 Enhanced Az: \(String(format: "%.2f", uwbLocation.enhancedAzimuth))°")
                            Text("📏 Enhanced El: \(String(format: "%.2f", uwbLocation.enhancedElevation))°")
                            Text("🔄 Arrow Rotation: \(String(format: "%.2f", arrowRotation))°")
                            Text("📱 Horizontal Angle: \(String(format: "%.4f", uwbLocation.horizontalAngle)) rad")
                        }
                        .font(.caption2)
                        .foregroundColor(.cyan)
                        
                        Divider().background(Color.white.opacity(0.3))
                        
                        Group {
                            Text("✅ Converged: \(uwbLocation.isConverged ? "YES" : "NO")")
                                .foregroundColor(uwbLocation.isConverged ? .green : .red)
                            Text("✅ Data Valid: \(uwbLocation.isValid ? "YES" : "NO")")
                                .foregroundColor(uwbLocation.isValid ? .green : .red)
                            Text("⚠️ No Update: \(uwbLocation.noUpdate ? "YES" : "NO")")
                                .foregroundColor(uwbLocation.noUpdate ? .orange : .green)
                            Text("🔢 Vertical Est: \(uwbLocation.verticalDirectionEstimate)")
                        }
                        .font(.caption2)
                        .fontWeight(.semibold)
                        
                        Divider().background(Color.white.opacity(0.3))
                        
                        Text("⏰ Updated: \(uwbLocation.timestamp, formatter: Self.debugTimeFormatter)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                .frame(maxWidth: 280, maxHeight: 200)
                .padding(8)
                .background(Color.black.opacity(0.9))
                .cornerRadius(8)
                .position(x: 150, y: 50)
            }
        }
    }
}

// MARK: - Simple UWB Status Card
struct SimpleUWBStatusCard: View {
    let uwbLocation: UWBLocation
    let protocolState: String
    let isClose: Bool
    let showDebug: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Connection status header
            HStack {
                Text("Arduino Stella Board")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(uwbLocation.isConverged ? Color.green : (uwbLocation.isValid ? Color.blue : Color.orange))
                        .frame(width: 10, height: 10)
                    Text(protocolState)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    if uwbLocation.isConverged {
                        Image(systemName: "target")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            
            if uwbLocation.isValid {
                // Simple navigation instructions
                VStack(spacing: 12) {
                    if isClose {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("You're close! Look around for your device.")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    } else {
                        VStack(spacing: 8) {
                            Text("📍 Turn until the arrow points ⬆️")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            Text("🚶 Walk forward toward the device")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            
                            // Enhanced positioning status
                            if uwbLocation.isConverged {
                                HStack(spacing: 4) {
                                    Image(systemName: "target")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    Text("Enhanced Accuracy")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            } else if uwbLocation.noUpdate {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text("Move for better positioning")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("Waiting for UWB positioning data...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Timestamp and tips
            VStack(spacing: 4) {
                Text("Updated: \(uwbLocation.timestamp, formatter: timeFormatter)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                
                if !showDebug {
                    Text("Triple-tap compass for raw debug • Tap friends view 3x for tutorial")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(20)
        .background(Color(hex: "232229"))
        .cornerRadius(20)
        .padding(.horizontal, 16)
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }
    
    private var debugTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
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
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                    .frame(width: 200, height: 200)
                
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
    
    var simpleUWBCompassCard: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            
            // Large distance display at top
            VStack(spacing: 8) {
                Text(String(format: "%.1f", bleManager.uwbLocation.distance))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(isCloseToDevice ? .green : .white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                    .animation(.easeInOut(duration: 0.3), value: isCloseToDevice)
                
                Text("METERS")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(3)
                
                if isCloseToDevice {
                    Text("🎯 CLOSE!")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .animation(.easeInOut(duration: 0.3), value: isCloseToDevice)
                }
            }
            .padding(.top, 40)
            
            Spacer(minLength: 40)
            
            // Simple direction arrow in center
            SimpleDirectionArrow(
                uwbLocation: bleManager.uwbLocation,
                deviceHeading: deviceHeading,
                showDebug: showDebugInfo
            )
            .frame(height: 200)
            
            Spacer(minLength: 40)
            
            // Simple status card
            SimpleUWBStatusCard(
                uwbLocation: bleManager.uwbLocation,
                protocolState: bleManager.protocolState,
                isClose: isCloseToDevice,
                showDebug: showDebugInfo
            )
            
            Spacer(minLength: 20)
        }
    }
    
    var connectedProxiCard: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 200, height: 200)
                
                if let friend = selectedFriend ?? compassFriends.first {
                    FriendArrow(
                        friend: friend,
                        deviceHeading: deviceHeading,
                        isSelected: true
                    )
                }
                
                // Tap instruction hint
                if tapCount > 0 && tapCount < 3 {
                    Text("Tap \(3 - tapCount) more time\(3 - tapCount == 1 ? "" : "s") for tutorial")
                        .font(.caption)
                        .foregroundColor(.yellow.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .offset(y: 150)
                        .animation(.easeInOut(duration: 0.3), value: tapCount)
                }
            }
            .frame(height: 380)
            .padding(.top, 24)
            
            Spacer(minLength: 0)
            
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

// MARK: - Friend Arrow (unchanged)
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
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(arrowRotation))
                .opacity(isSelected ? 1.0 : 0.7)
        }
    }
}

// MARK: - Empty Compass View (unchanged)
struct EmptyCompassView: View {
    var body: some View {
        VStack(spacing: 32) {
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

struct CompassView_Previews: PreviewProvider {
    static var previews: some View {
        CompassView(selectedTab: Binding.constant(1), isSidebarOpen: Binding.constant(false))
            .environmentObject(BLEManager())
            .environmentObject(FriendsManager())
    }
}
