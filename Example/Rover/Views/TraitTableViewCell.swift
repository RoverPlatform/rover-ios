//
//  ValueTableViewCell.swift
//  Rover
//
//  Created by Ata Namvari on 2016-03-04.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit

protocol TraitTableViewCellDelegate: class {
    func traitTableViewCell(cell: TraitTableViewCell, didChangeValue value: String?)
}


class TraitTableViewCell: UITableViewCell {
    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var label: UILabel!
    
    weak var delegate: TraitTableViewCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @IBAction func editingDidEnd(sender: UITextField) {
        delegate?.traitTableViewCell(self, didChangeValue: sender.text)
    }

}
