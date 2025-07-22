
import Foundation
import UIKit

class DeviceView: UIView {
    // Info fields
    let titleText: UITextField
    let deviceName: UITextField
    // Stack View to organise
    let verticalStackView: UIStackView
    
    init() {
        // Initializing subviews
        titleText = UITextField(frame: .zero)
        titleText.translatesAutoresizingMaskIntoConstraints = false
        titleText.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        titleText.contentVerticalAlignment = .bottom
        titleText.textAlignment = .center
        titleText.textColor = .qorvoGray50
        titleText.text = "SelectedAccessory".localized
        
        deviceName = UITextField(frame: .zero)
        deviceName.translatesAutoresizingMaskIntoConstraints = false
        deviceName.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        deviceName.contentVerticalAlignment = .center
        deviceName.textAlignment = .center
        deviceName.textColor = .black
        deviceName.text = "NotConnected".localized.uppercased()
        
        verticalStackView = UIStackView(arrangedSubviews: [titleText, deviceName])
        verticalStackView.translatesAutoresizingMaskIntoConstraints = false
        verticalStackView.axis = .vertical
        verticalStackView.distribution = .equalSpacing
        verticalStackView.spacing = 0
        
        super.init(frame: .zero)
        
        // Add the stack view to the superview
        addSubview(verticalStackView)
        
        // Set up the stack view's constraints
        NSLayoutConstraint.activate([
            titleText.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleText.heightAnchor.constraint(equalToConstant: DesignConstraints.DEVICE_VIEW_HEIGHT_CONSTRAINT),
            
            deviceName.centerXAnchor.constraint(equalTo: centerXAnchor),
            deviceName.heightAnchor.constraint(equalToConstant: DesignConstraints.DEVICE_VIEW_HEIGHT_CONSTRAINT),
            
            verticalStackView.topAnchor.constraint(equalTo: topAnchor),
            verticalStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            verticalStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            verticalStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        backgroundColor = .white
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setDeviceName(_ newDeviceName: String) {
        deviceName.text = newDeviceName
    }
}
