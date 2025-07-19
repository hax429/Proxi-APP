import SwiftUI

struct CompassView: View {
    @State private var hasFriends: Bool = false // Simulate if user has paired friends
    @State private var deviceHeading: Double = 0 // Device orientation
    @State private var selectedFriend: Friend? = nil
    
    // Mock data for demonstration
    let mockFriends = [
        Friend(id: "1", name: "Alex", distance: 45, bearing: 45, elevation: 12, color: .blue),
        Friend(id: "2", name: "Jamie", distance: 120, bearing: 180, elevation: -8, color: .green),
        Friend(id: "3", name: "Sam", distance: 85, bearing: 270, elevation: 0, color: .orange)
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBarView()
                
                if !hasFriends {
                    EmptyCompassView()
                } else {
                    CompassInterfaceView(
                        friends: mockFriends,
                        deviceHeading: deviceHeading,
                        selectedFriend: $selectedFriend
                    )
                }
            }
        }
        .onAppear {
            // Simulate device heading updates
            startHeadingUpdates()
        }
    }
    
    private func startHeadingUpdates() {
        // Simulate heading updates every second
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            deviceHeading = (deviceHeading + 5).truncatingRemainder(dividingBy: 360)
        }
    }
}

struct EmptyCompassView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Large compass icon
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 200, height: 200)
                
                // Cardinal directions
                
                
                // Center icon
                Image(systemName: "location.north.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(spacing: 16) {
                Text("No Friends Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Add friends on the Friends tab to start navigating and see their locations in real-time.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct CompassInterfaceView: View {
    let friends: [Friend]
    let deviceHeading: Double
    @Binding var selectedFriend: Friend?
    
    var body: some View {
        VStack(spacing: 0) {
            // Compass Display
            ZStack {
                // Compass background
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 300, height: 300)
                
                // Distance rings
                ForEach([50, 100, 150], id: \.self) { distance in
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                        .frame(width: CGFloat(distance * 3), height: CGFloat(distance * 3))
                }
                
                // Cardinal directions
                CompassDirections()
                
                // Friend arrows
                ForEach(friends) { friend in
                    FriendArrow(
                        friend: friend,
                        deviceHeading: deviceHeading,
                        isSelected: selectedFriend?.id == friend.id
                    )
                    .onTapGesture {
                        selectedFriend = friend
                    }
                }
                
                // Center indicator
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 20, height: 20)
            }
            .frame(height: 350)
            
            // Friend list
            FriendListView(
                friends: friends,
                selectedFriend: $selectedFriend
            )
        }
    }
}

struct CompassDirections: View {
    var body: some View {
        ZStack {
            
        }
    }
}

struct FriendArrow: View {
    let friend: Friend
    let deviceHeading: Double
    let isSelected: Bool
    
    private var arrowRotation: Double {
        (friend.bearing - deviceHeading).truncatingRemainder(dividingBy: 360)
    }
    
    private var arrowLength: CGFloat {
        // Scale arrow length based on distance (min 30, max 120)
        let minLength: CGFloat = 30
        let maxLength: CGFloat = 120
        let scale = min(CGFloat(friend.distance) / 150.0, 1.0)
        return minLength + (maxLength - minLength) * scale
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Arrow
            ZStack {
                // Arrow shaft
                Rectangle()
                    .fill(friend.color)
                    .frame(width: 3, height: arrowLength)
                    .opacity(isSelected ? 1.0 : 0.7)
                
                // Arrow head
                Triangle()
                    .fill(friend.color)
                    .frame(width: 12, height: 8)
                    .offset(y: -arrowLength/2 - 4)
                    .opacity(isSelected ? 1.0 : 0.7)
                
                // Elevation indicator
                if friend.elevation != 0 {
                    Image(systemName: friend.elevation > 0 ? "arrow.up" : "arrow.down")
                        .foregroundColor(friend.color)
                        .font(.caption)
                        .offset(y: -arrowLength/2 - 20)
                }
            }
            
            // Friend name and distance
            if isSelected {
                VStack(spacing: 2) {
                    Text(friend.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("\(friend.distance)m")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    
                    if friend.elevation != 0 {
                        Text("\(friend.elevation > 0 ? "+" : "")\(friend.elevation)m")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
            }
        }
        .rotationEffect(.degrees(arrowRotation))
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct FriendListView: View {
    let friends: [Friend]
    @Binding var selectedFriend: Friend?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Friends Nearby")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(friends.count) connected")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(friends) { friend in
                        FriendRowView(
                            friend: friend,
                            isSelected: selectedFriend?.id == friend.id
                        )
                        .onTapGesture {
                            selectedFriend = selectedFriend?.id == friend.id ? nil : friend
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color(hex: "232229"))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
}

struct FriendRowView: View {
    let friend: Friend
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Friend avatar
            Circle()
                .fill(friend.color)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(friend.name.prefix(1)))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text("\(friend.distance)m")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    if friend.elevation != 0 {
                        Text("\(friend.elevation > 0 ? "+" : "")\(friend.elevation)m")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            // Direction indicator
            Image(systemName: "location.north.fill")
                .foregroundColor(friend.color)
                .rotationEffect(.degrees(friend.bearing))
        }
        .padding()
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? friend.color : Color.clear, lineWidth: 1)
        )
    }
}

// Data Models
struct Friend: Identifiable {
    let id: String
    let name: String
    let distance: Int // in meters
    let bearing: Double // in degrees (0-360)
    let elevation: Int // in meters (positive = above, negative = below)
    let color: Color
}

struct CompassView_Previews: PreviewProvider {
    static var previews: some View {
        CompassView()
    }
} 
