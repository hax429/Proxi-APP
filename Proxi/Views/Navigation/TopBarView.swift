import SwiftUI
import PhotosUI
import UIKit
import MessageUI

struct TopBarView: View {
    @Binding var selectedTab: Int
    @Binding var isSidebarOpen: Bool
    @EnvironmentObject var userManager: UserManager
    @State private var showingImagePicker = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var logoTapCount = 0
    @State private var showingMailComposer = false
    
    var body: some View {
        HStack {
            // Hamburger menu
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isSidebarOpen.toggle()
                }
            }) {
                Image(systemName: "line.horizontal.3")
                    .resizable()
                    .frame(width: 28, height: 20)
                    .foregroundColor(.white)
                    .padding(.leading, 24)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Logo with tap gesture
            Image("Logo text")
                .resizable()
                .scaledToFit()
                .frame(height: 40)
                .onTapGesture {
                    handleLogoTap()
                }
            
            Spacer()
            
            // Profile image with PhotosPicker
            PhotosPicker(selection: $selectedImage,
                        matching: .images,
                        photoLibrary: .shared()) {
                if let profileImage = userManager.getProfileImage() {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                } else {
                    Image("Profile placeholder")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.trailing, 24)
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
        }
        .frame(height: 60)
        .background(Color.black)
        .sheet(isPresented: $showingMailComposer) {
            if MailComposerView.canSendMail() {
                MailComposerView(
                    recipient: "superkatiebros@gmail.com",
                    subject: "Hey Katie!",
                    isPresented: $showingMailComposer
                )
            } else {
                FallbackMailView(
                    isPresented: $showingMailComposer,
                    recipient: "superkatiebros@gmail.com"
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    private func handleLogoTap() {
        logoTapCount += 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if self.logoTapCount >= 10 {
                self.showingMailComposer = true
                self.logoTapCount = 0
            } else {
                self.logoTapCount = 0
            }
        }
    }
}

// MARK: - Mail Composer View
struct MailComposerView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([recipient])
        composer.setSubject(subject)
        composer.setMessageBody("Hi Katie!\n\nThe user tapped the Proxi logo 10 times to send you this message!\n\nBest regards,\nProxi App", isHTML: false)
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView
        
        init(_ parent: MailComposerView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.isPresented = false
        }
    }
    
    static func canSendMail() -> Bool {
        return MFMailComposeViewController.canSendMail()
    }
}

// MARK: - Fallback Mail View (for when Mail app is not configured)
struct FallbackMailView: View {
    @Binding var isPresented: Bool
    let recipient: String
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Mail Not Configured")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Please configure the Mail app on your device to send emails, or copy the email address below:")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(recipient)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    
                    Button("Copy") {
                        UIPasteboard.general.string = recipient
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Send Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct TopBarView_Previews: PreviewProvider {
    static var previews: some View {
        TopBarView(selectedTab: .constant(0), isSidebarOpen: .constant(false))
    }
} 
