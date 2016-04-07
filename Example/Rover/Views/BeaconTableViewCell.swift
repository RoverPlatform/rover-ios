//
//  BeaconTableViewCell.swift
//  Rover
//
//  Created by Ata Namvari on 2016-02-26.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit

@objc
protocol BeaconTableViewCellDelegate: class {
    optional func beaconTableViewCellDidPressEnter(cell: BeaconTableViewCell)
    optional func beaconTableViewCellDidPressExit(cell: BeaconTableViewCell)
}

class BeaconTableViewCell: UITableViewCell {

    @IBOutlet weak var label: UILabel!
    
    @IBOutlet weak var majorTextField: UITextField!
    @IBOutlet weak var minorTextField: UITextField!
    
    weak var delegate: BeaconTableViewCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func enterClicked(sender: UIButton) {
        delegate?.beaconTableViewCellDidPressEnter?(self)
    }
    
    @IBAction func exitClicked(sender: UIButton) {
        delegate?.beaconTableViewCellDidPressExit?(self)
    }
    
}