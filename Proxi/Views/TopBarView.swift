import SwiftUI

struct TopBarView: View {
    var body: some View {
        HStack {
            // Hamburger menu
            Image(systemName: "line.horizontal.3")
                .resizable()
                .frame(width: 28, height: 20)
                .foregroundColor(.white)
                .padding(.leading, 24)
            Spacer()
            // Logo
            Image("Logo text")
                .resizable()
                .scaledToFit()
                .frame(height: 40)
            Spacer()
            // Profile image
            Image("Profile placeholder") // Replace with actual asset if available
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .padding(.trailing, 24)
        }
        .frame(height: 60)
        .background(Color.black)
    }
} 
