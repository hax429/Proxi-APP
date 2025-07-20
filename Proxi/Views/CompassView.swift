import SwiftUI


//
//  CompassView 2.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/20/25.
//


import SwiftUI

struct CompassView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var friendsManager: FriendsManager
    @State private var deviceHeading: Double = 0
    @State private var selectedFriend: Friend? = nil
    @Binding var isSidebarOpen: Bool
    
    // Computed property that uses BLE connection status
    private var hasPairedProxi: Bool {
        true // Replace with bleManager.isConnected if needed
    }
    
    // Computed property to check if user has friends
    private var hasFriends: Bool {
        !friendsManager.friends.isEmpty
    }
    
    // Get friends for compass display
    private var compassFriends: [Friend] {
        friendsManager.getCompassFriends()
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBarView(selectedTab: $selectedTab, isSidebarOpen: $isSidebarOpen)
                
                if !hasPairedProxi {
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
                            Text("Pair Your Proxi First")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("To connect with friends, you need to pair your Proxi device first. This enables you to discover and connect with other Proxi users nearby.")
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
                                Text("Pair My Proxi")
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
                } else if !hasFriends {
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
                            Text("Proxi Connected!")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Your Proxi device is now connected and ready to discover friends.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 60)
                        
                        EmptyCompassView()
                        
                        Button(action: { selectedTab = 2 }) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 20))
                                Text("Add Friends")
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
                            .padding(.bottom, 100)
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        // Compass takes up most of the space
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                .frame(width: 340, height: 340)
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
                Spacer()
            }
        }
        .onAppear {
            startHeadingUpdates()
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
    
    private func startHeadingUpdates() {
        // Simulate heading updates every second
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            deviceHeading = (deviceHeading + 5).truncatingRemainder(dividingBy: 360)
        }
    }
}

// Keep all the other supporting views (EmptyCompassView, CompassInterfaceView, etc.) the same
// Just the main CompassView struct changes

struct CompassView_Previews: PreviewProvider {
    static var previews: some View {
        CompassView(selectedTab: Binding.constant(1), isSidebarOpen: Binding.constant(false))
            .environmentObject(BLEManager())
            .environmentObject(FriendsManager()) // Add this
    }
}

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

struct CompassInterfaceView: View {
    let friends: [Friend]
    let deviceHeading: Double
    @Binding var selectedFriend: Friend?
    
    var body: some View {
        VStack(spacing: 0) {
            // Compass Display
            ZStack {
                // Compass background
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 300, height: 300)
                
                // Distance rings
                ForEach([50, 100, 150], id: \.self) { distance in
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                        .frame(width: CGFloat(distance * 3), height: CGFloat(distance * 3))
                }
                
                // Cardinal directions
                CompassDirections()
                
                // Friend arrows
                ForEach(friends) { friend in
                    FriendArrow(
                        friend: friend,
                        deviceHeading: deviceHeading,
                        isSelected: selectedFriend?.id == friend.id
                    )
                    .onTapGesture {
                        selectedFriend = friend
                    }
                }
                
                // Center indicator
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 20, height: 20)
            }
            .frame(height: 350)
            
            // Friend list
            FriendListView(
                friends: friends,
                selectedFriend: $selectedFriend
            )
        }
    }
}

struct CompassDirections: View {
    var body: some View {
        ZStack {
            
        }
    }
}

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

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct FriendListView: View {
    let friends: [Friend]
    @Binding var selectedFriend: Friend?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Friends Nearby")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(friends.count) connected")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(friends) { friend in
                        FriendRowView(
                            friend: friend,
                            isSelected: selectedFriend?.id == friend.id
                        )
                        .onTapGesture {
                            selectedFriend = selectedFriend?.id == friend.id ? nil : friend
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color(hex: "232229"))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
}

struct FriendRowView: View {
    let friend: Friend
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Friend avatar
            Circle()
                .fill(friend.color)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(friend.name.prefix(1)))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text("\(friend.distance)m")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    if friend.elevation != 0 {
                        Text("\(friend.elevation > 0 ? "+" : "")\(friend.elevation)m")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            // Direction indicator
            Image(systemName: "location.north.fill")
                .foregroundColor(friend.color)
                .rotationEffect(.degrees(friend.bearing))
        }
        .padding()
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? friend.color : Color.clear, lineWidth: 1)
        )
    }
}

// Data Models
struct Friend: Identifiable {
    let id: String
    let name: String
    let distance: Int // in meters
    let bearing: Double // in degrees (0-360)
    let elevation: Int // in meters (positive = above, negative = below)
    let color: Color
}


