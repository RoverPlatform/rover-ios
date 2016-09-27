//
//  ValueTableViewCell.swift
//  Rover
//
//  Created by Ata Namvari on 2016-03-04.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit

protocol TraitTableViewCellDelegate: class {
    func traitTableViewCell(_ cell: TraitTableViewCell, didChangeValue value: String?)
}


class TraitTableViewCell: UITableViewCell {
    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var label: UILabel!
    
    weak var delegate: TraitTableViewCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @IBAction func editingDidEnd(_ sender: UITextField) {
        delegate?.traitTableViewCell(self, didChangeValue: sender.text)
    }

}
