import SwiftUI
import UIKit

struct DiscoverView: View {
    @Binding var selectedTab: Int
    @Binding var isSidebarOpen: Bool
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var friendsManager: FriendsManager
    
    // Sample data for discovered users
    @State private var discoveredUsers: [DiscoveredUser] = [
        DiscoveredUser(
            id: "1",
            name: "Alex Chen",
            status: "Working",
            statusEmoji: "💼",
            distance: "2.3m",
            playlist: "Lo-Fi Beats",
            isOnline: true,
            profileImage: nil as UIImage?
        ),
        DiscoveredUser(
            id: "2",
            name: "Sarah Kim",
            status: "Studying",
            statusEmoji: "📚",
            distance: "5.1m",
            playlist: "Classical Focus",
            isOnline: true,
            profileImage: nil as UIImage?
        ),
        DiscoveredUser(
            id: "3",
            name: "Mike Rodriguez",
            status: "Gaming",
            statusEmoji: "🎮",
            distance: "8.7m",
            playlist: "Epic Soundtracks",
            isOnline: false,
            profileImage: nil as UIImage?
        ),
        DiscoveredUser(
            id: "4",
            name: "Emma Wilson",
            status: "Working Out",
            statusEmoji: "🏃‍♀️",
            distance: "12.4m",
            playlist: "High Energy Mix",
            isOnline: true,
            profileImage: nil as UIImage?
        ),
        DiscoveredUser(
            id: "5",
            name: "David Park",
            status: "Coffee Break",
            statusEmoji: "☕",
            distance: "3.2m",
            playlist: "Chill Vibes",
            isOnline: true,
            profileImage: nil as UIImage?
        )
    ]
    
    @State private var selectedFilter: DiscoverFilter = .all
    @State private var searchText = ""
    
    var filteredUsers: [DiscoveredUser] {
        let filtered = discoveredUsers.filter { user in
            if !searchText.isEmpty {
                return user.name.localizedCaseInsensitiveContains(searchText) ||
                       user.status.localizedCaseInsensitiveContains(searchText) ||
                       user.playlist.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }
        
        switch selectedFilter {
        case .all:
            return filtered
        case .online:
            return filtered.filter { $0.isOnline }
        case .nearby:
            return filtered.filter { 
                if let distance = Double($0.distance.replacingOccurrences(of: "m", with: "")) {
                    return distance <= 10.0
                }
                return false
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBarView(selectedTab: $selectedTab, isSidebarOpen: $isSidebarOpen)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        headerSection
                        
                        // Search and Filter Section
                        searchAndFilterSection
                        
                        // Discovered Users Section
                        discoveredUsersSection
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Discover")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Find people nearby using Proxi")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Online indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("\(discoveredUsers.filter { $0.isOnline }.count) online")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Stats row
            HStack(spacing: 20) {
                StatCard(title: "Nearby", value: "\(discoveredUsers.count)", icon: "location.fill")
                StatCard(title: "Online", value: "\(discoveredUsers.filter { $0.isOnline }.count)", icon: "circle.fill")
                StatCard(title: "Active", value: "\(discoveredUsers.filter { $0.status != "Offline" }.count)", icon: "person.2.fill")
            }
        }
    }
    
    // MARK: - Search and Filter Section
    private var searchAndFilterSection: some View {
        VStack(spacing: 16) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                
                TextField("Search people, status, or playlists...", text: $searchText)
                    .foregroundColor(.white)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding()
            .background(Color("232229"))
            .cornerRadius(12)
            
            // Filter buttons
            HStack(spacing: 12) {
                FilterButton(title: "All", isSelected: selectedFilter == .all) {
                    selectedFilter = .all
                }
                
                FilterButton(title: "Online", isSelected: selectedFilter == .online) {
                    selectedFilter = .online
                }
                
                FilterButton(title: "Nearby", isSelected: selectedFilter == .nearby) {
                    selectedFilter = .nearby
                }
            }
        }
    }
    
    // MARK: - Discovered Users Section
    private var discoveredUsersSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("People Nearby")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(filteredUsers.count) found")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if filteredUsers.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredUsers) { user in
                        DiscoveredUserCard(user: user)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.4))
            
            Text("No people found")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Try adjusting your search or filters")
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
}

// MARK: - Supporting Views
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("232229"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.white.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct DiscoveredUserCard: View {
    let user: DiscoveredUser
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Image
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                if let profileImage = user.profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Text(String(user.name.prefix(1)))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                // Online indicator
                if user.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                        )
                        .offset(x: 18, y: -18)
                }
            }
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(user.distance)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                HStack(spacing: 6) {
                    Text(user.statusEmoji)
                        .font(.caption)
                    
                    Text(user.status)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                if !user.playlist.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text(user.playlist)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Action Button
            Button(action: {
                // Send friend request or view profile
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
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

// MARK: - Data Models
struct DiscoveredUser: Identifiable {
    let id: String
    let name: String
    let status: String
    let statusEmoji: String
    let distance: String
    let playlist: String
    let isOnline: Bool
    let profileImage: UIImage?
}

enum DiscoverFilter {
    case all, online, nearby
}

struct DiscoverView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoverView(selectedTab: Binding.constant(3), isSidebarOpen: Binding.constant(false))
    }
} 
