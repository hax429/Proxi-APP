import SwiftUI
import CoreBluetooth

struct FriendsView: View {
    @StateObject private var bleManager = BLEManager()
    @State private var hasPairedProxi = false // Simulate if user has paired their own Proxi
    @State private var showingFriendRequests = false
    @State private var selectedFriend: FriendProfile? = nil
    @Binding var selectedTab: Int
    
    // Mock data for demonstration
    @State private var nearbyProxis: [ProxiDevice] = [
        ProxiDevice(id: "1", name: "Alex's Proxi", distance: 15, isOnline: true, lastSeen: Date()),
        ProxiDevice(id: "2", name: "Jamie's Proxi", distance: 45, isOnline: true, lastSeen: Date()),
        ProxiDevice(id: "3", name: "Sam's Proxi", distance: 120, isOnline: false, lastSeen: Date().addingTimeInterval(-300))
    ]
    
    @State private var friends: [FriendProfile] = [
        FriendProfile(id: "1", name: "Alex Chen", status: "Online", lastActive: Date(), isOnline: true, avatar: "AC"),
        FriendProfile(id: "2", name: "Jamie Smith", status: "Nearby", lastActive: Date(), isOnline: true, avatar: "JS")
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBarView()
                
                if !hasPairedProxi {
                    unpairedStateView
                } else {
                    pairedStateView
                }
            }
        }
        .sheet(isPresented: $showingFriendRequests) {
            FriendRequestsView()
        }
    }
    
    // MARK: - Unpaired State (User hasn't paired their own Proxi)
    private var unpairedStateView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Large Proxi device illustration
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
            }
            
            // Pairing button
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
    
    // MARK: - Paired State (User has paired their Proxi)
    private var pairedStateView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Status Header
                statusHeader
                
                // Friends List
                friendsListSection
                
                // Nearby Proxis
                nearbyProxisSection
                
                // Quick Actions
                quickActionsSection
            }
            .padding()
        }
    }
    
    private var statusHeader: some View {
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
                Text("Proxi Connected")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Ready to discover friends")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Friend requests badge
            Button(action: { showingFriendRequests = true }) {
                ZStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 32, height: 32)
                    
                    Text("2")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
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
    
    private var friendsListSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Friends")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(friends.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if friends.isEmpty {
                emptyFriendsView
            } else {
                friendsList
            }
        }
    }
    
    private var emptyFriendsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.4))
            
            Text("No Friends Yet")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Discover and connect with nearby Proxi users")
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
    
    private var friendsList: some View {
        VStack(spacing: 8) {
            ForEach(friends) { friend in
                FriendsListRowView(friend: friend)
                    .onTapGesture {
                        selectedFriend = friend
                    }
            }
        }
    }
    
    private var nearbyProxisSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Nearby Proxis")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(nearbyProxis.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if nearbyProxis.isEmpty {
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
            ForEach(nearbyProxis) { proxi in
                NearbyProxiRowView(proxi: proxi)
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 12) {
                quickActionButton(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Scan",
                    subtitle: "Find Proxis",
                    action: { }
                )
                
                quickActionButton(
                    icon: "person.badge.plus",
                    title: "Add Friend",
                    subtitle: "Send request",
                    action: { }
                )
            }
        }
    }
    
    private func quickActionButton(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
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

// MARK: - Supporting Views
struct FriendsListRowView: View {
    let friend: FriendProfile
    
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
                
                Text(friend.avatar)
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
                
                Text(friend.status)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Last active")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                Text(friend.lastActive.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
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
                
                HStack(spacing: 8) {
                    Text("\(proxi.distance)m away")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    if !proxi.isOnline {
                        Text("Offline")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            // Send request button
            Button(action: {
                isRequesting = true
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

struct FriendsView_Previews: PreviewProvider {
    static var previews: some View {
        FriendsView(selectedTab: .constant(2))
    }
}

