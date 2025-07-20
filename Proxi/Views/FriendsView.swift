import SwiftUI
import CoreBluetooth

struct FriendsView: View {
    @StateObject private var bleManager = BLEManager()
    @State private var hasPairedProxi = false // Simulate if user has paired their own Proxi
    @Binding var selectedTab: Int
    @State private var selectedFriendsTab: Int = 0 // 0: Paired, 1: In Range, 2: Nearby, 3: Requests

    // Mock data for demonstration
    @State private var friends: [FriendProfile] = [
        FriendProfile(id: "1", name: "Alex Chen", status: "Online", lastActive: Date(), isOnline: true, avatar: "AC"),
        FriendProfile(id: "2", name: "Jamie Smith", status: "Nearby", lastActive: Date(), isOnline: true, avatar: "JS")
    ]
    @State private var nearbyProxis: [ProxiDevice] = [
        ProxiDevice(id: "4", name: "Taylor's Proxi", distance: 15, isOnline: true, lastSeen: Date()),
        ProxiDevice(id: "5", name: "Morgan's Proxi", distance: 45, isOnline: true, lastSeen: Date())
    ]
    @State private var incomingRequests: [FriendProfile] = [
        FriendProfile(id: "6", name: "Jordan Kim", status: "Requesting", lastActive: Date(), isOnline: true, avatar: "JK")
    ]
    @State private var sentRequests: Set<String> = []

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBarView(selectedTab: $selectedTab)
                if !hasPairedProxi {
                    unpairedStateView
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            pairedFriendsSection
                            nearbyProxisSection
                            incomingRequestsSection
                        }
                        .padding()
                    }
                }
            }
        }
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
                Text("\(friends.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            if friends.isEmpty {
                emptyFriendsView(text: "No paired friends yet.")
            } else {
                VStack(spacing: 8) {
                    ForEach(friends) { friend in
                        HStack {
                            FriendsListRowView(friend: friend, showLastActive: false)
                            Button(action: {
                                // Remove from friends and add to nearbyProxis
                                if let idx = friends.firstIndex(where: { $0.id == friend.id }) {
                                    let proxi = ProxiDevice(
                                        id: friend.id,
                                        name: friend.name,
                                        distance: Int.random(in: 10...100),
                                        isOnline: friend.isOnline,
                                        lastSeen: Date()
                                    )
                                    nearbyProxis.append(proxi)
                                    friends.remove(at: idx)
                                }
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
                Text("\(incomingRequests.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            if incomingRequests.isEmpty {
                emptyFriendsView(text: "No incoming requests.")
            } else {
                VStack(spacing: 8) {
                    ForEach(incomingRequests) { friend in
                        HStack(alignment: .center) {
                            FriendsListRowView(friend: friend)
                            VStack(spacing: 8) {
                                Button(action: {
                                    // Accept logic: move to friends, remove from incomingRequests, ensure not in nearbyProxis
                                    friends.removeAll { $0.id == friend.id }
                                    nearbyProxis.removeAll { $0.id == friend.id }
                                    friends.append(friend)
                                    incomingRequests.removeAll { $0.id == friend.id }
                                }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                        .padding(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                Button(action: {
                                    // Decline logic: move to nearbyProxis, remove from incomingRequests, ensure not in friends
                                    friends.removeAll { $0.id == friend.id }
                                    incomingRequests.removeAll { $0.id == friend.id }
                                    if !nearbyProxis.contains(where: { $0.id == friend.id }) {
                                        let proxi = ProxiDevice(
                                            id: friend.id,
                                            name: friend.name,
                                            distance: Int.random(in: 10...100),
                                            isOnline: friend.isOnline,
                                            lastSeen: Date()
                                        )
                                        nearbyProxis.append(proxi)
                                    }
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
                        // selectedFriend = friend // This state variable is no longer used
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
        FriendsView(selectedTab: Binding.constant(2))
    }
}

