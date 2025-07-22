//
//  SettingsSupView.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/20/25.
//

import SwiftUI
import PhotosUI
import MessageUI

// MARK: - Placeholder Views for Sheets
struct ProfileView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var editingName = false
    @State private var tempName = ""
    @State private var selectedImage: PhotosPickerItem?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                // Header
                HStack {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Edit Profile")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Profile Image Section
                        VStack(spacing: 16) {
                            PhotosPicker(selection: $selectedImage,
                                        matching: .images,
                                        photoLibrary: .shared()) {
                                if let profileImage = userManager.getProfileImage() {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.blue, lineWidth: 3)
                                        )
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 120, height: 120)
                                        
                                        VStack {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 30))
                                                .foregroundColor(.gray)
                                            Text("Add Photo")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                            .onChange(of: selectedImage) { newItem in
                                Task {
                                    if let newItem = newItem {
                                        if let data = try? await newItem.loadTransferable(type: Data.self),
                                           let image = UIImage(data: data) {
                                            DispatchQueue.main.async {
                                                _ = userManager.setProfileImage(image)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            Text("Tap to change photo")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // Name Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Display Name")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if editingName {
                                VStack(spacing: 12) {
                                    TextField("Enter your name", text: $tempName)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .foregroundColor(.black)
                                    
                                    HStack(spacing: 12) {
                                        Button("Save") {
                                            userManager.updateProfile(name: tempName)
                                            editingName = false
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(tempName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                                        .cornerRadius(8)
                                        .disabled(tempName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                        
                                        Button("Cancel") {
                                            tempName = userManager.userProfile?.name ?? ""
                                            editingName = false
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.gray)
                                        .cornerRadius(8)
                                    }
                                }
                            } else {
                                HStack {
                                    Text(userManager.userProfile?.name ?? "No name set")
                                        .font(.body)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Button("Edit") {
                                        tempName = userManager.userProfile?.name ?? ""
                                        editingName = true
                                    }
                                    .foregroundColor(.blue)
                                }
                                .padding()
                                .background(Color(hex: "232229"))
                                .cornerRadius(12)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            tempName = userManager.userProfile?.name ?? ""
        }
    }
}

struct NotificationsView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Text("Notifications")
                    .font(.title)
                    .foregroundColor(.white)
                Text("Notification settings coming soon...")
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

struct PrivacyView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Text("Privacy & Security")
                    .font(.title)
                    .foregroundColor(.white)
                Text("Privacy settings coming soon...")
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("About Proxi")
                    .font(.title)
                    .foregroundColor(.white)
                
                VStack(spacing: 8) {
                    Text("Version 1.0.0")
                        .foregroundColor(.white.opacity(0.7))
                    Text("© 2024 Proxi Team")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}

//MARK: Profile selection


struct ProfileSettingsView: View {
    @StateObject private var userManager = UserManager()
    @State private var editingName = false
    @State private var tempName = ""
    @State private var selectedImage: PhotosPickerItem?
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Image Section
            VStack {
                PhotosPicker(selection: $selectedImage,
                            matching: .images,
                            photoLibrary: .shared()) {
                    if let profileImage = userManager.getProfileImage() {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 3)
                            )
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 120, height: 120)
                            
                            VStack {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray)
                                Text("Add Photo")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .onChange(of: selectedImage) { newItem in
                    Task {
                        if let newItem = newItem {
                            if let data = try? await newItem.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                DispatchQueue.main.async {
                                    _ = userManager.setProfileImage(image)
                                }
                            }
                        }
                    }
                }
                
                Text("Tap to change photo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Name Section
            VStack(alignment: .leading) {
                Text("Name")
                    .font(.headline)
                
                if editingName {
                    HStack {
                        TextField("Enter your name", text: $tempName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Save") {
                            userManager.updateProfile(name: tempName)
                            editingName = false
                        }
                        .disabled(tempName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        Button("Cancel") {
                            tempName = userManager.userProfile?.name ?? ""
                            editingName = false
                        }
                    }
                } else {
                    HStack {
                        Text(userManager.userProfile?.name ?? "")
                            .font(.body)
                        
                        Spacer()
                        
                        Button("Edit") {
                            tempName = userManager.userProfile?.name ?? ""
                            editingName = true
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Profile Settings")
        .onAppear {
            tempName = userManager.userProfile?.name ?? ""
        }
    }
}


// MARK: - Mail Composer Views
struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setToRecipients(recipients)
        mailComposer.setSubject(subject)
        return mailComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct MailUnavailableView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.red)
                
                Text("Mail Not Available")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Please configure your Mail app or contact us directly at:")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Text("superkatiebros@gmail.com")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        UIPasteboard.general.string = "superkatiebros@gmail.com"
                    }
                
                Text("Tap email to copy")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}


//MARK: Setting Extensions

