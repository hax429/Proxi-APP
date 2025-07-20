import SwiftUI

struct DiscoverView: View {
    @Binding var selectedTab: Int
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBarView(selectedTab: $selectedTab)
                Spacer()
                Text("Discover")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                Spacer()
            }
        }
    }
}

struct DiscoverView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoverView(selectedTab: Binding.constant(3))
    }
} 
