//
//  QorvoViewController.swift
//  Proxi
//
//  Created by Claude on 7/21/25.
//
//  UWB Compass and Ranging Display Controller
//  This file contains the main UWB interface for displaying real-time ranging data,
//  compass direction, and device management functionality.
//

import SwiftUI
import UIKit
import NearbyInteraction
import ARKit
import RealityKit
import CoreBluetooth
import CoreLocation
import simd

// MARK: - Device Color System

/// Returns a unique UIColor for each device index
func getDeviceColor(for index: Int) -> UIColor {
    let colors: [UIColor] = [
        .systemGreen,    // Device 0 - Green
        .systemBlue,     // Device 1 - Blue  
        .systemOrange,   // Device 2 - Orange
        .systemPurple,   // Device 3 - Purple
        .systemRed,      // Device 4 - Red
        .systemYellow,   // Device 5 - Yellow
        .systemPink,     // Device 6 - Pink
        .systemTeal      // Device 7 - Teal
    ]
    return colors[index % colors.count]
}

/// Returns a unique SwiftUI Color for each device index
func getSwiftUIDeviceColor(for index: Int) -> Color {
    let colors: [Color] = [
        .green,    // Device 0 - Green
        .blue,     // Device 1 - Blue  
        .orange,   // Device 2 - Orange
        .purple,   // Device 3 - Purple
        .red,      // Device 4 - Red
        .yellow,   // Device 5 - Yellow
        .pink,     // Device 6 - Pink
        .teal      // Device 7 - Teal
    ]
    return colors[index % colors.count]
}

// MARK: - QorvoView - Main UWB Interface
/**
 * QorvoView - Ultra-Wideband Compass and Ranging Display
 *
 * This is the primary SwiftUI view for displaying UWB ranging data in a compass format.
 * It integrates UIKit components for advanced UWB visualization and provides
 * real-time distance, direction, and elevation information.
 *
 * ## Key Features:
 * - Real-time UWB ranging display
 * - Interactive compass with directional arrows
 * - Multi-device support and switching
 * - Device heading integration
 * - Calibration controls for accuracy
 * - Debug mode with detailed information
 *
 * ## Architecture:
 * - SwiftUI wrapper around UIKit UWB components
 * - Environment object integration for BLE management
 * - State management for device selection and calibration
 * - Location services integration for device heading
 *
 * ## Usage:
 * ```swift
 * QorvoView(selectedTab: $selectedTab, isSidebarOpen: $isSidebarOpen)
 *     .environmentObject(bleManager)
 * ```
 *
 * ## Multi-Device Support:
 * - Displays connected devices in a compact selector
 * - Allows switching between multiple UWB devices
 * - Maintains individual device data and calibration
 * - Shows device-specific ranging information
 */
struct QorvoView: View {
    
    // MARK: - Environment Objects
    @Binding var selectedTab: Int
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var friendsManager: FriendsManager
    @Binding var isSidebarOpen: Bool
    @Binding var showDebugWindow: Bool
    
    // MARK: - Device Management State
    @State private var selectedDeviceIndex: Int = 0
    @State private var connectedDevicesList: [CBPeripheral] = []
    @State private var isConnecting: Bool = false
    
    // MARK: - Direction and Location Tracking
    @State private var rotationAngle: Double = 0          // Compass rotation angle
    @State private var elevation: Int = 0                 // Elevation angle
    @State private var directionCalibrationOffset: Double = 0  // Calibration offset
    @State private var showCalibrationControls = false    // Calibration UI visibility
    @State private var locationManager = CLLocationManager()   // Location services
    @State private var deviceHeading: Double = 0          // Device magnetic heading

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Main UWB content with UIKit integration
                if let device = currentDevice {
                    ModernQorvoUIView(
                        peripheral: device,
                        deviceData: currentDeviceData,
                        selectedDeviceIndex: selectedDeviceIndex,
                        rotationAngle: $rotationAngle,
                        elevation: $elevation,
                        deviceHeading: $deviceHeading,
                        directionCalibrationOffset: $directionCalibrationOffset,
                        showCalibrationControls: $showCalibrationControls,
                        onCompassTap: {},
                        onCalibrationChanged: saveCalibrationOffset
                    )
                    .onAppear {
                        startDeviceMonitoring()
                        loadCalibrationOffset()
                        setupLocationManager()
                    }
                } else {
                    // No device connected state
                    NoDeviceConnectedView(selectedTab: $selectedTab)
                }
                
                // Available device selector - shows all discovered devices
                if availableDevices.count > 0 {
                    AvailableDeviceSelectorView(
                        devices: availableDevices,
                        selectedIndex: $selectedDeviceIndex,
                        connectedDevices: connectedDevices,
                        isConnecting: isConnecting,
                        onDeviceSelection: handleDeviceSelection
                    )
                    .padding(.bottom, 20)
                }
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .overlay(
            debugWindow
        )
        .onAppear {
            setupLocationManager()
            
            // Listen for device heading updates
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("DeviceHeadingUpdated"),
                object: nil,
                queue: .main
            ) { notification in
                if let heading = notification.userInfo?["heading"] as? CLHeading {
                    self.updateDeviceHeading(heading)
                }
            }
            
            // Listen for debug window requests from Settings
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowUWBDebugWindow"),
                object: nil,
                queue: .main
            ) { _ in
                self.showDebugWindow = true
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /**
     * Connected devices from BLE manager
     * Returns array of currently connected CBPeripheral objects
     */
    private var connectedDevices: [CBPeripheral] {
        return Array(bleManager.connectedPeripherals.values)
    }
    
    /**
     * Available devices from BLE manager discovery
     * Returns array of discovered CBPeripheral objects for display selection
     * Filters out unwanted devices when developer mode is enabled
     */
    private var availableDevices: [CBPeripheral] {
        return bleManager.discoveredPeripherals.filter { peripheral in
            let deviceName = peripheral.name ?? "Unknown Device"
            
            // When developer mode is enabled, filter out specific devices
            if isDeveloperModeEnabled {
                return deviceName != "Unknown Device" && 
                       deviceName != "Adafruit Bluefruit LE AA68"
            } else {
                // Original filtering logic for non-developer mode
                return deviceName != "Adafruit Bluefruit LE AA68"
            }
        }
    }
    

    
    /**
     * Currently selected device for UWB display
     * Returns the device at the selected index, or nil if no devices available
     */
    private var currentDevice: CBPeripheral? {
        guard !availableDevices.isEmpty else { 
            print("🎯 No available devices")
            return nil 
        }
        let safeIndex = min(selectedDeviceIndex, availableDevices.count - 1)
        let device = availableDevices[safeIndex]
        print("🎯 Current device: \(device.name ?? "Unknown") at index \(safeIndex)")
        return device
    }
    
    private var currentDeviceData: BLEManager.DeviceData? {
        guard let currentDevice = currentDevice else { 
            print("🎯 No current device for data lookup")
            return nil 
        }
        let deviceData = bleManager.getDeviceData(for: currentDevice.identifier)
        if let data = deviceData {
            print("🎯 Device data found for \(currentDevice.name ?? "Unknown"): ranging=\(data.isRanging), distance=\(data.uwbLocation.distance)")
        } else {
            print("🎯 No device data found for \(currentDevice.name ?? "Unknown") (ID: \(currentDevice.identifier))")
        }
        return deviceData
    }
    
    private var isDeveloperModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: "isDeveloperModeEnabled")
    }
    
    private var calibratedRotationAngle: Double {
        rotationAngle + directionCalibrationOffset
    }
    
    // MARK: - Helper Methods
    private func startDeviceMonitoring() {
        // Real-time monitoring with very fast updates for responsive direction tracking
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            updateDeviceState()
            // Post notification for immediate UI updates
            NotificationCenter.default.post(name: NSNotification.Name("UWBLocationUpdated"), object: nil)
        }
        
        // Add periodic detailed debug info every 2 seconds
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.logDetailedDebugInfo()
        }
    }
    
    private func logDetailedDebugInfo() {
        print("\n=== 🔍 DETAILED DEBUG INFO ===")
        print("📊 Available devices: \(availableDevices.count)")
        print("📊 Connected devices: \(connectedDevices.count)")
        print("📊 Selected device index: \(selectedDeviceIndex)")
        print("📊 Developer mode: \(isDeveloperModeEnabled)")
        print("📊 Is connecting: \(isConnecting)")
        
        print("📊 Available devices list:")
        for (index, device) in availableDevices.enumerated() {
            let isSelected = index == selectedDeviceIndex
            let isConnected = connectedDevices.contains(device)
            print("   [\(index)] \(device.name ?? "Unknown") - Selected: \(isSelected), Connected: \(isConnected)")
            print("       ID: \(device.identifier)")
        }
        
        if let current = currentDevice {
            print("📊 Current device: \(current.name ?? "Unknown")")
            print("📊 Current device ID: \(current.identifier)")
            print("📊 Is current device connected: \(connectedDevices.contains(current))")
            
            if let data = bleManager.getDeviceData(for: current.identifier) {
                print("📊 Device data exists: YES")
                print("📊 Is ranging: \(data.isRanging)")
                print("📊 Distance: \(data.uwbLocation.distance)")
                print("📊 Location valid: \(data.uwbLocation.isValid)")
                print("📊 Direction: (\(data.uwbLocation.direction.x), \(data.uwbLocation.direction.y), \(data.uwbLocation.direction.z))")
            } else {
                print("📊 Device data exists: NO - DEVICE NOT CONNECTED TO BLE!")
                print("📊 ❌ This means Arduino UWB is discovered but not connected")
                print("📊 ❌ You need to TAP the Arduino UWB device to connect to it")
            }
        } else {
            print("📊 Current device: NONE")
        }
        
        print("📊 All connected devices:")
        if connectedDevices.isEmpty {
            print("   ❌ NO DEVICES CONNECTED - You need to tap a device to connect!")
        } else {
            for device in connectedDevices {
                print("   ✅ \(device.name ?? "Unknown"): \(device.identifier)")
            }
        }
        print("=== END DEBUG INFO ===\n")
    }
    
    private func saveCalibrationOffset() {
        UserDefaults.standard.set(directionCalibrationOffset, forKey: "directionCalibrationOffset")
    }
    
    private func loadCalibrationOffset() {
        directionCalibrationOffset = UserDefaults.standard.double(forKey: "directionCalibrationOffset")
    }
    
    private func setupLocationManager() {
        locationManager.delegate = LocationManagerDelegate.shared
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.headingFilter = 1.0
        
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
    }
    
    private func updateDeviceHeading(_ heading: CLHeading) {
        deviceHeading = heading.trueHeading
    }
    
    private func updateDeviceState() {
        let newAvailableDevices = availableDevices
        if connectedDevicesList.count != newAvailableDevices.count {
            connectedDevicesList = newAvailableDevices
            print("📊 Device list changed - Available: \(newAvailableDevices.count), Connected: \(connectedDevices.count)")
            // Don't reset selectedDeviceIndex to 0 - maintain current selection if valid
            if selectedDeviceIndex >= newAvailableDevices.count {
                selectedDeviceIndex = max(0, newAvailableDevices.count - 1)
            }
        }
        
        // Check if direction override is enabled
        let isDirectionOverrideEnabled = UserDefaults.standard.bool(forKey: "isDirectionOverrideEnabled")
        let forcedDirectionAngle = UserDefaults.standard.double(forKey: "forcedDirectionAngle")
        
        if let deviceData = currentDeviceData {
            print("📡 Current device data found - Device: \(currentDevice?.name ?? "Unknown")")
            print("📡 Is Ranging: \(deviceData.isRanging)")
            print("📡 Distance: \(deviceData.uwbLocation.distance)")
            print("📡 Is Valid: \(deviceData.uwbLocation.isValid)")
            
            if deviceData.isRanging {
                let direction = deviceData.uwbLocation.direction
                print("📡 Direction vector: x=\(direction.x), y=\(direction.y), z=\(direction.z)")
                
                // Use forced direction if override is enabled, otherwise calculate normally
                if isDirectionOverrideEnabled {
                    rotationAngle = forcedDirectionAngle
                    print("📡 Using forced direction: \(forcedDirectionAngle)")
                } else {
                    let azimuthValue = calculateAccurateAzimuth(direction)
                    print("📡 Calculated azimuth: \(azimuthValue)")
                    
                    if !azimuthValue.isNaN && !azimuthValue.isInfinite {
                        let azimuthDegrees: Double
                        if Settings().isDirectionEnable {
                            azimuthDegrees = 90.0 * Double(azimuthValue)
                        } else {
                            azimuthDegrees = Double(azimuthValue) * 180.0 / .pi
                        }
                        
                        let targetAngle = azimuthDegrees
                        let currentAngle = rotationAngle
                        let angleDifference = targetAngle - currentAngle
                        let normalizedDifference = atan2(sin(angleDifference * .pi / 180), cos(angleDifference * .pi / 180)) * 180 / .pi
                        
                        rotationAngle = currentAngle + (normalizedDifference * 0.8)
                        print("📡 Updated rotation angle: \(rotationAngle)")
                    }
                }
                
                // Calculate elevation using the same logic as Qorvo example
                let elevationValue = calculateElevation(direction)
                var calculatedElevation = Int(90 * Double(elevationValue))
                if !Settings().isDirectionEnable {
                    // Use verticalDirectionEstimate like Qorvo example\n                    calculatedElevation = deviceData.uwbLocation.verticalDirectionEstimate
                }
                elevation = calculatedElevation
                print("📡 Updated elevation: \(elevation)")
            } else {
                print("📡 Device not ranging - no UWB data")
            }
        } else {
            print("📡 No current device data available")
            print("📡 Current device: \(currentDevice?.name ?? "None")")
            print("📡 Selected device index: \(selectedDeviceIndex)")
            print("📡 Available devices: \(availableDevices.map { $0.name ?? "Unknown" })")
            rotationAngle = 0
            elevation = 0
        }
    }
    
    private func calculateAccurateAzimuth(_ direction: simd_float3) -> Float {
        if Settings().isDirectionEnable {
            return asin(direction.x)
        } else {
            return atan2(direction.x, direction.z)
        }
    }
    
    private func calculateElevation(_ direction: simd_float3) -> Float {
        return atan2(direction.z, direction.y) + .pi / 2
    }
    
    private func rad2deg(_ number: Double) -> Double {
        return number * 180 / .pi
    }
    
    // MARK: - Device Selection and Connection Management
    private func handleDeviceSelection(peripheral: CBPeripheral, index: Int) {
        // In developer mode, auto-connect when switching tabs
        if isDeveloperModeEnabled {
            print("📱 Developer Mode: Switching to device tab \(peripheral.name ?? "Unknown") (Index: \(index))")
            
            // Force disconnect all currently connected devices (BLE + UWB)
            if !connectedDevices.isEmpty {
                for connectedDevice in connectedDevices {
                    print("🔌 Developer Mode: Forcefully disconnecting \(connectedDevice.name ?? "Unknown") (ID: \(connectedDevice.identifier))")
                    bleManager.disconnect(peripheralID: connectedDevice.identifier)
                }
                
                // Additional safety: Force disconnectAll to ensure complete cleanup
                print("🔌 Developer Mode: Forcing complete disconnection of all devices")
                bleManager.disconnectAll()
            }
            
            // Switch to the selected device tab
            selectedDeviceIndex = index
            
            // Auto-connect to the new device after brief cleanup delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                print("🔗 Developer Mode: Auto-connecting to \(peripheral.name ?? "Unknown")")
                print("🔗 Device ID: \(peripheral.identifier)")
                print("🔗 Available devices count: \(self.availableDevices.count)")
                print("🔗 Connected devices count: \(self.connectedDevices.count)")
                
                self.isConnecting = true
                self.bleManager.connect(to: peripheral)
                
                // Reset connecting state after connection attempt
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.isConnecting = false
                    print("🔗 Connection attempt finished - isConnecting reset to false")
                    print("🔗 Connected devices after connection: \(self.connectedDevices.count)")
                    
                    // Log the successful switch and connection
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DeviceAutoConnectedInDeveloperMode"), 
                        object: nil, 
                        userInfo: [
                            "deviceName": peripheral.name ?? "Unknown",
                            "deviceID": peripheral.identifier.uuidString,
                            "tabIndex": index,
                            "connected": self.connectedDevices.contains(peripheral)
                        ]
                    )
                }
            }
            
        } else {
            // Original behavior: Check if device is already connected
            if connectedDevices.contains(peripheral) {
                // Just switch to this device without disconnecting
                selectedDeviceIndex = index
                return
            }
            
            // Set connecting state
            isConnecting = true
            
            // Connect to the new device while keeping existing connections
            bleManager.connect(to: peripheral)
            selectedDeviceIndex = index
            
            // Reset connecting state after connection attempt
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.isConnecting = false
            }
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
                        
                        if let deviceData = currentDeviceData {
                            let direction = deviceData.uwbLocation.direction
                            let distance = deviceData.uwbLocation.distance
                            
                            VStack(alignment: .leading, spacing: 8) {
                                debugRow("Device", currentDevice?.name ?? "Unknown")
                                debugRow("Status", deviceData.isRanging ? "Ranging" : "Connected")
                                debugRow("Distance", String(format: "%.4f m", distance))
                                debugRow("Direction X", String(format: "%.6f", direction.x))
                                debugRow("Direction Y", String(format: "%.6f", direction.y))
                                debugRow("Direction Z", String(format: "%.6f", direction.z))
                                debugRow("Raw Azimuth", String(format: "%.6f", calculateAccurateAzimuth(direction)))
                                debugRow("Scaled Azimuth", String(format: "%.2f°", rotationAngle))
                                debugRow("Elevation Raw", String(elevation))
                                debugRow("Direction Enabled", Settings().isDirectionEnable ? "YES" : "NO")
                                debugRow("Device ID", currentDevice?.identifier.uuidString ?? "Unknown")
                                debugRow("No Update Flag", deviceData.uwbLocation.noUpdate ? "YES" : "NO")
                                debugRow("Developer Mode", isDeveloperModeEnabled ? "ENABLED" : "DISABLED")
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

// MARK: - Modern UIKit-based Main View
struct ModernQorvoUIView: UIViewControllerRepresentable {
    let peripheral: CBPeripheral
    let deviceData: BLEManager.DeviceData?
    let selectedDeviceIndex: Int
    @Binding var rotationAngle: Double
    @Binding var elevation: Int
    @Binding var deviceHeading: Double
    @Binding var directionCalibrationOffset: Double
    @Binding var showCalibrationControls: Bool
    let onCompassTap: () -> Void
    let onCalibrationChanged: () -> Void
    
    func makeUIViewController(context: Context) -> ModernQorvoUIViewController {
        let controller = ModernQorvoUIViewController()
        controller.onCompassTap = onCompassTap
        controller.onCalibrationChanged = onCalibrationChanged
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ModernQorvoUIViewController, context: Context) {
        uiViewController.updateDevice(peripheral: peripheral, deviceData: deviceData, selectedDeviceIndex: selectedDeviceIndex)
        uiViewController.updateRotation(rotationAngle + directionCalibrationOffset)
        uiViewController.updateElevation(elevation)
        uiViewController.updateDeviceHeading(deviceHeading)
        uiViewController.updateCalibrationOffset(directionCalibrationOffset)
        uiViewController.showCalibrationControls = showCalibrationControls
    }
}

// MARK: - Modern UIKit View Controller
class ModernQorvoUIViewController: UIViewController {
    
    // MARK: - Properties
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var deviceNameLabel: UILabel!
    private var statusView: UIView!
    private var statusIndicator: UIView!
    private var statusLabel: UILabel!
    private var distanceContainerView: UIView!
    private var distanceValueLabel: UILabel!
    private var distanceUnitLabel: UILabel!
    private var proximityMessageLabel: UILabel!
    private var compassContainerView: UIView!
    private var compassBackgroundView: UIView!
    private var compassImageView: UIImageView!
    private var elevationContainerView: UIView!
    private var elevationLabel: UILabel!
    private var azimuthLabel: UILabel!
    private var calibrationContainerView: UIView!
    
    var onCompassTap: (() -> Void)?
    var onCalibrationChanged: (() -> Void)?
    var showCalibrationControls: Bool = false {
        didSet {
            updateCalibrationVisibility()
        }
    }
    
    private var currentDevice: CBPeripheral?
    private var isDeveloperModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: "isDeveloperModeEnabled")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.black
        
        // Scroll view for content
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        view.addSubview(scrollView)
        
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        setupDeviceHeader()
        setupDistanceDisplay()
        setupCompassView()
        setupElevationAndAzimuthView()
        setupCalibrationControls()
    }
    
    private func setupDeviceHeader() {
        // Device name
        deviceNameLabel = UILabel()
        deviceNameLabel.translatesAutoresizingMaskIntoConstraints = false
        deviceNameLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        deviceNameLabel.textColor = .white
        deviceNameLabel.textAlignment = .center
        deviceNameLabel.text = "Device Name"
        contentView.addSubview(deviceNameLabel)
        
        // Status container
        statusView = UIView()
        statusView.translatesAutoresizingMaskIntoConstraints = false
        statusView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        statusView.layer.cornerRadius = 12
        contentView.addSubview(statusView)
        
        // Status indicator
        statusIndicator = UIView()
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusIndicator.backgroundColor = .systemGreen
        statusIndicator.layer.cornerRadius = 3
        statusView.addSubview(statusIndicator)
        
        // Status label
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .systemGreen
        statusLabel.text = "Ranging"
        statusView.addSubview(statusLabel)
    }
    
    private func setupDistanceDisplay() {
        distanceContainerView = UIView()
        distanceContainerView.translatesAutoresizingMaskIntoConstraints = false
        distanceContainerView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        distanceContainerView.layer.cornerRadius = 16
        contentView.addSubview(distanceContainerView)
        
        let distanceTitleLabel = UILabel()
        distanceTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceTitleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        distanceTitleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        distanceTitleLabel.text = "DISTANCE"
        distanceTitleLabel.textAlignment = .center
        distanceContainerView.addSubview(distanceTitleLabel)
        
        distanceValueLabel = UILabel()
        distanceValueLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceValueLabel.font = UIFont.systemFont(ofSize: 42, weight: .bold)
        distanceValueLabel.textColor = getDeviceColor(for: 0) // Default to first device color
        distanceValueLabel.text = "0.00"
        distanceValueLabel.textAlignment = .center
        distanceContainerView.addSubview(distanceValueLabel)
        
        distanceUnitLabel = UILabel()
        distanceUnitLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceUnitLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        distanceUnitLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        distanceUnitLabel.text = "meters"
        distanceUnitLabel.textAlignment = .center
        distanceContainerView.addSubview(distanceUnitLabel)
        
        proximityMessageLabel = UILabel()
        proximityMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        proximityMessageLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        proximityMessageLabel.textColor = .systemGreen
        proximityMessageLabel.text = ""
        proximityMessageLabel.textAlignment = .center
        proximityMessageLabel.isHidden = true
        distanceContainerView.addSubview(proximityMessageLabel)
        
        // Distance constraints
        NSLayoutConstraint.activate([
            distanceTitleLabel.topAnchor.constraint(equalTo: distanceContainerView.topAnchor, constant: 16),
            distanceTitleLabel.centerXAnchor.constraint(equalTo: distanceContainerView.centerXAnchor),
            
            distanceValueLabel.topAnchor.constraint(equalTo: distanceTitleLabel.bottomAnchor, constant: 8),
            distanceValueLabel.centerXAnchor.constraint(equalTo: distanceContainerView.centerXAnchor),
            
            distanceUnitLabel.topAnchor.constraint(equalTo: distanceValueLabel.bottomAnchor, constant: 4),
            distanceUnitLabel.centerXAnchor.constraint(equalTo: distanceContainerView.centerXAnchor),
            
            proximityMessageLabel.topAnchor.constraint(equalTo: distanceUnitLabel.bottomAnchor, constant: 8),
            proximityMessageLabel.centerXAnchor.constraint(equalTo: distanceContainerView.centerXAnchor),
            proximityMessageLabel.bottomAnchor.constraint(equalTo: distanceContainerView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupCompassView() {
        compassContainerView = UIView()
        compassContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(compassContainerView)
        
        let directionTitleLabel = UILabel()
        directionTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        directionTitleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        directionTitleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        directionTitleLabel.text = "DIRECTION"
        directionTitleLabel.textAlignment = .center
        compassContainerView.addSubview(directionTitleLabel)
        
        // Compass background with cardinal directions
        compassBackgroundView = UIView()
        compassBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        compassBackgroundView.backgroundColor = .clear
        compassBackgroundView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        compassBackgroundView.layer.borderWidth = 2
        compassBackgroundView.layer.cornerRadius = 100
        compassContainerView.addSubview(compassBackgroundView)
        
        // Add cardinal direction labels
        addCardinalDirections()
        
        // Compass arrow using asset
        compassImageView = UIImageView()
        compassImageView.translatesAutoresizingMaskIntoConstraints = false
        compassImageView.image = UIImage(named: "compass")
        compassImageView.contentMode = .scaleAspectFit
        compassImageView.tintColor = .systemRed
        compassContainerView.addSubview(compassImageView)
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(compassTapped))
        compassImageView.addGestureRecognizer(tapGesture)
        compassImageView.isUserInteractionEnabled = true
        
        // Center dot
        let centerDot = UIView()
        centerDot.translatesAutoresizingMaskIntoConstraints = false
        centerDot.backgroundColor = .white
        centerDot.layer.cornerRadius = 4
        compassContainerView.addSubview(centerDot)
        
        // Compass constraints
        NSLayoutConstraint.activate([
            directionTitleLabel.topAnchor.constraint(equalTo: compassContainerView.topAnchor),
            directionTitleLabel.centerXAnchor.constraint(equalTo: compassContainerView.centerXAnchor),
            
            compassBackgroundView.topAnchor.constraint(equalTo: directionTitleLabel.bottomAnchor, constant: 16),
            compassBackgroundView.centerXAnchor.constraint(equalTo: compassContainerView.centerXAnchor),
            compassBackgroundView.widthAnchor.constraint(equalToConstant: 200),
            compassBackgroundView.heightAnchor.constraint(equalToConstant: 200),
            
            compassImageView.centerXAnchor.constraint(equalTo: compassBackgroundView.centerXAnchor),
            compassImageView.centerYAnchor.constraint(equalTo: compassBackgroundView.centerYAnchor),
            compassImageView.widthAnchor.constraint(equalToConstant: 120),
            compassImageView.heightAnchor.constraint(equalToConstant: 120),
            
            centerDot.centerXAnchor.constraint(equalTo: compassBackgroundView.centerXAnchor),
            centerDot.centerYAnchor.constraint(equalTo: compassBackgroundView.centerYAnchor),
            centerDot.widthAnchor.constraint(equalToConstant: 8),
            centerDot.heightAnchor.constraint(equalToConstant: 8),
            
            compassContainerView.bottomAnchor.constraint(equalTo: compassBackgroundView.bottomAnchor)
        ])
    }
    
    private func addCardinalDirections() {
        let directions = [
            ("N", 0, -90),
            ("E", 90, 0),
            ("S", 0, 90),
            ("W", -90, 0)
        ]
        
        for (text, xOffset, yOffset) in directions {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            label.textColor = UIColor.white.withAlphaComponent(0.8)
            label.text = text
            label.textAlignment = .center
            compassBackgroundView.addSubview(label)
            
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: compassBackgroundView.centerXAnchor, constant: CGFloat(xOffset)),
                label.centerYAnchor.constraint(equalTo: compassBackgroundView.centerYAnchor, constant: CGFloat(yOffset)),
                label.widthAnchor.constraint(equalToConstant: 20),
                label.heightAnchor.constraint(equalToConstant: 20)
            ])
        }
    }
    
    private func setupElevationAndAzimuthView() {
        elevationContainerView = UIView()
        elevationContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(elevationContainerView)
        
        // Elevation
        let (elevationStack, elevationValueLabel) = createInfoStack(title: "ELEVATION", value: "SAME LEVEL")
        elevationLabel = elevationValueLabel
        elevationContainerView.addSubview(elevationStack)
        
        // Azimuth
        let (azimuthStack, azimuthValueLabel) = createInfoStack(title: "AZIMUTH", value: "0.0°")
        azimuthLabel = azimuthValueLabel
        elevationContainerView.addSubview(azimuthStack)
        
        // Constraints
        NSLayoutConstraint.activate([
            elevationStack.leadingAnchor.constraint(equalTo: elevationContainerView.leadingAnchor),
            elevationStack.topAnchor.constraint(equalTo: elevationContainerView.topAnchor),
            elevationStack.trailingAnchor.constraint(equalTo: elevationContainerView.centerXAnchor, constant: -8),
            elevationStack.bottomAnchor.constraint(equalTo: elevationContainerView.bottomAnchor),
            
            azimuthStack.leadingAnchor.constraint(equalTo: elevationContainerView.centerXAnchor, constant: 8),
            azimuthStack.topAnchor.constraint(equalTo: elevationContainerView.topAnchor),
            azimuthStack.trailingAnchor.constraint(equalTo: elevationContainerView.trailingAnchor),
            azimuthStack.bottomAnchor.constraint(equalTo: elevationContainerView.bottomAnchor)
        ])
    }
    
    private func createInfoStack(title: String, value: String) -> (UIStackView, UILabel) {
        let titleLabel = UILabel()
        titleLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        titleLabel.text = title
        titleLabel.textAlignment = .center
        
        let valueLabel = UILabel()
        valueLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        valueLabel.textColor = .white
        valueLabel.text = value
        valueLabel.textAlignment = .center
        
        let container = UIView()
        container.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        container.layer.cornerRadius = 8
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        
        let finalStack = UIStackView(arrangedSubviews: [container])
        finalStack.translatesAutoresizingMaskIntoConstraints = false
        return (finalStack, valueLabel)
    }
    
    private func setupCalibrationControls() {
        calibrationContainerView = UIView()
        calibrationContainerView.translatesAutoresizingMaskIntoConstraints = false
        calibrationContainerView.backgroundColor = UIColor(red: 0.14, green: 0.13, blue: 0.16, alpha: 1.0) // #232229
        calibrationContainerView.layer.cornerRadius = 12
        calibrationContainerView.isHidden = true
        contentView.addSubview(calibrationContainerView)
        
        // Add calibration controls content here if needed
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        titleLabel.text = "CALIBRATION CONTROLS"
        titleLabel.textAlignment = .center
        calibrationContainerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: calibrationContainerView.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: calibrationContainerView.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: calibrationContainerView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Device header
            deviceNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            deviceNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            deviceNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            statusView.topAnchor.constraint(equalTo: deviceNameLabel.bottomAnchor, constant: 12),
            statusView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            statusView.heightAnchor.constraint(equalToConstant: 28),
            
            statusIndicator.leadingAnchor.constraint(equalTo: statusView.leadingAnchor, constant: 12),
            statusIndicator.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 6),
            statusIndicator.heightAnchor.constraint(equalToConstant: 6),
            
            statusLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 6),
            statusLabel.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: -12),
            
            // Distance
            distanceContainerView.topAnchor.constraint(equalTo: statusView.bottomAnchor, constant: 24),
            distanceContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            distanceContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Compass
            compassContainerView.topAnchor.constraint(equalTo: distanceContainerView.bottomAnchor, constant: 24),
            compassContainerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            // Elevation and Azimuth
            elevationContainerView.topAnchor.constraint(equalTo: compassContainerView.bottomAnchor, constant: 24),
            elevationContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            elevationContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Calibration
            calibrationContainerView.topAnchor.constraint(equalTo: elevationContainerView.bottomAnchor, constant: 24),
            calibrationContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            calibrationContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            calibrationContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }
    
    // MARK: - Update Methods
    func updateDevice(peripheral: CBPeripheral, deviceData: BLEManager.DeviceData?, selectedDeviceIndex: Int) {
        currentDevice = peripheral
        deviceNameLabel.text = peripheral.name ?? "Unknown Device"
        
        let isRanging = deviceData?.isRanging ?? false
        statusIndicator.backgroundColor = isRanging ? .systemGreen : .systemBlue
        statusLabel.textColor = isRanging ? .systemGreen : .systemBlue
        statusLabel.text = isRanging ? "Ranging" : "Connected"
        
        if let distance = deviceData?.uwbLocation.distance {
            updateDistanceDisplay(distance: distance)
            distanceValueLabel.textColor = getDeviceColor(for: selectedDeviceIndex)
        } else {
            distanceValueLabel.text = "--"
            distanceUnitLabel.text = "meters"
            distanceValueLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        }
    }
    
    func updateRotation(_ angle: Double) {
        UIView.animate(withDuration: 0.05, delay: 0, options: .curveEaseInOut, animations: {
            self.compassImageView.transform = CGAffineTransform(rotationAngle: CGFloat(angle * .pi / 180))
        }, completion: nil)
        
        azimuthLabel?.text = String(format: "%.1f°", angle)
    }
    
    func updateElevation(_ elevation: Int) {
        let elevationText = getElevationFromVerticalEstimate(elevation)
        let elevationColor = getElevationColor(elevation)
        
        elevationLabel?.text = elevationText
        elevationLabel?.textColor = elevationColor
    }
    
    func updateDeviceHeading(_ heading: Double) {
        // Apply true north alignment to compass background
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
            self.compassBackgroundView.transform = CGAffineTransform(rotationAngle: CGFloat(-heading * .pi / 180))
        }, completion: nil)
    }
    
    func updateCalibrationOffset(_ offset: Double) {
        // Update calibration display if needed
    }
    
    private func updateCalibrationVisibility() {
        calibrationContainerView.isHidden = !showCalibrationControls || !isDeveloperModeEnabled
    }
    
    // MARK: - Helper Methods
    private func getElevationText(_ elevation: Int) -> String {
        // For now, use the elevation parameter since we don't have direct access to deviceData here
        switch elevation {
        case 1: return "ABOVE"
        case -1: return "BELOW"
        case 0: return "SAME LEVEL"
        default: return "SAME LEVEL"
        }
    }
    
    private func calculateElevationAngle(_ direction: simd_float3) -> Float {
        let elevationRad = atan2(direction.y, sqrt(direction.x * direction.x + direction.z * direction.z))
        return elevationRad * 180 / .pi
    }
    
    private func getElevationFromVerticalEstimate(_ elevation: Int) -> String {
        // Use the shared getElevationFromInt function that supports force elevation
        return getElevationFromInt(elevation: elevation)
    }
    
    private func getElevationColor(_ elevation: Int) -> UIColor {
        // Check if force elevation mode is enabled
        let forcedElevationValue = UserDefaults.standard.string(forKey: "forcedElevationValue") ?? "DISABLED"
        
        if forcedElevationValue != "DISABLED" {
            // Use colors based on forced elevation value
            switch forcedElevationValue {
            case "ABOVE":
                return .systemOrange  // Above should be orange
            case "BELOW":
                return .systemBlue    // Below should be blue
            case "SAME LEVEL":
                return .systemGreen   // Same level should be green
            default:
                return .systemGreen
            }
        } else {
            // Original logic when not forced - corrected color mapping
            switch elevation {
            case NINearbyObject.VerticalDirectionEstimate.above.rawValue: return .systemOrange  // Above = orange
            case NINearbyObject.VerticalDirectionEstimate.below.rawValue: return .systemBlue   // Below = blue
            case NINearbyObject.VerticalDirectionEstimate.same.rawValue: return .systemGreen   // Same = green
            default: return .systemGreen
            }
        }
    }
    
    @objc private func compassTapped() {
        onCompassTap?()
    }
    
    // MARK: - Distance Display Helper
    private func updateDistanceDisplay(distance: Float) {
        // Check if distance override is enabled
        let isDistanceOverrideEnabled = UserDefaults.standard.bool(forKey: "isDistanceOverrideEnabled")
        let forcedDistanceString = UserDefaults.standard.string(forKey: "forcedDistanceValue") ?? ""
        
        var displayDistance: Float
        if isDistanceOverrideEnabled, let forcedDistance = Float(forcedDistanceString), !forcedDistanceString.isEmpty {
            displayDistance = forcedDistance
        } else {
            displayDistance = distance
            
            // Apply calibration offset if not using forced distance
            let calibrationOffset = UserDefaults.standard.double(forKey: "distanceCalibrationOffset")
            if calibrationOffset != 0 {
                // Convert calibration offset from centimeters to meters and apply
                let offsetInMeters = Float(calibrationOffset / 100.0)
                displayDistance += offsetInMeters
                
                // Ensure distance is never below 0
                if displayDistance < 0 {
                    displayDistance = 0
                }
            }
        }
        
        if displayDistance < 1.5 {
            // Show in centimeters for distances below 1.5 meters
            let centimeters = displayDistance * 100
            distanceValueLabel.text = String(format: "%.0f", centimeters)
            distanceUnitLabel.text = "centimeters"
            
            // Show proximity message
            proximityMessageLabel.text = "You are close to your friends!"
            proximityMessageLabel.isHidden = false
        } else {
            // Show in meters for distances 1.5 meters and above
            distanceValueLabel.text = String(format: "%.2f", displayDistance)
            distanceUnitLabel.text = "meters"
            
            // Hide proximity message
            proximityMessageLabel.isHidden = true
        }
    }
}

// MARK: - Supporting Views
struct NoDeviceConnectedView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "location.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .blue.opacity(0.3), radius: 12)
            
            VStack(spacing: 12) {
                Text("No Device Connected")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Connect a UWB device in Settings to start ranging")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Go to Settings") {
                selectedTab = 4
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            
            Spacer()
        }
        .padding()
    }
}

struct CompactDeviceSelectorView: View {
    let devices: [CBPeripheral]
    @Binding var selectedIndex: Int
    @EnvironmentObject var bleManager: BLEManager
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Devices (\(devices.count))")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(devices.enumerated()), id: \.element.identifier) { index, peripheral in
                        let deviceAction = { (peripheral: CBPeripheral, index: Int) in
                            selectedIndex = index
                        }
                        CompactDeviceCard(
                            peripheral: peripheral, 
                            index: index, 
                            isSelected: selectedIndex == index,
                            onDeviceSelection: deviceAction
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal, 16)
    }
}

struct AvailableDeviceSelectorView: View {
    let devices: [CBPeripheral]
    @Binding var selectedIndex: Int
    let connectedDevices: [CBPeripheral]
    let isConnecting: Bool
    let onDeviceSelection: (CBPeripheral, Int) -> Void
    @EnvironmentObject var bleManager: BLEManager
    
    var body: some View {
        VStack(spacing: 8) {
            Text("All Devices (\(devices.count))")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(devices.enumerated()), id: \.element.identifier) { index, peripheral in
                        AvailableDeviceCard(
                            peripheral: peripheral,
                            index: index,
                            isSelected: selectedIndex == index,
                            isConnected: connectedDevices.contains(peripheral),
                            isConnecting: isConnecting && selectedIndex == index,
                            onDeviceSelection: onDeviceSelection
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal, 16)
    }
}

struct AvailableDeviceCard: View {
    let peripheral: CBPeripheral
    let index: Int
    let isSelected: Bool
    let isConnected: Bool
    let isConnecting: Bool
    let onDeviceSelection: (CBPeripheral, Int) -> Void
    @EnvironmentObject var bleManager: BLEManager
    
    var body: some View {
        Button(action: { onDeviceSelection(peripheral, index) }) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    let deviceColor = getSwiftUIDeviceColor(for: index)
                    
                    ZStack {
                        Circle()
                            .fill(isConnected ? deviceColor : Color.gray.opacity(0.6))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: isConnected)
                        
                        // Add a ring around selected device
                        if isSelected {
                            Circle()
                                .stroke(deviceColor, lineWidth: 2)
                                .frame(width: 12, height: 12)
                        }
                    }
                    
                    Text(peripheral.name ?? "Unknown Device")
                        .font(.caption)
                        .fontWeight(isConnected ? .semibold : .medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                // Show connection status and ranging info
                if isConnecting {
                    HStack(spacing: 4) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.6)
                        Text("Connecting...")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                } else if isConnected {
                    if let deviceData = bleManager.getDeviceData(for: peripheral.identifier) {
                        let distance = deviceData.uwbLocation.distance
                        let deviceColor = getSwiftUIDeviceColor(for: index)
                        let isRanging = deviceData.isRanging
                        
                        VStack(spacing: 2) {
                            Text("\(String(format: "%.1f", distance))m")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(deviceColor)
                                .animation(.easeInOut(duration: 0.1), value: distance)
                            
                            Text(isRanging ? "Ranging" : "Connected")
                                .font(.caption2)
                                .foregroundColor(isRanging ? .green : .blue)
                        }
                    } else {
                        Text("Connected")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                } else {
                    Text("Tap to Connect")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? getSwiftUIDeviceColor(for: index).opacity(0.3) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? getSwiftUIDeviceColor(for: index).opacity(0.8) : (isConnected ? getSwiftUIDeviceColor(for: index).opacity(0.4) : Color.clear),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CompactDeviceCard: View {
    let peripheral: CBPeripheral
    let index: Int
    let isSelected: Bool
    let onDeviceSelection: (CBPeripheral, Int) -> Void
    @EnvironmentObject var bleManager: BLEManager
    
    var body: some View {
        Button(action: { onDeviceSelection(peripheral, index) }) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    let deviceData = bleManager.getDeviceData(for: peripheral.identifier)
                    let isRanging = deviceData?.isRanging ?? false
                    let deviceColor = getSwiftUIDeviceColor(for: index)
                    
                    Circle()
                        .fill(isRanging ? deviceColor : Color.gray)
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: isRanging) // Animate status changes
                    
                    Text(peripheral.name ?? "Unknown Device")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                if let deviceData = bleManager.getDeviceData(for: peripheral.identifier) {
                    let distance = deviceData.uwbLocation.distance
                    let deviceColor = getSwiftUIDeviceColor(for: index)
                    Text("\(String(format: "%.1f", distance))m")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(deviceColor)
                        .animation(.easeInOut(duration: 0.1), value: distance) // Smooth distance updates
                } else {
                    Text("...")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? getSwiftUIDeviceColor(for: index).opacity(0.3) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? getSwiftUIDeviceColor(for: index).opacity(0.6) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}


// MARK: - Location Manager Delegate
class LocationManagerDelegate: NSObject, CLLocationManagerDelegate, ObservableObject {
    static let shared = LocationManagerDelegate()
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        NotificationCenter.default.post(
            name: NSNotification.Name("DeviceHeadingUpdated"),
            object: nil,
            userInfo: ["heading": newHeading]
        )
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}
