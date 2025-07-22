import SwiftUI
import PhotosUI
import UIKit

struct TopBarView: View {
    @Binding var selectedTab: Int
    @Binding var isSidebarOpen: Bool
    @EnvironmentObject var userManager: UserManager
    @State private var showingImagePicker = false
    @State private var selectedImage: PhotosPickerItem?
    
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
            
            // Logo
            Image("Logo text")
                .resizable()
                .scaledToFit()
                .frame(height: 40)
            
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
    }
}

struct TopBarView_Previews: PreviewProvider {
    static var previews: some View {
        TopBarView(selectedTab: .constant(0), isSidebarOpen: .constant(false))
    }
} 
