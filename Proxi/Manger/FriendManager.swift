//
//  FriendManager.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/20/25.
//

import SwiftUI
import Combine

// MARK: - Enhanced Friends Manager with Location Tracking
class FriendsManager: ObservableObject {
    @Published var friends: [FriendProfile] = []
    @Published var nearbyProxis: [ProxiDevice] = []
    @Published var incomingRequests: [FriendProfile] = []
    @Published var sentRequests: Set<String> = []
    
    // Location tracking for friends
    @Published private var friendLocations: [String: FriendLocation] = [:]
    
    private var locationTimer: Timer?
    
    init() {
        // Initialize with mock data
        friends = [
            FriendProfile(id: "1", name: "Alex Chen", status: "Online", lastActive: Date(), isOnline: true, avatar: "AC"),
            FriendProfile(id: "2", name: "Jamie Smith", status: "Nearby", lastActive: Date(), isOnline: true, avatar: "JS")
        ]
        
        nearbyProxis = [
            ProxiDevice(id: "4", name: "Taylor's Proxi", distance: 15, isOnline: true, lastSeen: Date()),
            ProxiDevice(id: "5", name: "Morgan's Proxi", distance: 45, isOnline: true, lastSeen: Date())
        ]
        
        incomingRequests = [
            FriendProfile(id: "6", name: "Jordan Kim", status: "Requesting", lastActive: Date(), isOnline: true, avatar: "JK")
        ]
        
        // Initialize friend locations
        initializeFriendLocations()
        
        // Start location simulation
        startLocationUpdates()
    }
    
    deinit {
        locationTimer?.invalidate()
    }
    
    // MARK: - Location Management
    private func initializeFriendLocations() {
        for friend in friends {
            friendLocations[friend.id] = FriendLocation(
                id: friend.id,
                distance: Double.random(in: 20...200),
                bearing: Double.random(in: 0...360),
                elevation: Double.random(in: -20...20),
                lastUpdate: Date()
            )
        }
    }
    
    private func startLocationUpdates() {
        locationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.updateFriendLocations()
        }
    }
    
    private func updateFriendLocations() {
        for friendId in friendLocations.keys {
            if var location = friendLocations[friendId] {
                // Simulate slight changes in location
                location.distance += Double.random(in: -5...5)
                location.distance = max(10, min(300, location.distance)) // Keep within bounds
                
                location.bearing += Double.random(in: -10...10)
                location.bearing = location.bearing.truncatingRemainder(dividingBy: 360)
                if location.bearing < 0 { location.bearing += 360 }
                
                location.elevation += Double.random(in: -2...2)
                location.elevation = max(-50, min(50, location.elevation))
                
                location.lastUpdate = Date()
                
                friendLocations[friendId] = location
            }
        }
    }
    
    // MARK: - Friend Management Methods
    func addFriend(_ friend: FriendProfile) {
        // Remove from other lists and add to friends
        friends.removeAll { $0.id == friend.id }
        nearbyProxis.removeAll { $0.id == friend.id }
        incomingRequests.removeAll { $0.id == friend.id }
        friends.append(friend)
        
        // Add location tracking for new friend
        if friendLocations[friend.id] == nil {
            friendLocations[friend.id] = FriendLocation(
                id: friend.id,
                distance: Double.random(in: 20...200),
                bearing: Double.random(in: 0...360),
                elevation: Double.random(in: -20...20),
                lastUpdate: Date()
            )
        }
    }
    
    func removeFriend(_ friend: FriendProfile) {
        friends.removeAll { $0.id == friend.id }
        friendLocations.removeValue(forKey: friend.id)
        
        // Add to nearby proxis
        let proxi = ProxiDevice(
            id: friend.id,
            name: friend.name,
            distance: Int.random(in: 10...100),
            isOnline: friend.isOnline,
            lastSeen: Date()
        )
        nearbyProxis.append(proxi)
    }
    
    func acceptFriendRequest(_ friend: FriendProfile) {
        addFriend(friend)
    }
    
    func declineFriendRequest(_ friend: FriendProfile) {
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
    }
    
    func sendFriendRequest(to proxiId: String) {
        sentRequests.insert(proxiId)
    }
    
    // MARK: - Convert FriendProfile to Friend for Compass
    func getCompassFriends() -> [Friend] {
        return friends.enumerated().map { index, friendProfile in
            let location = friendLocations[friendProfile.id] ?? FriendLocation(
                id: friendProfile.id,
                distance: Double.random(in: 20...200),
                bearing: Double.random(in: 0...360),
                elevation: Double.random(in: -20...20),
                lastUpdate: Date()
            )
            
            return Friend(
                id: friendProfile.id,
                name: friendProfile.name,
                distance: Int(location.distance),
                bearing: location.bearing,
                elevation: Int(location.elevation),
                color: predefinedColors[index % predefinedColors.count]
            )
        }
    }
    
    // MARK: - Location Data Methods
    func getFriendLocation(_ friendId: String) -> FriendLocation? {
        return friendLocations[friendId]
    }
    
    func updateFriendLocation(_ friendId: String, distance: Double, bearing: Double, elevation: Double) {
        friendLocations[friendId] = FriendLocation(
            id: friendId,
            distance: distance,
            bearing: bearing,
            elevation: elevation,
            lastUpdate: Date()
        )
    }
    
    private let predefinedColors: [Color] = [.blue, .green, .orange, .purple, .red, .yellow, .pink, .cyan]
}

// MARK: - Supporting Data Models
struct FriendLocation {
    let id: String
    var distance: Double
    var bearing: Double
    var elevation: Double
    var lastUpdate: Date
}

// Extension to add convenience methods
extension FriendsManager {
    var onlineFriendsCount: Int {
        friends.filter { $0.isOnline }.count
    }
    
    var nearbyFriendsCount: Int {
        friends.filter { friend in
            if let location = friendLocations[friend.id] {
                return location.distance < 100 // Within 100 meters
            }
            return false
        }.count
    }
    
    func getFriendsWithinRange(_ maxDistance: Double) -> [Friend] {
        return getCompassFriends().filter { $0.distance <= Int(maxDistance) }
    }
}
