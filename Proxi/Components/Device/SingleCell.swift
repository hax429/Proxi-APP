

import UIKit

enum asset: String {
    // Index for each label.
    case actionButton = "Button to Connect"
    case connecting   = "Animated Icon"
    case miniLocation = "Panel with TWR info"
}

class SingleCell: UITableViewCell {
    
    let accessoryButton: UIButton
    let miniLocation: UIView
    let actionButton: UIButton
    let connecting: UIImageView
    let bottomBar: UIImageView
    
    let azimuthLabel: UITextField
    let miniArrow: UIImageView
    let pipe: UIImageView
    let distanceLabel: UITextField
    
    // Used to animate scanning images
    var imageLoading = [UIImage]()
    var uniqueID: Int = 0
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        
        accessoryButton = UIButton()
        accessoryButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        accessoryButton.setTitleColor(.black, for: .normal)
        accessoryButton.contentHorizontalAlignment = .left
        accessoryButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        //accessoryButton.configuration?.titlePadding = 20
        accessoryButton.translatesAutoresizingMaskIntoConstraints = false
        
        miniLocation = UIView()
        miniLocation.translatesAutoresizingMaskIntoConstraints = false
        
        azimuthLabel = UITextField(frame: .zero)
        azimuthLabel.translatesAutoresizingMaskIntoConstraints = false
        azimuthLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        azimuthLabel.textAlignment = .right
        azimuthLabel.textColor = .black
        azimuthLabel.text = "StartDegrees".localized
        
        miniArrow = UIImageView(image: UIImage(named: "arrow_small"))
        miniArrow.translatesAutoresizingMaskIntoConstraints = false
        
        pipe = UIImageView(image: UIImage(named: "subheading"))
        pipe.contentMode = .scaleAspectFit
        pipe.translatesAutoresizingMaskIntoConstraints = false
        
        distanceLabel = UITextField(frame: .zero)
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        distanceLabel.textAlignment = .right
        distanceLabel.textColor = .black
        distanceLabel.text = "StartMeters".localized
        
        actionButton = UIButton()
        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        actionButton.setTitleColor(.qorvoBlue, for: .normal)
        actionButton.setTitle("Connect".localized, for: .normal)
        actionButton.contentHorizontalAlignment = .right
        actionButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 20)
        //actionButton.configuration?.titlePadding = 20
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        
        connecting = UIImageView()
        connecting.contentMode = .scaleAspectFit
        connecting.translatesAutoresizingMaskIntoConstraints = false
        
        bottomBar = UIImageView(image: UIImage(named: "bar"))
        bottomBar.contentMode = .scaleAspectFit
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        
        miniLocation.addSubview(distanceLabel)
        miniLocation.addSubview(pipe)
        miniLocation.addSubview(miniArrow)
        miniLocation.addSubview(azimuthLabel)
        
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.backgroundColor = .white
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(accessoryButton)
        contentView.addSubview(miniLocation)
        contentView.addSubview(actionButton)
        contentView.addSubview(connecting)
        contentView.addSubview(bottomBar)
        
        // Start the Activity Indicators
        let imageSmall = UIImage(named: "spinner_small")!
        for i in 0...24 {
            imageLoading.append(imageSmall.rotate(radians: Float(i) * .pi / 12)!)
        }
        connecting.animationImages = imageLoading
        connecting.animationDuration = 1
        
        // Set up the stack view's constraints
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            accessoryButton.topAnchor.constraint(equalTo: topAnchor),
            accessoryButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            accessoryButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            accessoryButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            actionButton.topAnchor.constraint(equalTo: topAnchor),
            actionButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: DesignConstraints.ACTION_BUTTON_WIDTH_CONSTRAINT),
            
            connecting.heightAnchor.constraint(equalToConstant: DesignConstraints.CONNECTING_SIDE_CONSTRAINT),
            connecting.widthAnchor.constraint(equalToConstant: DesignConstraints.CONNECTING_SIDE_CONSTRAINT),
            connecting.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            connecting.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            bottomBar.heightAnchor.constraint(equalToConstant: DesignConstraints.BOTTOM_BAR_HEIGHT_CONSTRAINT),
            bottomBar.widthAnchor.constraint(equalToConstant: DesignConstraints.BOTTOM_BAR_WIDTH_CONSTRAINT),
            bottomBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            bottomBar.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            // miniLocation view is where the location asstes are nested
            miniLocation.topAnchor.constraint(equalTo: topAnchor),
            miniLocation.bottomAnchor.constraint(equalTo: bottomAnchor),
            miniLocation.trailingAnchor.constraint(equalTo: trailingAnchor),
            miniLocation.widthAnchor.constraint(equalToConstant: DesignConstraints.MINI_LOCATION_WIDTH_CONSTRAINT),
            
            distanceLabel.widthAnchor.constraint(equalToConstant: DesignConstraints.DISTANCE_LABEL_WIDTH_CONSTRAINT),
            distanceLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            distanceLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            pipe.heightAnchor.constraint(equalToConstant: DesignConstraints.PIPE_SIDE_CONSTRAINT),
            pipe.widthAnchor.constraint(equalToConstant: DesignConstraints.PIPE_SIDE_CONSTRAINT),
            pipe.trailingAnchor.constraint(equalTo: distanceLabel.leadingAnchor),
            pipe.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            miniArrow.heightAnchor.constraint(equalToConstant: DesignConstraints.MINI_ARROW_SIDE_CONSTRAINT),
            miniArrow.widthAnchor.constraint(equalToConstant: DesignConstraints.MINI_ARROW_SIDE_CONSTRAINT),
            miniArrow.trailingAnchor.constraint(equalTo: pipe.leadingAnchor, constant: -6),
            miniArrow.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            azimuthLabel.widthAnchor.constraint(equalToConstant: DesignConstraints.AZIMUTH_LABEL_WIDTH_CONSTRAINT),
            azimuthLabel.trailingAnchor.constraint(equalTo: miniArrow.leadingAnchor, constant: -6),
            azimuthLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        backgroundColor = .white
        
        selectAsset(.actionButton)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func selectAsset(_ asset: asset) {
        switch asset {
        case .actionButton:
            miniLocation.isHidden = true
            actionButton.isHidden = false
            connecting.isHidden   = true
            connecting.stopAnimating()
        case .connecting:
            miniLocation.isHidden = true
            actionButton.isHidden = true
            connecting.isHidden   = false
            connecting.startAnimating()
        case .miniLocation:
            miniLocation.isHidden = false
            actionButton.isHidden = true
            connecting.isHidden   = true
            connecting.stopAnimating()
        }
    }
}
