//
//  UserManager.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/20/25.
//
import SwiftUI
import PhotosUI
import Foundation

// MARK: - User Model
class User: ObservableObject, Codable {
    @Published var name: String
    @Published var profileImagePath: String?
    
    init(name: String = "User", profileImagePath: String? = nil) {
        self.name = name
        self.profileImagePath = profileImagePath
    }
    
    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case name, profileImagePath
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        profileImagePath = try container.decodeIfPresent(String.self, forKey: .profileImagePath)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(profileImagePath, forKey: .profileImagePath)
    }
}

// MARK: - User Manager
class UserManager: ObservableObject {
    @Published var currentUser: User
    private let userDefaultsKey = "SavedUser"
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    init() {
        // Load user from UserDefaults
        if let savedUserData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedUser = try? JSONDecoder().decode(User.self, from: savedUserData) {
            self.currentUser = savedUser
        } else {
            self.currentUser = User()
        }
    }
    
    func saveUser() {
        if let encoded = try? JSONEncoder().encode(currentUser) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    func saveProfileImage(_ image: UIImage) -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let filename = "profile_\(UUID().uuidString).jpg"
        let imageURL = documentsPath.appendingPathComponent(filename)
        
        do {
            try imageData.write(to: imageURL)
            
            // Delete old profile image if it exists
            if let oldPath = currentUser.profileImagePath {
                let oldURL = documentsPath.appendingPathComponent(oldPath)
                try? FileManager.default.removeItem(at: oldURL)
            }
            
            currentUser.profileImagePath = filename
            saveUser()
            return filename
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    func getProfileImage() -> UIImage? {
        guard let imagePath = currentUser.profileImagePath else { return nil }
        let imageURL = documentsPath.appendingPathComponent(imagePath)
        return UIImage(contentsOfFile: imageURL.path)
    }
    
    func updateUserName(_ name: String) {
        currentUser.name = name
        saveUser()
    }
}
