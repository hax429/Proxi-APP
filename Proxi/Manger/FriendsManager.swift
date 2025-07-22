//
//  FriendsManager.swift
//  Proxi
//
//  Created by Claude on 7/21/25.
//

import Foundation
import SwiftUI

// MARK: - Friend Data Model
struct Friend: Identifiable, Codable {
    let id: String
    let name: String
    let bearing: Double // Direction in degrees
    let distance: Int    // Distance in meters
    let elevation: Int   // Elevation in meters
    let color: Color     // Friend's color for display
    let isOnline: Bool   // Online status
    let lastSeen: Date   // Last seen timestamp
    
    init(id: String = UUID().uuidString, name: String, bearing: Double = 0, distance: Int = 0, elevation: Int = 0, color: Color = .blue, isOnline: Bool = true) {
        self.id = id
        self.name = name
        self.bearing = bearing
        self.distance = distance
        self.elevation = elevation
        self.color = color
        self.isOnline = isOnline
        self.lastSeen = Date()
    }
    
    // Custom coding for Color
    enum CodingKeys: String, CodingKey {
        case id, name, bearing, distance, elevation, isOnline, lastSeen, colorRed, colorGreen, colorBlue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        bearing = try container.decode(Double.self, forKey: .bearing)
        distance = try container.decode(Int.self, forKey: .distance)
        elevation = try container.decode(Int.self, forKey: .elevation)
        isOnline = try container.decode(Bool.self, forKey: .isOnline)
        lastSeen = try container.decode(Date.self, forKey: .lastSeen)
        
        let red = try container.decode(Double.self, forKey: .colorRed)
        let green = try container.decode(Double.self, forKey: .colorGreen)
        let blue = try container.decode(Double.self, forKey: .colorBlue)
        color = Color(red: red, green: green, blue: blue)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(bearing, forKey: .bearing)
        try container.encode(distance, forKey: .distance)
        try container.encode(elevation, forKey: .elevation)
        try container.encode(isOnline, forKey: .isOnline)
        try container.encode(lastSeen, forKey: .lastSeen)
        
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        try container.encode(Double(red), forKey: .colorRed)
        try container.encode(Double(green), forKey: .colorGreen)
        try container.encode(Double(blue), forKey: .colorBlue)
    }
}

// MARK: - Friends Manager
class FriendsManager: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var incomingRequests: [Friend] = []
    @Published var nearbyProxis: [ProxiDevice] = []
    
    private let userDefaults = UserDefaults.standard
    private let friendsKey = "saved_friends"
    private let requestsKey = "incoming_requests"
    
    init() {
        loadFriends()
        loadIncomingRequests()
        // Add some sample nearby proxis for demonstration
        loadSampleNearbyProxis()
    }
    
    // MARK: - Core Friend Management
    func addFriend(_ friend: Friend) {
        if !friends.contains(where: { $0.id == friend.id }) {
            friends.append(friend)
            saveFriends()
        }
    }
    
    func removeFriend(_ friend: Friend) {
        friends.removeAll { $0.id == friend.id }
        saveFriends()
    }
    
    func updateFriend(_ friend: Friend) {
        if let index = friends.firstIndex(where: { $0.id == friend.id }) {
            friends[index] = friend
            saveFriends()
        }
    }
    
    // MARK: - Friend Request Management
    func acceptFriendRequest(_ friend: Friend) {
        // Remove from requests
        incomingRequests.removeAll { $0.id == friend.id }
        // Add to friends
        addFriend(friend)
        saveIncomingRequests()
    }
    
    func declineFriendRequest(_ friend: Friend) {
        incomingRequests.removeAll { $0.id == friend.id }
        saveIncomingRequests()
    }
    
    func sendFriendRequest(to proxi: ProxiDevice) {
        // Simulate sending a friend request
        // In a real implementation, this would send a request over BLE or network
        print("Sending friend request to \(proxi.name)")
    }
    
    // MARK: - Compass-related Methods
    func getCompassFriends() -> [Friend] {
        // Return online friends for compass display
        return friends.filter { $0.isOnline }
    }
    
    func updateFriendLocation(_ friendId: String, bearing: Double, distance: Int, elevation: Int = 0) {
        if let index = friends.firstIndex(where: { $0.id == friendId }) {
            let updatedFriend = Friend(
                id: friends[index].id,
                name: friends[index].name,
                bearing: bearing,
                distance: distance,
                elevation: elevation,
                color: friends[index].color,
                isOnline: friends[index].isOnline
            )
            friends[index] = updatedFriend
            saveFriends()
        }
    }
    
    // MARK: - Persistence
    private func saveFriends() {
        if let encoded = try? JSONEncoder().encode(friends) {
            userDefaults.set(encoded, forKey: friendsKey)
        }
    }
    
    private func loadFriends() {
        if let data = userDefaults.data(forKey: friendsKey),
           let decoded = try? JSONDecoder().decode([Friend].self, from: data) {
            friends = decoded
        }
    }
    
    private func saveIncomingRequests() {
        if let encoded = try? JSONEncoder().encode(incomingRequests) {
            userDefaults.set(encoded, forKey: requestsKey)
        }
    }
    
    private func loadIncomingRequests() {
        if let data = userDefaults.data(forKey: requestsKey),
           let decoded = try? JSONDecoder().decode([Friend].self, from: data) {
            incomingRequests = decoded
        }
    }
    
    // MARK: - Sample Data for Development
    private func loadSampleNearbyProxis() {
        nearbyProxis = [
            ProxiDevice(id: "proxi1", name: "Arduino Stella #1", distance: 25, isOnline: true, lastSeen: Date()),
            ProxiDevice(id: "proxi2", name: "Arduino Stella #2", distance: 48, isOnline: true, lastSeen: Date()),
            ProxiDevice(id: "proxi3", name: "UWB Tracker Pro", distance: 32, isOnline: false, lastSeen: Date().addingTimeInterval(-300))
        ]
    }
    
    func loadSampleData() {
        // Add sample friends for development/testing
        let sampleFriends = [
            Friend(name: "Alice", bearing: 45, distance: 15, color: .blue),
            Friend(name: "Bob", bearing: 180, distance: 32, color: .green),
            Friend(name: "Charlie", bearing: 270, distance: 28, elevation: 5, color: .red)
        ]
        
        for friend in sampleFriends {
            if !friends.contains(where: { $0.name == friend.name }) {
                addFriend(friend)
            }
        }
        
        // Add sample incoming requests
        let sampleRequests = [
            Friend(name: "Diana", bearing: 90, distance: 0, color: .purple, isOnline: true),
            Friend(name: "Eve", bearing: 0, distance: 0, color: .orange, isOnline: true)
        ]
        
        for request in sampleRequests {
            if !incomingRequests.contains(where: { $0.name == request.name }) {
                incomingRequests.append(request)
            }
        }
        saveIncomingRequests()
    }
}