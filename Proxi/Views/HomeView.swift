import SwiftUI

struct HomeView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Binding var selectedTab: Int
    @State private var isPaired: Bool = false // Simulate pairing status
    // Example data for demo purposes
    let recentActivities = [
        "Paired with Proxi Mini 2 hours ago",
        "Added Alex as a friend",
        "Shared location with Jamie"
    ]
    let tips = [
        "You can pair with multiple Proxi devices for groups!",
        "Go to Settings to connect your Proxi.",
        "Use Discover to find new friends nearby."
    ]
    
    @Binding var isSidebarOpen: Bool
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBarView(selectedTab: $selectedTab, isSidebarOpen: $isSidebarOpen)
                ScrollView {
                    VStack(spacing: 28) {
                        // Gradient Welcome Header with Logo
                        ZStack {
                            
                            VStack(spacing: 8) {
                                Image("Logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 100)
                                Text("Welcome to Proxi!")
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    
                                Text("Never Lose Your People Again")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        if isPaired {
                            StatusCard()
                        }
                        
                        // Feature Grid
                        VStack(alignment: .leading, spacing: 12) {
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                FeatureCard(icon: "location", title: "Compass", description: "Find your friends with ease.", gradient: Gradient(colors: [Color.blue, Color.purple]))
                                FeatureCard(icon: "person.3", title: "Friends", description: "Connect and manage your Proxi friends.", gradient: Gradient(colors: [Color.pink, Color.orange]))
                                FeatureCard(icon: "magnifyingglass", title: "Discover", description: "Find new people and devices nearby.", gradient: Gradient(colors: [Color.green, Color.teal]))
                                FeatureCard(icon: "gearshape", title: "Settings", description: "Pair your Proxi and manage preferences.", gradient: Gradient(colors: [Color.gray, Color.indigo]))
                            }
                            .padding(.horizontal, 8)
                        }
                        .padding(.horizontal, 16)
                        
                        // How It Works Section
                        HowItWorksSection()
                        
                        
               
                        
                        // Status Card or Get Started Button]
                        if !isPaired {
                            
                            Button(action: { selectedTab = 4 }) {
                                HStack {
                                    Image(systemName: "bolt.fill")
                                        .foregroundColor(.white)
                                    Text("Pair Now")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 32)
                                .padding(.vertical, 20)
                                .background(LinearGradient(gradient: Gradient(colors: [Color.purple, Color.blue]), startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(16)
                                .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .padding(.horizontal, 16)
                        }
                        // Quick Actions
                        
                        
                        
                        // Tips
                        SectionCard(title: "Tips", icon: "lightbulb.fill") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(tips, id: \.self) { tip in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.yellow)
                                        Text(tip)
                                            .foregroundColor(.white)
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
                        Spacer(minLength: 24)
                    }
                    .padding(.top, 32)
                }
            }
        }
    }
}

struct HowItWorksSection: View {
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("How It Works")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)
            
            // Steps
            HStack(spacing: 16) {
                StepCard(
                    stepNumber: "1",
                    icon: "link.circle.fill",
                    title: "Pair",
                    description: "Connect your Proxi device in seconds",
                    gradient: Gradient(colors: [Color.blue, Color.cyan])
                )
                
                StepCard(
                    stepNumber: "2",
                    icon: "person.2.circle.fill",
                    title: "Connect",
                    description: "Add friends and family to your network",
                    gradient: Gradient(colors: [Color.purple, Color.pink])
                )
                
                StepCard(
                    stepNumber: "3",
                    icon: "location.circle.fill",
                    title: "Find",
                    description: "See real-time locations instantly",
                    gradient: Gradient(colors: [Color.green, Color.teal])
                )
            }
            .padding(.horizontal, 16)
        }
    }
}

struct StepCard: View {
    let stepNumber: String
    let icon: String
    let title: String
    let description: String
    let gradient: Gradient
    
    var body: some View {
        VStack(spacing: 12) {
            // Step Number Badge
            ZStack {
                Circle()
                    .fill(LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                Text(stepNumber)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Icon
            
            
            // Content
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Color(hex: "232229"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                .opacity(0.3)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}


struct StatusCard: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text("Proxi Mini: Connected")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Battery: 85% • Location: On")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding()
        .background(Color(hex: "232229"))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
}




struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            content
        }
        .padding()
        .background(Color(hex: "232229"))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let gradient: Gradient
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .opacity(0.18)
                .background(Color(hex: "232229").cornerRadius(20))
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 54, height: 54)
                        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.white)
                }
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(selectedTab: Binding.constant(0), isSidebarOpen: Binding.constant(false))
    }
} 
