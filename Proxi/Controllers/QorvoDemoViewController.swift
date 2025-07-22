/*
 * @file      QorvoDemoViewController.swift
 *
 * @brief     Main Application View Controller.
 *
 * @author    Decawave Applications
 *
 * @attention Copyright (c) 2021 - 2022, Qorvo US, Inc.
 * All rights reserved
 * Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 * 1. Redistributions of source code must retain the above copyright notice, this
 *  list of conditions, and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *  this list of conditions and the following disclaimer in the documentation
 *  and/or other materials provided with the distribution.
 * 3. You may only use this software, with or without any modification, with an
 *  integrated circuit developed by Qorvo US, Inc. or any of its affiliates
 *  (collectively, "Qorvo"), or any module that contains such integrated circuit.
 * 4. You may not reverse engineer, disassemble, decompile, decode, adapt, or
 *  otherwise attempt to derive or gain access to the source code to any software
 *  distributed under this license in binary or object code form, in whole or in
 *  part.
 * 5. You may not use any Qorvo name, trademarks, service marks, trade dress,
 *  logos, trade names, or other symbols or insignia identifying the source of
 *  Qorvo's products or services, or the names of any of Qorvo's developers to
 *  endorse or promote products derived from this software without specific prior
 *  written permission from Qorvo US, Inc. You must not call products derived from
 *  this software "Qorvo", you must not have "Qorvo" appear in their name, without
 *  the prior permission from Qorvo US, Inc.
 * 6. Qorvo may publish revised or new version of this license from time to time.
 *  No one other than Qorvo US, Inc. has the right to modify the terms applicable
 *  to the software provided under this license.
 * THIS SOFTWARE IS PROVIDED BY QORVO US, INC. "AS IS" AND ANY EXPRESS OR IMPLIED
 *  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. NEITHER
 *  QORVO, NOR ANY PERSON ASSOCIATED WITH QORVO MAKES ANY WARRANTY OR
 *  REPRESENTATION WITH RESPECT TO THE COMPLETENESS, SECURITY, RELIABILITY, OR
 *  ACCURACY OF THE SOFTWARE, THAT IT IS ERROR FREE OR THAT ANY DEFECTS WILL BE
 *  CORRECTED, OR THAT THE SOFTWARE WILL OTHERWISE MEET YOUR NEEDS OR EXPECTATIONS.
 * IN NO EVENT SHALL QORVO OR ANYBODY ASSOCIATED WITH QORVO BE LIABLE FOR ANY
 *  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 *  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 *  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 *  ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 *
 */

import UIKit
import NearbyInteraction
import os.log



protocol TableProtocol: AnyObject {
    func buttonSelect(_ sender: UIButton)
    func buttonAction(_ sender: UIButton)
    func sendStopToDevice(_ deviceID: Int)
}

class QorvoDemoViewController: UIViewController, TableProtocol {
    public var bleManager: BLEManager?
   
    @IBOutlet weak var mainStackView: UIStackView!
    @IBOutlet weak var arButton: UIButton!
    
    // All info Views
    let worldView = WorldView(frame: .zero)
    let deviceView = DeviceView()
    let locationFields = LocationFields()
    let arrowView = ArrowView()
    let separatorView = SeparatorView(fieldTitle: "Devices near you")
    let accessoriesTable = AccessoriesTable()
    
    let feedback = Feedback()
    
    var selectedAccessory = -1
    var selectExpand = true
    
    // Device list for UIKit compatibility
    var qorvoDevices: [qorvoDevice?] = []
    
    let logger = os.Logger(subsystem: "com.qorvo.ni", category: "QorvoDemoViewController")
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Ensure mainStackView is initialized if not loaded from storyboard
        if mainStackView == nil {
            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 0
            stack.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
            ])
            mainStackView = stack
        }
        
        // Insert GUI assets to the Main Stack View
        mainStackView.insertArrangedSubview(worldView, at: 0)
        mainStackView.insertArrangedSubview(deviceView, at: 1)
        mainStackView.insertArrangedSubview(locationFields, at: 2)
        mainStackView.insertArrangedSubview(arrowView, at: 3)
        mainStackView.insertArrangedSubview(separatorView, at: 4)
        mainStackView.insertArrangedSubview(accessoriesTable, at: 5)
        mainStackView.overrideUserInterfaceStyle = .light
        
        // To update UI regarding NISession Device Direction Capabilities
        checkDirectionIsEnable()
        
        // Set delegate to allow "accessoriesTable" to use TableProtocol
        accessoriesTable.tableDelegate = self
        
        // Initialises the Timer used for Haptic and Sound feedbacks
        _ = Timer.scheduledTimer(timeInterval: 0.2,
                                 target: self,
                                 selector: #selector(feedbackHandler),
                                 userInfo: nil,
                                 repeats: true)
        
        // Timer to monitor device state changes from SettingsView
        _ = Timer.scheduledTimer(timeInterval: 0.5,
                                 target: self,
                                 selector: #selector(updateDeviceState),
                                 userInfo: nil,
                                 repeats: true)
        
        // Add gesture recognition to "Devices near you" UIView
        let upSwipe   = UISwipeGestureRecognizer(target: self, action: #selector(swipeHandler))
        let downSwipe = UISwipeGestureRecognizer(target: self, action: #selector(swipeHandler))
        
        upSwipe.direction   = .up
        downSwipe.direction = .down
        
        separatorView.addGestureRecognizer(upSwipe)
        separatorView.addGestureRecognizer(downSwipe)
        
    }
    
    func checkDirectionIsEnable(){
        // if NISession device direction capabilities is disabled
        if !appSettings.isDirectionEnable {
            // Hide the ArButton
            arButton.isHidden = true
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
            .lightContent
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? SettingsViewController {
            // Settings configuration if needed
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        hideDetails(true)
    }
    
    @objc func swipeHandler(_ gestureRecognizer : UISwipeGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            if gestureRecognizer.direction == .up {
                hideDetails(true)
            }
            if gestureRecognizer.direction == .down {
                hideDetails(false)
            }
        }
    }
    
    func hideDetails(_ hide: Bool) {
        if worldView.isHidden {
            if qorvoDevices.count > 1 {
                UIView.animate(withDuration: 0.4) {
                    self.locationFields.isHidden = hide
                }
            }
        }
        else {
            UIView.animate(withDuration: 0.4) {
                self.accessoriesTable.isHidden = !hide
            }
        }
    }
    
    @IBAction func SwitchAR(_ sender: Any) {
        if worldView.isHidden {
            UIView.animate(withDuration: 0.4) {
                self.worldView.isHidden = false
                
                self.deviceView.isHidden = true
                self.locationFields.isHidden = true
                self.arrowView.isHidden = true
                
                self.accessoriesTable.isHidden = true
            }
        }
        else {
            UIView.animate(withDuration: 0.4) {
                self.worldView.isHidden = true
                
                self.deviceView.isHidden = false
                self.locationFields.isHidden = false
                self.arrowView.isHidden = false
                
                self.accessoriesTable.isHidden = false
            }
        }
    }
    
    @IBAction func buttonSelect(_ sender: UIButton) {
        let deviceID = sender.tag
        
        // Check if device exists in global qorvoDevices array
        if qorvoDevices.compactMap({ $0 }).first(where: { $0.bleUniqueID == deviceID }) != nil {
            selectDevice(deviceID)
            logger.info("Select Button pressed for device \(deviceID)")
        }
    }
    
    @IBAction func buttonAction(_ sender: UIButton) {
        // All device connection is now handled in Settings
        // Show message directing user to Settings
        arrowView.infoLabelUpdate(with: "Use Settings tab to connect to devices")
    }
    
    @objc func updateDeviceState() {
        // Monitor global qorvoDevices array for changes and update UI accordingly
        let connectedDevices = qorvoDevices.compactMap { $0 }.filter { device in
            device.blePeripheralStatus == statusConnected || device.blePeripheralStatus == statusRanging
        }
        
        // Update info label based on device state
        if connectedDevices.isEmpty {
            arrowView.infoLabelUpdate(with: "Use Settings to connect to devices")
        } else {
            let rangingDevices = connectedDevices.filter { $0.blePeripheralStatus == statusRanging }
            if !rangingDevices.isEmpty {
                arrowView.infoLabelUpdate(with: "Device ranging - move around for direction")
            } else {
                arrowView.infoLabelUpdate(with: "Device connected - initializing ranging...")
            }
        }
        
        // If we have connected devices but no selected device, auto-select the first one
        if selectedAccessory == -1 && !connectedDevices.isEmpty {
            let firstConnectedDevice = connectedDevices.first!
            selectDevice(firstConnectedDevice.bleUniqueID)
            logger.info("Auto-selected device \(firstConnectedDevice.bleUniqueID) connected via Settings")
        }
        
        // If selected device is no longer connected, clear selection
        if selectedAccessory != -1 {
            let selectedDeviceStillConnected = connectedDevices.contains { $0.bleUniqueID == self.selectedAccessory }
            if !selectedDeviceStillConnected {
                selectDevice(-1) // Clear selection
                logger.info("Cleared selection - device \(self.selectedAccessory) disconnected")
            }
        }
        
        // Update UI for all connected devices
        for device in connectedDevices {
            updateLocationFields(device.bleUniqueID)
            updateMiniFields(device.bleUniqueID)
        }
        
        // Refresh the accessories table to reflect current device state
        DispatchQueue.main.async {
            self.accessoriesTable.reloadData()
        }
    }
    
    @objc func feedbackHandler() {
        // Sequence of checks before set Haptics
        if (!appSettings.audioHapticEnabled!) {
            return
        }
        
        if selectedAccessory == -1 {
            return
        }
        
        // Get device from global qorvoDevices array
        guard let qorvoDevice = qorvoDevices.compactMap({ $0 }).first(where: { $0.bleUniqueID == selectedAccessory }) else {
            return
        }
        if qorvoDevice.blePeripheralStatus != statusRanging {
            return
        }
        
        feedback.update()
    }
    
    func selectDevice(_ deviceID: Int) {
        // If an accessory was selected, clear highlight
        if selectedAccessory != -1 {
            accessoriesTable.setCellColor(selectedAccessory, .white)
        }
        
        // Set the new selected accessory
        selectedAccessory = deviceID
        
        // If no accessory is selected, reset location fields
        if deviceID == -1 {
            clearLocationFields()
            enableLocation(false)
            deviceView.setDeviceName("NotConnected".localized)
            
            return
        }
    
        // If a new accessory is selected initialise location
        if let chosenDevice = qorvoDevices.compactMap({ $0 }).first(where: { $0.bleUniqueID == deviceID }) {
            
            accessoriesTable.setCellColor(deviceID, .qorvoGray02)
            
            logger.info("Selecting device \(deviceID)")
            deviceView.setDeviceName(chosenDevice.blePeripheralName)
            
            if chosenDevice.blePeripheralStatus == statusDiscovered {
                // Clear location values
                clearLocationFields()
                // Disables Location assets when Qorvo device is not ranging
                enableLocation(false)
            }
            else {
                // Update location values
                updateLocationFields(deviceID)
                // Enables Location assets when Qorvo device is ranging
                enableLocation(true)
                // Show location fields
                hideDetails(false)
            }
        }
    }
    
    
    // MARK: - TableProtocol
    func sendStopToDevice(_ deviceID: Int) {
        logger.info("Stop device request for \(deviceID) - redirecting to Settings")
        arrowView.infoLabelUpdate(with: "Use Settings to disconnect devices")
    }
    
    // MARK: - Display and UI Update Methods (Data now comes from Settings)
    
    func clearLocationFields() {
        locationFields.clearFields()
        locationFields.disableFields(false)
    }
    
    func enableLocation(_ enable: Bool) {
        arrowView.enable2DArrow(enable, true)
    }
    
    func updateMiniFields(_ deviceID: Int) {
        
        guard let qorvoDevice = qorvoDevices.compactMap({ $0 }).first(where: { $0.bleUniqueID == deviceID }) else { return }
        
        // Get updated location values
        guard let distance = qorvoDevice.uwbLocation?.distance,
              let direction = qorvoDevice.uwbLocation?.direction else { return }
        
        let azimuthCheck = azimuth(direction)
        
        // Check if azimuth check calcul is a number (ie: not infinite)
        if azimuthCheck.isNaN {
            return
        }
        
        var azimuth = 0
        if Settings().isDirectionEnable {
            azimuth =  Int( 90 * (Double(azimuthCheck)))
        }
        else {
            azimuth = Int(rad2deg(Double(azimuthCheck)))
        }

        // Update the "accessoriesTable" cell with the given values
        accessoriesTable.updateCell(deviceID, distance, azimuth)
    }
    
    func updateLocationFields(_ deviceID: Int) {
        if selectedAccessory == deviceID {
            guard let currentDevice = qorvoDevices.compactMap({ $0 }).first(where: { $0.bleUniqueID == deviceID }) else { return }
            
            // Get updated location values
            guard let distance = currentDevice.uwbLocation?.distance,
                  let direction = currentDevice.uwbLocation?.direction else { return }
            
            let azimuthCheck = azimuth(direction)
            // Check if azimuth check calcul is a number (ie: not infinite)
            if azimuthCheck.isNaN {
                return
            }
            
            var azimuth = 0
            if Settings().isDirectionEnable {
                azimuth =  Int(90 * (Double(azimuthCheck)))
            }
            else {
                azimuth = Int(rad2deg(Double(azimuthCheck)))
            }

            var elevation = Int(90 * elevation(direction))
            if !Settings().isDirectionEnable {
                elevation = currentDevice.uwbLocation?.elevation ?? 0
            }
            
            // Update Location Fields
            locationFields.updateFields(newDistance: distance, newDirection: direction)
            locationFields.disableFields(currentDevice.uwbLocation?.noUpdate ?? false)

            // Update 2D Arrow (updated to use new 2D arrow)
            arrowView.setArrowAngle(newElevation: elevation,
                                    newAzimuth: azimuth)

            // Update Haptic Feedback
            feedback.setLevel(distance: distance)
        }
    }
}

// MARK: - NISessionDelegate (removed - now handled in Settings)
// Connection and UWB session handling has been moved to SettingsView

// MARK: - Helpers (Connection helpers removed - now in Settings)
extension QorvoDemoViewController {
    // Connection methods are now handled in SettingsView
}

// MARK: - Utils.
// Provides the azimuth from an argument 3D directional.
func azimuth(_ direction: simd_float3) -> Float {
    if Settings().isDirectionEnable {
        return asin(direction.x)
    }
    else {
        return atan2(direction.x, direction.z)
    }
}

// Provides the elevation from the argument 3D directional.
func elevation(_ direction: simd_float3) -> Float {
    return atan2(direction.z, direction.y) + .pi / 2
}

//TODO: Refactor
func rad2deg(_ number: Double) -> Double {
    return number * 180 / .pi
}

func getDirectionFromHorizontalAngle(rad: Float) -> simd_float3 {
    print("Horizontal Angle in deg = \(rad2deg(Double(rad)))")
    return simd_float3(x: sin(rad), y: 0, z: cos(rad))
}

func getElevationFromInt(elevation: Int?) -> String {
    guard elevation != nil else {
        return "unknown".localizedUppercase
    }
    // TODO: Use Localizable String
    switch elevation  {
    case NINearbyObject.VerticalDirectionEstimate.above.rawValue:
        return "above".localizedUppercase
    case NINearbyObject.VerticalDirectionEstimate.below.rawValue:
        return "below".localizedUppercase
    case NINearbyObject.VerticalDirectionEstimate.same.rawValue:
        return "same".localizedUppercase
    case NINearbyObject.VerticalDirectionEstimate.aboveOrBelow.rawValue, NINearbyObject.VerticalDirectionEstimate.unknown.rawValue:
        return "unknown".localizedUppercase
    default:
        return "unknown".localizedUppercase
    }
}

extension String {
    var localized: String {
        return NSLocalizedString(self, tableName: nil, bundle: Bundle.main, value: "", comment: "")
    }
    var localizedUppercase: String {
        return NSLocalizedString(self, tableName: nil, bundle: Bundle.main, value: "", comment: "").uppercased()
    }
}
