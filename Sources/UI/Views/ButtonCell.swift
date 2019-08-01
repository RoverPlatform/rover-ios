//
//  ButtonCell.swift
//  Rover
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

class ButtonCell: BlockCell {
    let label = UILabel()
    
    override var content: UIView? {
        return label
    }
    
    override func configure(with block: Block, for experience: Experience) {
        super.configure(with: block, for: experience)
        
        guard let buttonBlock = block as? ButtonBlock else {
            label.isHidden = true
            return
        }
        
        label.isHidden = false
        
        let text = buttonBlock.text
        label.highlightedTextColor = text.color.uiColor.withAlphaComponent(0.5 * text.color.uiColor.cgColor.alpha)
        label.text = text.rawValue
        label.textColor = text.color.uiColor
        label.textAlignment = text.alignment.textAlignment
        label.font = text.font.uiFont
    }
}
