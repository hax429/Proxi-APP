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
    @State private var elevation: Int = 0
    @State private var showDebugWindow = false
    @State private var tapCount = 0
    
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
                        
                        // Compass and Distance Display
                        if device.blePeripheralStatus == statusRanging {
                            VStack(spacing: 20) {
                                // Distance
                                if let distance = device.uwbLocation?.distance {
                                    Text(String(format: "%.2f meters", distance))
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                }
                                
                                // Compass with Arrow
                                ZStack {
                                    // Background Compass
                                    Image("compass")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 200, height: 200)
                                        .opacity(0.8)
                                    
                                    // Direction Cursor (Compass Image)
                                    Image("compass")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 60, height: 60)
                                        .foregroundColor(.red)
                                        .rotationEffect(.degrees(rotationAngle))
                                        .animation(.easeInOut(duration: 0.3), value: rotationAngle)
                                        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
                                    
                                    // Center dot
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 8, height: 8)
                                        .shadow(radius: 2)
                                }
                                .onTapGesture {
                                    handleCompassTap()
                                }
                                
                                // Elevation Display
                                VStack(spacing: 8) {
                                    Text("Elevation")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text(getElevationText(elevation))
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(getElevationColor(elevation))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(12)
                                }
                                
                                // Azimuth Display
                                Text("Azimuth: \(String(format: "%.1f°", rotationAngle))")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
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
        .overlay(
            // Debug Window
            debugWindow
        )
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
            
            // Update arrow rotation and elevation based on direction using Qorvo's accurate calculation
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
                
                // Update elevation
                elevation = device.uwbLocation?.elevation ?? 0
            }
        } else {
            selectedDevice = nil
            rotationAngle = 0
            elevation = 0
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
    
    // MARK: - Triple-tap functionality
    private func handleCompassTap() {
        tapCount += 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if tapCount >= 3 {
                showDebugWindow = true
                tapCount = 0
            } else if tapCount == 1 {
                tapCount = 0
            }
        }
    }
    
    // MARK: - Elevation helpers
    private func getElevationText(_ elevation: Int) -> String {
        // Use more sensitive elevation detection based on actual angle
        if let device = connectedDevice,
           let direction = device.uwbLocation?.direction {
            let elevationAngle = calculateElevationAngle(direction)
            
            // More sensitive thresholds for elevation detection
            if elevationAngle > 5.0 {
                return "ABOVE (+\(String(format: "%.1f", elevationAngle))°)"
            } else if elevationAngle < -5.0 {
                return "BELOW (\(String(format: "%.1f", elevationAngle))°)"
            } else {
                return "SAME LEVEL"
            }
        }
        
        // Fallback to original logic if no direction data
        switch elevation {
        case 1: return "ABOVE"
        case -1: return "BELOW"
        case 0: return "SAME LEVEL"
        default: return "UNKNOWN"
        }
    }

    private func calculateElevationAngle(_ direction: simd_float3) -> Float {
        // Calculate elevation angle in degrees from direction vector
        let elevationRad = atan2(direction.y, sqrt(direction.x * direction.x + direction.z * direction.z))
        return elevationRad * 180 / .pi
    }

    private func getElevationColor(_ elevation: Int) -> Color {
        switch elevation {
        case 1: return .blue      // Above
        case -1: return .orange   // Below
        case 0: return .green     // Same level
        default: return .gray     // Unknown
        }
    }
    
    // MARK: - Debug Window
    private var debugWindow: some View {
        Group {
            if showDebugWindow {
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("🔍 UWB Debug Data")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button("✕") {
                                showDebugWindow = false
                            }
                            .foregroundColor(.white)
                        }
                        
                        if let device = connectedDevice,
                           let direction = device.uwbLocation?.direction,
                           let distance = device.uwbLocation?.distance {
                            
                            VStack(alignment: .leading, spacing: 8) {
                                debugRow("Device", device.blePeripheralName)
                                debugRow("Status", device.blePeripheralStatus ?? "Unknown")
                                debugRow("Distance", String(format: "%.4f m", distance))
                                debugRow("Direction X", String(format: "%.6f", direction.x))
                                debugRow("Direction Y", String(format: "%.6f", direction.y))
                                debugRow("Direction Z", String(format: "%.6f", direction.z))
                                debugRow("Raw Azimuth", String(format: "%.6f", calculateAccurateAzimuth(direction)))
                                debugRow("Scaled Azimuth", String(format: "%.2f°", rotationAngle))
                                debugRow("Elevation Raw", String(elevation))
                                debugRow("Elevation Text", getElevationText(elevation))
                                debugRow("Elevation Angle", String(format: "%.2f°", calculateElevationAngle(direction)))
                                debugRow("Direction Enabled", Settings().isDirectionEnable ? "YES" : "NO")
                                debugRow("Device ID", String(device.bleUniqueID))
                                debugRow("No Update Flag", device.uwbLocation?.noUpdate == true ? "YES" : "NO")
                            }
            } else {
                            Text("No UWB data available")
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
                .ignoresSafeArea(.all, edges: .bottom)
                .transition(.move(edge: .bottom))
                .animation(.easeInOut(duration: 0.3), value: showDebugWindow)
            }
        }
    }
    
    private func debugRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 120, alignment: .leading)
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
            Spacer()
        }
        .font(.caption)
    }
}

