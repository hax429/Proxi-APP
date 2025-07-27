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

// An example messaging protocol for communications between the app and the
// accessory. In your app, modify or extend this enumeration to your app's
// user experience and conform the accessory accordingly.
enum MessageId: UInt8 {
    // Messages from the accessory.
    case accessoryConfigurationData = 0x1
    case accessoryUwbDidStart = 0x2
    case accessoryUwbDidStop = 0x3
    
    // Messages to the accessory.
    case initialize = 0xA
    case configureAndStart = 0xB
    case stop = 0xC
    
    // User defined/notification messages
    case getReserved = 0x20
    case setReserved = 0x21

    case iOSNotify = 0x2F
}

protocol ArrowProtocol: AnyObject {
    func switch3DArrow()
}

protocol TableProtocol: AnyObject {
    func buttonSelect(_ sender: UIButton)
    func buttonAction(_ sender: UIButton)
    func sendStopToDevice(_ deviceID: Int)
}

class QorvoDemoViewController: UIViewController, ArrowProtocol, TableProtocol {
   
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
    
    var dataChannel = DataCommunicationChannel()
    var configuration: NINearbyAccessoryConfiguration?
    var selectedAccessory = -1
    var selectExpand = true
    var isConverged = false
    
    // Dictionary to associate each NI Session to the qorvoDevice using the uniqueID
    var referenceDict = [Int:NISession]()
    // A mapping from a discovery token to a name.
    var accessoryMap = [NIDiscoveryToken: String]()
    
    let logger = os.Logger(subsystem: "com.qorvo.ni", category: "QorvoDemoViewController")
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dataChannel.accessoryDataHandler = accessorySharedData
        
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
        
        // Prepare the data communication channel.
        dataChannel.accessorySynchHandler = accessorySynch
        dataChannel.accessoryConnectedHandler = accessoryConnected
        dataChannel.accessoryDisconnectedHandler = accessoryDisconnected
        dataChannel.accessoryDataHandler = accessorySharedData
        dataChannel.start()
        
        // Initialises the Timer used for Haptic and Sound feedbacks
        _ = Timer.scheduledTimer(timeInterval: 0.2,
                                 target: self,
                                 selector: #selector(feedbackHandler),
                                 userInfo: nil,
                                 repeats: true)
        
        // Add gesture recognition to "Devices near you" UIView
        let upSwipe   = UISwipeGestureRecognizer(target: self, action: #selector(swipeHandler))
        let downSwipe = UISwipeGestureRecognizer(target: self, action: #selector(swipeHandler))
        
        upSwipe.direction   = .up
        downSwipe.direction = .down
        
        separatorView.addGestureRecognizer(upSwipe)
        separatorView.addGestureRecognizer(downSwipe)
        
        switch3DArrow()
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
            destination.arrowDelegate = self
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
        if dataChannel.getDeviceFromUniqueID(sender.tag) != nil {
            let deviceID = sender.tag

            selectDevice(deviceID)
            logger.info("Select Button pressed for device \(deviceID)")
        }
    }
    
    @IBAction func buttonAction(_ sender: UIButton) {
        let deviceID = sender.tag
        
        if let qorvoDevice = dataChannel.getDeviceFromUniqueID(deviceID) {
            // Connect to the accessory
            if qorvoDevice.blePeripheralStatus == statusDiscovered {
                arrowView.infoLabelUpdate(with: "ConnectingAccessory".localized)
                connectToAccessory(deviceID)
            }
            else {
                return
            }
            
            // Edit cell for this sender
            accessoriesTable.setCellAsset(deviceID, .connecting)
            
            logger.info("Action Button pressed for device \(deviceID)")
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
        
        let qorvoDevice = dataChannel.getDeviceFromUniqueID(selectedAccessory)
        if qorvoDevice?.blePeripheralStatus != statusRanging {
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
        if let chosenDevice = dataChannel.getDeviceFromUniqueID(deviceID) {
            
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
    
    // MARK: - ArrowProtocol
    func switch3DArrow() {
        arrowView.switch3DArrow(appSettings.arrow3DEnabled!)
    }
    
    // MARK: - TableProtocol
    func sendStopToDevice(_ deviceID: Int) {
        let qorvoDevice = dataChannel.getDeviceFromUniqueID(deviceID)
        
        if qorvoDevice?.blePeripheralStatus != statusDiscovered {
            sendDataToAccessory(Data([MessageId.stop.rawValue]), deviceID)
        }
    }
    
    // MARK: - Data channel methods
    func accessorySharedData(data: Data, accessoryName: String, deviceID: Int) {
        // The accessory begins each message with an identifier byte.
        // Ensure the message length is within a valid range.
        if data.count < 1 {
            arrowView.infoLabelUpdate(with: "AccessoryData1".localized)
            return
        }
        
        // Assign the first byte which is the message identifier.
        guard let messageId = MessageId(rawValue: data.first!) else {
            fatalError("\(data.first!) is not a valid MessageId.")
        }
        
        // Handle the data portion of the message based on the message identifier.
        switch messageId {
        case .accessoryConfigurationData:
            // Access the message data by skipping the message identifier.
            assert(data.count > 1)
            let message = data.advanced(by: 1)
            setupAccessory(message, name: accessoryName, deviceID: deviceID)
        case .accessoryUwbDidStart:
            handleAccessoryUwbDidStart(deviceID)
        case .accessoryUwbDidStop:
            handleAccessoryUwbDidStop(deviceID)
        case .configureAndStart:
            fatalError("Accessory should not send 'configureAndStart'.")
        case .initialize:
            fatalError("Accessory should not send 'initialize'.")
        case .stop:
            fatalError("Accessory should not send 'stop'.")
        // User defined/notification messages
        case .getReserved:
            logger.debug("Get not implemented in this version")
        case .setReserved:
            logger.debug("Set not implemented in this version")
        case .iOSNotify:
            logger.debug("Notification not implemented in this version")
        }
    }
    
    func accessorySynch(_ index: Int,_ insert: Bool ) {
        accessoriesTable.handleCell(index, insert)
    }
    
    func accessoryUpdate() {
        // Update cells based on their status
        qorvoDevices.forEach { (qorvoDevice) in
            if qorvoDevice?.blePeripheralStatus == statusDiscovered {
                accessoriesTable.setCellAsset(qorvoDevice!.bleUniqueID,
                                              .actionButton)
            }
        }
    }
    
    func accessoryConnected(deviceID: Int) {
        // If no device is selected, select the new device
        if selectedAccessory == -1 {
            selectDevice(deviceID)
        }
        
        // Create a NISession for the new device
        referenceDict[deviceID] = NISession()
        referenceDict[deviceID]?.delegate = self
        referenceDict[deviceID]?.setARSession(worldView.session)
        
        // Also creates the AR object
        worldView.insertEntity(deviceID)
        
        arrowView.infoLabelUpdate(with: "RequestConfFromAccessory".localized)
        let msg = Data([MessageId.initialize.rawValue])
        
        sendDataToAccessory(msg, deviceID)
    }
    
    func accessoryDisconnected(deviceID: Int) {
        referenceDict[deviceID]?.invalidate()
        // Remove the NI Session and Location values related to the device ID
        referenceDict.removeValue(forKey: deviceID)
        
        // Remove entity and delete etityDict entry
        worldView.removeEntity(deviceID)
        
        if selectedAccessory == deviceID {
            selectDevice(-1)
        }
        
        accessoryUpdate()
        
        // Update device list and take other actions depending on the amount of devices
        let deviceCount = qorvoDevices.count
        
        if deviceCount == 0 {
            selectDevice(-1)
            
            arrowView.setScanning(true)
            arrowView.infoLabelUpdate(with: "AccessoryDisconnected".localized)
        }
    }
    
    // MARK: - Accessory messages handling
    func setupAccessory(_ configData: Data, name: String, deviceID: Int) {
        arrowView.infoLabelUpdate(with: "Received configuration data from '\(name)'. Running session.")
        do {
            configuration = try NINearbyAccessoryConfiguration(data: configData)
            configuration?.isCameraAssistanceEnabled = true
        }
        catch {
            // Stop and display the issue because the incoming data is invalid.
            // In your app, debug the accessory data to ensure an expected
            // format.
            arrowView.infoLabelUpdate(with: "Failed to create NINearbyAccessoryConfiguration for '\(name)'. Error: \(error)")
            return
        }
        
        // Cache the token to correlate updates with this accessory.
        cacheToken(configuration!.accessoryDiscoveryToken, accessoryName: name)
        
        referenceDict[deviceID]?.run(configuration!)
        arrowView.infoLabelUpdate(with: "SessionConfigured".localized)
    }
    
    func handleAccessoryUwbDidStart(_ deviceID: Int) {
        arrowView.infoLabelUpdate(with: "SessionStarted".localized)
        
        // Update the device Status
        if let startedDevice = dataChannel.getDeviceFromUniqueID(deviceID) {
            startedDevice.blePeripheralStatus = statusRanging
        }
        
        accessoriesTable.setCellAsset(deviceID, .miniLocation)
        
        // Enables Location assets when Qorvo device starts ranging
        // TODO: Check if this is still necessary
        enableLocation(true)
    }
    
    func handleAccessoryUwbDidStop(_ deviceID: Int) {
        arrowView.infoLabelUpdate(with: "SessionStopped".localized)
        
        // Disconnect from device
        disconnectFromAccessory(deviceID)
    }
    
    func clearLocationFields() {
        locationFields.clearFields()
        locationFields.disableFields(false)
    }
    
    func enableLocation(_ enable: Bool) {
        arrowView.enable3DArrow(enable, true)
    }
    
    func updateMiniFields(_ deviceID: Int) {
        
        let qorvoDevice = dataChannel.getDeviceFromUniqueID(deviceID)
        if qorvoDevice == nil { return }
        
        // Get updated location values
        let distance  = qorvoDevice?.uwbLocation?.distance
        let azimuthCheck = azimuth((qorvoDevice?.uwbLocation?.direction)!)
        
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
        accessoriesTable.updateCell(deviceID, distance!, azimuth)
    }
    
    func updateLocationFields(_ deviceID: Int) {
        if selectedAccessory == deviceID {
            let currentDevice = dataChannel.getDeviceFromUniqueID(deviceID)
            if  currentDevice == nil { return }
            
            // Get updated location values
            let distance  = currentDevice?.uwbLocation?.distance
            let direction = currentDevice?.uwbLocation?.direction
            
            let azimuthCheck = azimuth((currentDevice?.uwbLocation?.direction)!)
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

            var elevation = Int(90 * elevation(direction!))
            if !Settings().isDirectionEnable {
                elevation = currentDevice?.uwbLocation?.elevation ?? 0
            }
            
            // Update Location Fields
            locationFields.updateFields(newDistance: distance!, newDirection: direction!)
            locationFields.disableFields((currentDevice?.uwbLocation!.noUpdate)!)

            // Update 3D Arrow
            arrowView.setArrowAngle(newElevation: elevation,
                                    newAzimuth: azimuth)

            // Update Haptic Feedback
            feedback.setLevel(distance: distance!)
        }
    }
}

// MARK: - `NISessionDelegate`.
extension QorvoDemoViewController: NISessionDelegate {

    func session(_ session: NISession, didGenerateShareableConfigurationData shareableConfigurationData: Data, for object: NINearbyObject) {
        guard object.discoveryToken == configuration?.accessoryDiscoveryToken else { return }
        
        // Prepare to send a message to the accessory.
        var msg = Data([MessageId.configureAndStart.rawValue])
        msg.append(shareableConfigurationData)
        
        let str = msg.map { String(format: "0x%02x, ", $0) }.joined()
        logger.info("Sending shareable configuration bytes: \(str)")
        
        // Send the message to the correspondent accessory.
        sendDataToAccessory(msg, deviceIDFromSession(session))
        arrowView.infoLabelUpdate(with: "SentConfData".localized)
    }
    
    func session(_ session: NISession, didUpdateAlgorithmConvergence convergence: NIAlgorithmConvergence, for object: NINearbyObject?) {
        print("Convergence Status:\(convergence.status)")
        //TODO: To Refactor delete to only know converged or not
        
        guard object != nil else { return}
    
        switch convergence.status {
        case .converged:
            logger.info("Device Converged")
            arrowView.infoLabelUpdate(with: "Converged".localized)
            isConverged = true
        case .notConverged([NIAlgorithmConvergenceStatus.Reason.insufficientLighting]):
            arrowView.infoLabelUpdate(with: "LightError".localized)
            isConverged = false
        default:
            arrowView.infoLabelUpdate(with: "MovementNeeded".localized)
        }
    }
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let accessory = nearbyObjects.first else { return }
        guard let distance  = accessory.distance else { return }
        
        let deviceID = deviceIDFromSession(session)
        //logger.info(NISession.deviceCapabilities)
    
        if let updatedDevice = dataChannel.getDeviceFromUniqueID(deviceID) {
            // set updated values
            updatedDevice.uwbLocation?.distance = distance
    
            if let direction = accessory.direction {
                updatedDevice.uwbLocation?.direction = direction
                updatedDevice.uwbLocation?.noUpdate  = false
                
                // Update AR anchor
                if !worldView.isHidden {
                    guard let transform = session.worldTransform(for: accessory) else {return}
                    worldView.updateEntityPosition(deviceID, transform)
                }
            }
            //TODO: For IPhone 14 only
            else if isConverged {
                guard let horizontalAngle = accessory.horizontalAngle else {return}
                updatedDevice.uwbLocation?.direction = getDirectionFromHorizontalAngle(rad: horizontalAngle)
                updatedDevice.uwbLocation?.elevation = accessory.verticalDirectionEstimate.rawValue
                updatedDevice.uwbLocation?.noUpdate  = false
            }
            else {
                updatedDevice.uwbLocation?.noUpdate  = true
            }
    
            updatedDevice.blePeripheralStatus = statusRanging
        }
        
        updateLocationFields(deviceID)
        updateMiniFields(deviceID)
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        // Retry the session only if the peer timed out.
        guard reason == .timeout else { return }
        arrowView.infoLabelUpdate(with: "SessionTimeOut".localized)
        
        // The session runs with one accessory.
        guard let accessory = nearbyObjects.first else { return }
        
        // Clear the app's accessory state.
        accessoryMap.removeValue(forKey: accessory.discoveryToken)
        
        // Get the deviceID associated to the NISession
        let deviceID = deviceIDFromSession(session)
        
        // Consult helper function to decide whether or not to retry.
        if shouldRetry(deviceID) {
            sendDataToAccessory(Data([MessageId.stop.rawValue]), deviceID)
            sendDataToAccessory(Data([MessageId.initialize.rawValue]), deviceID)
        }
    }
    
    func sessionWasSuspended(_ session: NISession) {
        arrowView.infoLabelUpdate(with: "SessionSuspended".localized)
        let msg = Data([MessageId.stop.rawValue])
        
        sendDataToAccessory(msg, deviceIDFromSession(session))
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        arrowView.infoLabelUpdate(with: "SessionSuspendedEnded".localized)
        // When suspension ends, restart the configuration procedure with the accessory.
        let msg = Data([MessageId.initialize.rawValue])
        
        sendDataToAccessory(msg, deviceIDFromSession(session))
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        let deviceID = deviceIDFromSession(session)
        
        switch error {
        case NIError.invalidConfiguration:
            // Debug the accessory data to ensure an expected format.
            arrowView.infoLabelUpdate(with: "DataInvalid".localized)
        case NIError.userDidNotAllow:
            handleUserDidNotAllow()
        case NIError.invalidConfiguration:
            logger.error("Check the ARConfiguration used to run the ARSession")
        default:
            logger.error("invalidated: \(error)")
            handleSessionInvalidation(deviceID)
        }
    }
}

// MARK: - Helpers.
extension QorvoDemoViewController {
    
    func connectToAccessory(_ deviceID: Int) {
         do {
             try dataChannel.connectPeripheral(deviceID)
         } catch {
             arrowView.infoLabelUpdate(with: "Failed to connect to accessory: \(error)")
         }
    }
    
    func disconnectFromAccessory(_ deviceID: Int) {
         do {
             try dataChannel.disconnectPeripheral(deviceID)
         } catch {
             arrowView.infoLabelUpdate(with: "Failed to disconnect from accessory: \(error)")
         }
     }
    
    func sendDataToAccessory(_ data: Data,_ deviceID: Int) {
         do {
             try dataChannel.sendData(data, deviceID)
         } catch {
             arrowView.infoLabelUpdate(with: "Failed to send data to accessory: \(error)")
         }
     }
    
    func handleSessionInvalidation(_ deviceID: Int) {
        arrowView.infoLabelUpdate(with: "SessionInvalidated".localized)
        // Ask the accessory to stop.
        sendDataToAccessory(Data([MessageId.stop.rawValue]), deviceID)

        // Replace the invalidated session with a new one.
        referenceDict[deviceID] = NISession()
        referenceDict[deviceID]?.delegate = self

        // Ask the accessory to stop.
        sendDataToAccessory(Data([MessageId.initialize.rawValue]), deviceID)
    }
    
    func shouldRetry(_ deviceID: Int) -> Bool {
        // Need to use the dictionary here, to know which device failed and check its connection state
        let qorvoDevice = dataChannel.getDeviceFromUniqueID(deviceID)
        
        if qorvoDevice?.blePeripheralStatus != statusDiscovered {
            return true
        }
        
        return false
    }
    
    func deviceIDFromSession(_ session: NISession)-> Int {
        var deviceID = -1
        
        for (key, value) in referenceDict {
            if value == session {
                deviceID = key
            }
        }
        
        return deviceID
    }
    
    func cacheToken(_ token: NIDiscoveryToken, accessoryName: String) {
        accessoryMap[token] = accessoryName
    }
    
    func handleUserDidNotAllow() {
        // Beginning in iOS 15, persistent access state in Settings.
        arrowView.infoLabelUpdate(with: "NIAccessRequired".localized)
        
        // Create an alert to request the user go to Settings.
        let accessAlert = UIAlertController(title: "AccessRequired".localized,
                                            message: "NIAccessRequired.message".localized,
                                            preferredStyle: .alert)
        accessAlert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))
        accessAlert.addAction(UIAlertAction(title: "GoSettings".localized, style: .default, handler: {_ in
            // Navigate the user to the app's settings.
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        }))

        // Preset the access alert.
        present(accessAlert, animated: true, completion: nil)
    }
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
