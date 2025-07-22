//
//  ProxiApp.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/16/25.
//
//  Main application entry point for Proxi UWB Social Networking App.
//  This file initializes the core managers and sets up the SwiftUI environment.
//

import SwiftUI
import CoreBluetooth

/**
 * ProxiApp - Main Application Entry Point
 * 
 * This is the root application struct that initializes the app and sets up
 * the environment objects for state management across the entire application.
 * 
 * Key Responsibilities:
 * - Initialize core managers (BLE, Friends, User)
 * - Set up SwiftUI environment objects
 * - Configure the main window group
 * - Establish the app's dependency injection system
 * 
 * Architecture:
 * - Uses @StateObject for persistent state management
 * - Implements environment object pattern for dependency injection
 * - Follows MVVM architecture with centralized state management
 */
@main
struct ProxiApp: App {
    
    // MARK: - Core Managers (State Objects)
    
    /// Manages all Bluetooth Low Energy operations including device scanning,
    /// connection management, and UWB session handling
    @StateObject private var bleManager = BLEManager()
    
    /// Handles social networking features including friend discovery,
    /// profile management, and social interactions
    @StateObject private var friendsManager = FriendsManager()
    
    /// Manages user profile data, authentication, and app preferences
    @StateObject private var userManager = UserManager()
    
    // MARK: - App Body
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject core managers into the SwiftUI environment
                // These will be available to all child views via @EnvironmentObject
                .environmentObject(bleManager)
                .environmentObject(friendsManager)
                .environmentObject(userManager)
        }
    }
}
