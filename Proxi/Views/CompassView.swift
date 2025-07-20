import SwiftUI


//
//  CompassView 2.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/20/25.
//


import SwiftUI

struct CompassView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var friendsManager: FriendsManager
    @State var deviceHeading: Double = 0
    @State var selectedFriend: Friend? = nil
    @Binding var isSidebarOpen: Bool
    
    // Computed property that uses BLE connection status
    var hasPairedProxi: Bool {
        bleManager.isConnected
    }
    
    // Computed property to check if user has friends
    var hasFriends: Bool {
        !friendsManager.friends.isEmpty
    }
    
    // Get friends for compass display
    var compassFriends: [Friend] {
        friendsManager.getCompassFriends()
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBarView(selectedTab: $selectedTab, isSidebarOpen: $isSidebarOpen)
                
                if !hasPairedProxi {
                    connectFirstCard
                } else if !hasFriends {
                    findFriendCard
                } else {
                    connectedProxiCard
                }
                Spacer()
            }
        }
        .onAppear {
            startHeadingUpdates()
        }
        .onChange(of: bleManager.isConnected) { isConnected in
            if isConnected {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                if bleManager.isScanning {
                    bleManager.stopScanning()
                }
            }
        }
    }
    
    private func startHeadingUpdates() {
        // Simulate heading updates every second
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            deviceHeading = (deviceHeading + 5).truncatingRemainder(dividingBy: 360)
        }
    }
}

// Keep all the other supporting views (EmptyCompassView, CompassInterfaceView, etc.) the same
// Just the main CompassView struct changes

struct CompassView_Previews: PreviewProvider {
    static var previews: some View {
        CompassView(selectedTab: Binding.constant(1), isSidebarOpen: Binding.constant(false))
            .environmentObject(BLEManager())
            .environmentObject(FriendsManager()) // Add this
    }
}

