//
//  GeofenceTableViewCell.swift
//  Rover
//
//  Created by Ata Namvari on 2016-02-26.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit

@objc
protocol GeofenceTableViewCellDelegate: class {
    @objc optional func geofenceTableViewCellDidPressEnter(_ cell: GeofenceTableViewCell)
    @objc optional func geofenceTableViewCellDidPressExit(_ cell: GeofenceTableViewCell)
}

class GeofenceTableViewCell: UITableViewCell {
    
    @IBOutlet weak var label: UILabel!

    weak var delegate: GeofenceTableViewCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @IBAction func enterClicked(_ sender: UIButton) {
        delegate?.geofenceTableViewCellDidPressEnter?(self)
    }

    @IBAction func exitClicked(_ sender: UIButton) {
        delegate?.geofenceTableViewCellDidPressExit?(self)
    }
    
    
}
