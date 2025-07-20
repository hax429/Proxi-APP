//
//  ProxiApp.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/16/25.
//

import SwiftUI
import CoreBluetooth



@main
struct ProxiApp: App {
    @StateObject private var bleManager = BLEManager()
    @StateObject private var friendsManager = FriendsManager()
    @StateObject private var userManager = UserManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleManager)
                .environmentObject(friendsManager)
                .environmentObject(userManager)
        }
    }
}
