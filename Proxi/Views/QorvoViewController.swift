//
//  QorvoViewController.swift
//  Proxi
//
//  Created by Claude on 7/21/25.
//

import SwiftUI
import UIKit
import NearbyInteraction
import ARKit
import RealityKit
import CoreBluetooth
import simd

// MARK: - SwiftUI UWB Tracker View
struct QorvoView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var friendsManager: FriendsManager
    @Binding var isSidebarOpen: Bool
    @State private var selectedDevice: qorvoDevice?
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                TopBarView(selectedTab: $selectedTab, isSidebarOpen: $isSidebarOpen)
                
                // Main UWB Content
                VStack(spacing: 24) {
                    if let device = connectedDevice {
                        // Device Info
                        VStack(spacing: 8) {
                            Text(device.blePeripheralName)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text(device.blePeripheralStatus ?? "Unknown")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        // Arrow and Distance Display
                        if device.blePeripheralStatus == statusRanging {
                            VStack(spacing: 16) {
                                // Distance
                                if let distance = device.uwbLocation?.distance {
                                    Text(String(format: "%.2f meters", distance))
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                }
                                
                                // 2D Arrow
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 60, weight: .bold))
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(rotationAngle))
                                    .animation(.easeInOut(duration: 0.3), value: rotationAngle)
                                
                                // Direction Info
                                if let direction = device.uwbLocation?.direction {
                                    VStack(spacing: 4) {
                                        Text("Direction")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                        Text("X: \(String(format: "%.2f", direction.x)), Z: \(String(format: "%.2f", direction.z))")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                            }
                        } else {
                            VStack(spacing: 16) {
                                Text("Device connected - initializing ranging...")
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                            }
                        }
                    } else {
                        // No device connected
                        VStack(spacing: 16) {
                            Image(systemName: "location.viewfinder")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.3))
                            
                            Text("No Device Connected")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text("Use Settings to connect to UWB devices")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                            
                            Button("Go to Settings") {
                                selectedTab = 4
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                
                Spacer()
            }
        }
        .onAppear {
            startDeviceMonitoring()
        }
    }
    
    private var connectedDevice: qorvoDevice? {
        qorvoDevices.compactMap { $0 }.first { device in
            device.blePeripheralStatus == statusConnected || device.blePeripheralStatus == statusRanging
        }
    }
    
    private func startDeviceMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            updateDeviceState()
        }
    }
    
    private func updateDeviceState() {
        if let device = connectedDevice {
            selectedDevice = device
            
            // Update arrow rotation based on direction using Qorvo's accurate calculation
            if let direction = device.uwbLocation?.direction, device.blePeripheralStatus == statusRanging {
                let azimuthValue = calculateAccurateAzimuth(direction)
                
                // Check if azimuth calculation is valid (not NaN or infinite)
                if azimuthValue.isNaN || azimuthValue.isInfinite {
                    return
                }
                
                // Apply the same scaling as the previous accurate implementation
                let azimuthDegrees: Double
                if Settings().isDirectionEnable {
                    // For direction-enabled devices (iPhone 14+)
                    azimuthDegrees = 90.0 * Double(azimuthValue)
                } else {
                    // For non-direction-enabled devices
                    azimuthDegrees = Double(azimuthValue) * 180.0 / .pi
                }
                
                rotationAngle = azimuthDegrees
            }
        } else {
            selectedDevice = nil
            rotationAngle = 0
        }
    }
    
    // Accurate azimuth calculation matching the previous Qorvo implementation
    private func calculateAccurateAzimuth(_ direction: simd_float3) -> Float {
        if Settings().isDirectionEnable {
            return asin(direction.x)
        } else {
            return atan2(direction.x, direction.z)
        }
    }
}

