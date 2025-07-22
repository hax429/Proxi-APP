
import Foundation
import UIKit
import os.log

class AccessoriesTable: UITableView, UITableViewDelegate, UITableViewDataSource {
    
    let logger = os.Logger(subsystem: "com.qorvo.ni", category: "AccessoriesTable")
    
    var tableDelegate: TableProtocol?
    
    // Device list for UIKit compatibility
    var qorvoDevices: [qorvoDevice?] = []
    
    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        
        // Set up the table view
        delegate = self
        dataSource = self
        
        // Register a cell class for reuse
        register(SingleCell.self, forCellReuseIdentifier: "SingleCell")
        
                    rowHeight = DesignConstraints.ACCESSORY_TABLE_ROW_HEIGHT_CONSTRAINT
        separatorInset = .zero
        separatorStyle = .none
        tableFooterView = UIView()
        
        // Set up the parent view's constraints
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: DesignConstraints.ACCESSORY_TABLE_HEIGHT_CONSTRAINT),
            topAnchor.constraint(equalTo: topAnchor),
            leadingAnchor.constraint(equalTo: leadingAnchor),
            trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        separatorStyle = .none
        backgroundColor = .white
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setCellAsset(_ deviceID: Int,_ newAsset: asset) {
        // Edit cell for this uniqueID
        for case let cell as SingleCell in self.visibleCells {
            if cell.uniqueID == deviceID {
                cell.selectAsset(newAsset)
            }
        }
    }
    
    func setCellColor(_ deviceID: Int,_ newColor: UIColor) {
        // Edit cell for this uniqueID
        for case let cell as SingleCell in self.visibleCells {
            if cell.uniqueID == deviceID {
                cell.accessoryButton.backgroundColor = newColor
            }
        }
    }
    
    func handleCell(_ index: Int,_ insert: Bool ) {
        self.beginUpdates()
        if (insert) {
            self.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        }
        else {
            self.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        }
        self.endUpdates()
    }
    
    func updateCell(_ deviceID: Int,_ distance: Float,_ azimuth: Int) {
        for case let cell as SingleCell in self.visibleCells {
            if cell.uniqueID == deviceID {
                cell.distanceLabel.text = String(format: "meters".localized, distance)
                cell.azimuthLabel.text  = String(format: "degrees".localized, azimuth)
                
                // Update mini arrow
                let radians: CGFloat = CGFloat(azimuth) * (.pi / 180)
                cell.miniArrow.transform = CGAffineTransform(rotationAngle: radians)
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // Only one section
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Number of rows equals the number of accessories
        return qorvoDevices.count
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let disconnect = UIContextualAction(style: .normal, title: "") { [self] (action, view, completion) in
            // Send the disconnection message to the device
            let cell = tableView.cellForRow(at: indexPath) as! SingleCell
            let deviceID = cell.uniqueID
            
            tableDelegate?.sendStopToDevice(deviceID)
            
            completion(true)
        }
        // Set the Contextual action parameters
        disconnect.image = UIImage(named: "trash_bin")
        disconnect.backgroundColor = .qorvoRed
        
        let swipeActions = UISwipeActionsConfiguration(actions: [disconnect])
        swipeActions.performsFirstActionWithFullSwipe = false
        
        return swipeActions
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SingleCell", for: indexPath) as! SingleCell
        
        let qorvoDevice = qorvoDevices[indexPath.row]
        
        cell.uniqueID = (qorvoDevice?.bleUniqueID)!
        
        // Initialize the new cell assets
        cell.accessoryButton.tag = cell.uniqueID
        cell.accessoryButton.setTitle(qorvoDevice?.blePeripheralName, for: .normal)
        cell.accessoryButton.addTarget(self,
                                       action: #selector(buttonSelect),
                                       for: .touchUpInside)
        cell.accessoryButton.isEnabled = true
        
        cell.actionButton.tag = cell.uniqueID
        cell.actionButton.addTarget(self,
                                    action: #selector(buttonAction),
                                    for: .touchUpInside)
        cell.actionButton.isEnabled = true
        
        logger.info("New device included at row \(indexPath.row)")
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    // MARK: - TableProtocol delegate wraper
    
    @objc func buttonSelect(_ sender: UIButton) {
        tableDelegate?.buttonSelect(sender)
    }
    
    @objc func buttonAction(_ sender: UIButton) {
        tableDelegate?.buttonAction(sender)
    }
}
