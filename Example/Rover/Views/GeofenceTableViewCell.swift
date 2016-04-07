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
    optional func geofenceTableViewCellDidPressEnter(cell: GeofenceTableViewCell)
    optional func geofenceTableViewCellDidPressExit(cell: GeofenceTableViewCell)
}

class GeofenceTableViewCell: UITableViewCell {
    
    @IBOutlet weak var label: UILabel!

    weak var delegate: GeofenceTableViewCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @IBAction func enterClicked(sender: UIButton) {
        delegate?.geofenceTableViewCellDidPressEnter?(self)
    }

    @IBAction func exitClicked(sender: UIButton) {
        delegate?.geofenceTableViewCellDidPressExit?(self)
    }
    
    
}
