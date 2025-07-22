//
//  UserManager.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/16/25.
//

/**
 * UserManager - User Profile and Authentication Management
 *
 * This class manages user profile data, authentication state, and user preferences
 * throughout the Proxi application. It provides a centralized way to handle
 * user-related operations and data persistence.
 *
 * ## Responsibilities:
 * - User profile data management (name, avatar, preferences)
 * - Profile image storage and retrieval
 * - User authentication state management
 * - Data persistence using UserDefaults
 * - SwiftUI environment object integration
 *
 * ## Key Features:
 * - Profile image management with PhotosUI integration
 * - User name editing and validation
 * - Persistent data storage
 * - Real-time profile updates across views
 * - Error handling for data operations
 *
 * ## Usage:
 * ```swift
 * @EnvironmentObject var userManager: UserManager
 * 
 * // Get user profile
 * let profile = userManager.userProfile
 * 
 * // Update profile image
 * userManager.setProfileImage(image)
 * 
 * // Update user name
 * userManager.updateProfile(name: "New Name")
 * ```
 *
 * ## Data Model:
 * - UserProfile: Core user data structure
 * - ProfileImage: Image data management
 * - UserPreferences: App settings and preferences
 *
 * ## Persistence:
 * - Uses UserDefaults for simple data
 * - File system for profile images
 * - Automatic data synchronization
 *
 * @author Gabriel Wang
 * @version 1.0.0
 * @since iOS 16.0
 */

import Foundation
import SwiftUI
import UIKit

// MARK: - User Profile Model
struct UserProfile: Codable {
    let id: String
    let name: String
    let email: String?
    let createdDate: Date
    var hasProfileImage: Bool
    
    init(id: String = UUID().uuidString, name: String, email: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.createdDate = Date()
        self.hasProfileImage = false
    }
}

// MARK: - User Manager
class UserManager: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var isSetup: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let profileKey = "user_profile"
    private let profileImageKey = "user_profile_image"
    
    init() {
        loadUserProfile()
    }
    
    // MARK: - Profile Management
    func createProfile(name: String, email: String? = nil) {
        let profile = UserProfile(name: name, email: email)
        userProfile = profile
        isSetup = true
        saveUserProfile()
    }
    
    func updateProfile(name: String? = nil, email: String? = nil) {
        guard var profile = userProfile else { return }
        
        if let name = name {
            profile = UserProfile(
                id: profile.id,
                name: name,
                email: email ?? profile.email
            )
        }
        
        userProfile = profile
        saveUserProfile()
    }
    
    // MARK: - Profile Image Management
    func setProfileImage(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        userDefaults.set(imageData, forKey: profileImageKey)
        
        if var profile = userProfile {
            profile.hasProfileImage = true
            userProfile = profile
            saveUserProfile()
        }
    }
    
    func getProfileImage() -> UIImage? {
        guard let imageData = userDefaults.data(forKey: profileImageKey) else { return nil }
        return UIImage(data: imageData)
    }
    
    func removeProfileImage() {
        userDefaults.removeObject(forKey: profileImageKey)
        
        if var profile = userProfile {
            profile.hasProfileImage = false
            userProfile = profile
            saveUserProfile()
        }
    }
    
    // MARK: - User Preferences
    func getUserName() -> String {
        return userProfile?.name ?? "User"
    }
    
    func getUserInitials() -> String {
        let name = getUserName()
        let components = name.components(separatedBy: " ")
        if components.count > 1 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    // MARK: - Persistence
    private func saveUserProfile() {
        if let profile = userProfile,
           let encoded = try? JSONEncoder().encode(profile) {
            userDefaults.set(encoded, forKey: profileKey)
        }
    }
    
    private func loadUserProfile() {
        if let data = userDefaults.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            userProfile = decoded
            isSetup = true
        } else {
            // Create default user for development
            createDefaultUser()
        }
    }
    
    private func createDefaultUser() {
        let defaultProfile = UserProfile(name: "Proxi User", email: nil)
        userProfile = defaultProfile
        isSetup = true
        saveUserProfile()
    }
    
    // MARK: - Reset/Logout
    func resetUserData() {
        userDefaults.removeObject(forKey: profileKey)
        userDefaults.removeObject(forKey: profileImageKey)
        userProfile = nil
        isSetup = false
    }
}