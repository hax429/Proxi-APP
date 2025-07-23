//
//  SimulationManager.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/16/25.
//
//  Simulation Manager for Fake UWB Device Data
//  This file contains the simulation system for generating fake UWB data for testing.

import Foundation
import SwiftUI
import CoreBluetooth
import simd

/**
 * SimulationManager - Fake UWB Device Data Generator
 *
 * This class provides fake UWB device simulation for testing and development purposes.
 * It generates random distance, direction, and elevation data that mimics real UWB devices.
 *
 * ## Responsibilities:
 * - Generate fake UWB device data
 * - Simulate multiple connected devices
 * - Provide realistic random data updates
 * - Integrate with existing BLEManager structure
 *
 * ## Key Features:
 * - Random distance generation (0.5m to 15m)
 * - Realistic direction vector simulation
 * - Elevation angle simulation
 * - Multiple device support
 * - Configurable update frequency
 *
 * ## Usage:
 * ```swift
 * @StateObject var simulationManager = SimulationManager()
 * 
 * // Start simulation
 * simulationManager.startSimulation()
 * 
 * // Get fake device data
 * let deviceData = simulationManager.getDeviceData(for: deviceId)
 * ```
 *
 * @author Gabriel Wang
 * @version 1.0.0
 * @since iOS 16.0
 */

// MARK: - Fake Device Data Structure
struct FakeDeviceData {
    let id: UUID
    let name: String
    var distance: Float
    var direction: simd_float3
    var elevation: Float
    var lastUpdate: Date
    var isRanging: Bool
    var rssi: Int
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.distance = Float.random(in: 1.0 ... 10.0)
        self.direction = simd_float3(
            Float.random(in: -1.0 ... 1.0),
            Float.random(in: -0.5 ... 0.5),
            Float.random(in: -1.0 ... 1.0)
        )
        self.elevation = Float.random(in: -30 ... 30)
        self.lastUpdate = Date()
        self.isRanging = true
        self.rssi = Int.random(in: -60 ... -40)
    }
    
    mutating func updateRandomData() {
        // Update distance with some randomness
        let distanceChange = Float.random(in: -0.5 ... 0.5)
        self.distance = max(0.5, min(15.0, self.distance + distanceChange))
        
        // Update direction with slight changes
        self.direction = simd_float3(
            max(-1.0, min(1.0, self.direction.x + Float.random(in: -0.1 ... 0.1))),
            max(-0.5, min(0.5, self.direction.y + Float.random(in: -0.05 ... 0.05))),
            max(-1.0, min(1.0, self.direction.z + Float.random(in: -0.1 ... 0.1)))
        )
        
        // Update elevation with slight changes
        self.elevation = max(-45, min(45, self.elevation + Float.random(in: -5 ... 5)))
        
        // Update RSSI with slight changes
        self.rssi = max(-80, min(-20, self.rssi + Int.random(in: -5 ... 5)))
        
        self.lastUpdate = Date()
    }
}

// MARK: - Mock Peripheral Structure
struct MockPeripheral {
    let identifier: UUID
    let name: String?
    let state: CBPeripheralState
    
    init(name: String, id: UUID) {
        self.identifier = id
        self.name = name
        self.state = .connected
    }
}

// MARK: - Simulation Manager
class SimulationManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isSimulationEnabled = false
    @Published var fakeDevices: [UUID: FakeDeviceData] = [:]
    @Published var connectedDevicesCount: Int = 0
    
    // MARK: - Private Properties
    private var simulationTimer: Timer?
    private let updateInterval: TimeInterval = 0.5 // 500ms updates
    
    // MARK: - Initialization
    init() {
        print("🎭 SimulationManager initialized")
    }
    
    deinit {
        stopSimulation()
    }
    
    // MARK: - Public Methods
    func startSimulation() {
        guard !isSimulationEnabled else { return }
        
        isSimulationEnabled = true
        createFakeDevices()
        startSimulationTimer()
        
        connectedDevicesCount = fakeDevices.count
        
        print("🎭 Fake device simulation started with \(fakeDevices.count) devices")
    }
    
    func stopSimulation() {
        guard isSimulationEnabled else { return }
        
        isSimulationEnabled = false
        simulationTimer?.invalidate()
        simulationTimer = nil
        fakeDevices.removeAll()
        connectedDevicesCount = 0
        
        print("🎭 Fake device simulation stopped")
    }
    
    func getDeviceData(for deviceId: UUID) -> FakeDeviceData? {
        return fakeDevices[deviceId]
    }
    
    func getAllDeviceData() -> [UUID: FakeDeviceData] {
        return fakeDevices
    }
    
    func getDeviceIds() -> [UUID] {
        return Array(fakeDevices.keys)
    }
    
    func createMockPeripheral(name: String, id: UUID) -> MockPeripheral {
        return MockPeripheral(name: name, id: id)
    }
    
    // MARK: - Private Methods
    private func createFakeDevices() {
        let fakeDeviceNames = ["Fake Arduino 1", "Fake Arduino 2", "Fake Arduino 3"]
        
        for name in fakeDeviceNames {
            let fakeDevice = FakeDeviceData(name: name)
            fakeDevices[fakeDevice.id] = fakeDevice
            print("🎭 Created fake device: \(name) (ID: \(fakeDevice.id))")
        }
    }
    
    private func startSimulationTimer() {
        simulationTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            self.updateFakeDevices()
        }
    }
    
    private func updateFakeDevices() {
        for (deviceId, var fakeDevice) in fakeDevices {
            fakeDevice.updateRandomData()
            fakeDevices[deviceId] = fakeDevice
            
            // Log significant changes for debugging
            if fakeDevice.distance < 2.0 {
                print("🎭 [\(fakeDevice.name)] Close proximity: \(String(format: "%.2f", fakeDevice.distance))m")
            }
        }
    }
} 