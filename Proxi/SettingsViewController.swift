

import UIKit
import os
import NearbyInteraction

public struct Settings {
    var audioHapticEnabled: Bool?
    // Check if direction is enable (iPhone 14)
    let isDirectionEnable : Bool = NISession.deviceCapabilities.supportsDirectionMeasurement
    
    init() {
        audioHapticEnabled = false;
    }
}

extension UIImage {
    enum AssetIdentifier: String {
        case SwitchOn = "switch_on.svg"
        case SwitchOff = "switch_off.svg"
    }
    convenience init(assetIdentifier: AssetIdentifier) {
        self.init(named: assetIdentifier.rawValue)!
    }
}

public var appSettings: Settings = Settings.init()

// UIButton extension which enables the caller to duplicate a UIButton
extension UIStackView {
    func copyStackView() -> UIStackView? {
        
        // Attempt to duplicate button by archiving and unarchiving the original UIButton
        guard let archived = try? NSKeyedArchiver.archivedData(withRootObject: self,
                                                               requiringSecureCoding: false)
        else {
            fatalError("archivedData failed")
        }
        
        guard let copy = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(archived) as? UIStackView
        else {
            fatalError("unarchivedData failed")
        }
        
        return copy
    }
}

class SettingsViewController: UIViewController {
    
    @IBOutlet weak var enable3DArrow: UIButton!
    @IBOutlet weak var enableAudioHaptic: UIButton!
    @IBOutlet weak var accessorySample: UIStackView!
    @IBOutlet weak var accessoriesList: UIStackView!
    @IBOutlet weak var scanning: UIImageView!
    @IBOutlet weak var arrow3DLabel: UILabel!
    
    
    // Dictionary to co-relate BLE Device Unique ID with its UIStackViews hashValues
    var referenceDict = [Int:UIStackView]()
    
    let logger = os.Logger(subsystem: "com.qorvo.ni", category: "Settings")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // To update UI regarding NISession Device Direction Capabilities
        checkDirectionIsEnable()
        
        // Initialize switches        
        if appSettings.audioHapticEnabled! {
            enableAudioHaptic.setImage(UIImage(assetIdentifier: .SwitchOn), for: .normal)
        }
        else {
            enableAudioHaptic.setImage(UIImage(assetIdentifier: .SwitchOff), for: .normal)
        }
        
        updateDeviceList()
        
        // Start the Activity Indicator
        var imageArray = [UIImage]()
        let image = UIImage(named: "spinner.svg")!
        for i in 0...24 {
            imageArray.append(image.rotate(radians: Float(i) * .pi / 12)!)
        }
        scanning.animationImages = imageArray
        scanning.animationDuration = 1
        scanning.startAnimating()
        
        // Initialises the Timer used for update the device list
        _ = Timer.scheduledTimer(timeInterval: 0.5,
                                 target: self,
                                 selector: #selector(timerHandler),
                                 userInfo: nil,
                                 repeats: true)
    }
    
    func checkDirectionIsEnable(){
        // Direction capabilities check - now only affects UI elements, not 3D arrow
        if !appSettings.isDirectionEnable {
            // Disable 3D Arrow Label (even though we use 2D now)
            arrow3DLabel.isEnabled = false
            
            // Disable 3DArrow switch (even though we use 2D now)
            enable3DArrow.setImage(UIImage(assetIdentifier: .SwitchOff), for: .normal)
            enable3DArrow.isEnabled = false
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
            .lightContent
    }
    
    @IBAction func backToMain(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func toggle3DArrow(_ sender: Any) {
        // This button now does nothing since we only use 2D arrows
        // But we keep it for UI compatibility
    }
    
    @IBAction func toggleAudioHaptic(_ sender: Any) {
        if appSettings.audioHapticEnabled! {
            enableAudioHaptic.setImage(UIImage(assetIdentifier: .SwitchOff), for: .normal)
            appSettings.audioHapticEnabled = false
        }
        else {
            enableAudioHaptic.setImage(UIImage(assetIdentifier: .SwitchOn), for: .normal)
            appSettings.audioHapticEnabled = true
        }
    }
    
    @objc func timerHandler() {
        updateDeviceList()
    }
    
    func updateDeviceList() {
        var removeFromDict: Bool
        
        // Add new devices, if any
        qorvoDevices.forEach { (qorvoDevice) in
            // Check if the device is already included
            if referenceDict[(qorvoDevice?.bleUniqueID)!] == nil {
                // Create a new StackView and add it to the main StackView
                let newDevice: UIStackView = accessorySample.copyStackView()!
                
                if let device = newDevice.arrangedSubviews.first as? UILabel {
                    device.text = qorvoDevice?.blePeripheralName
                }
                if let status = newDevice.arrangedSubviews.last as? UILabel {
                    status.text = qorvoDevice?.blePeripheralStatus
                }
                
                accessoriesList.addArrangedSubview(newDevice)
                UIView.animate(withDuration: 0.2) {
                    newDevice.isHidden =  false
                }

                // Add the new entry to the dictionary
                referenceDict[(qorvoDevice?.bleUniqueID)!] = newDevice
            }
        }
        
        // Remove devices, if they are no longer included
        for (key, value) in referenceDict {
            removeFromDict = true

            qorvoDevices.forEach { (qorvoDevice) in
                if key == qorvoDevice?.bleUniqueID {
                    removeFromDict = false
                }
            }

            if removeFromDict {
                referenceDict.removeValue(forKey: key)
                value.removeFromSuperview()
            }
        }
    }
}
