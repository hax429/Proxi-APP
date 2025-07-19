import SwiftUI

struct DiscoverView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBarView()
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
        DiscoverView()
    }
} 
