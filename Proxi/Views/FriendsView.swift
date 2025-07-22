
import SwiftUI
import CoreBluetooth

struct FriendsView: View {
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var friendsManager: FriendsManager // Add this
    @Binding var selectedTab: Int
    @State private var selectedFriendsTab: Int = 0
    @Binding var isSidebarOpen: Bool

    // Computed property that uses BLE connection status
    private var hasPairedProxi: Bool {
        bleManager.isConnected
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
                            // Connection status header when paired
                            connectionStatusHeader
                            pairedFriendsSection
                            nearbyProxisSection
                            incomingRequestsSection
                        }
                        .padding()
                    }
                }
            }
        }
        .onChange(of: bleManager.isConnected) { isConnected in
            if isConnected {
                // Device just connected - provide haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
        }
    }

    // MARK: - Connection Status Header
    private var connectionStatusHeader: some View {
        HStack(spacing: 16) {
            // Proxi status indicator
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
                    Text("Ready to discover friends")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text("Connection lost")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            if bleManager.isConnected && bleManager.rssi != 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Signal")
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

    // MARK: - Paired Friends
    private var pairedFriendsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Currently Paired")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(friendsManager.friends.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            if friendsManager.friends.isEmpty {
                emptyFriendsView(text: "No paired friends yet.")
            } else {
                VStack(spacing: 8) {
                    ForEach(friendsManager.friends) { friend in
                        HStack {
                            FriendsListRowView(friend: friend, showLastActive: false)
                            Button(action: {
                                friendsManager.removeFriend(friend)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.title2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
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
        .background(Color(hex: "232229"))
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
                Text("Pair Your Proxi First")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("To connect with friends, you need to pair your Proxi device first. This enables you to discover and connect with other Proxi users nearby.")
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
    }
    
    private var nearbyProxisSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Nearby Proxis")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(friendsManager.nearbyProxis.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if friendsManager.nearbyProxis.isEmpty {
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
        .background(Color(hex: "232229"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var nearbyProxisList: some View {
        VStack(spacing: 8) {
            ForEach(friendsManager.nearbyProxis) { proxi in
                NearbyProxiRowView(proxi: proxi, onSendRequest: {
                    friendsManager.sendFriendRequest(to: proxi)
                })
            }
        }
    }
}

// Keep all the supporting views the same (FriendsListRowView, NearbyProxiRowView, etc.)

struct FriendsView_Previews: PreviewProvider {
    static var previews: some View {
        FriendsView(selectedTab: Binding.constant(2), isSidebarOpen: Binding.constant(false))
            .environmentObject(BLEManager())
            .environmentObject(FriendsManager()) // Add this
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
        .background(Color(hex: "232229"))
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
        .background(Color(hex: "232229"))
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


