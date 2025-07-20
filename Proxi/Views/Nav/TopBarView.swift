import SwiftUI

struct TopBarView: View {
    @Binding var selectedTab: Int
    @Binding var isSidebarOpen: Bool
    
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
            
            // Profile image
            Button(action: {
                selectedTab = 4
                isSidebarOpen = false // Close sidebar when navigating
            }) {
                Image("Profile placeholder") // Replace with actual asset if available
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .padding(.trailing, 24)
            }
            .buttonStyle(PlainButtonStyle())
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
