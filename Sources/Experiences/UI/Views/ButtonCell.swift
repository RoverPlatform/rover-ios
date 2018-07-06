//
//  ButtonCell.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

open class ButtonCell: BlockCell {
    open let label = UILabel()
    
    open override var content: UIView? {
        return label
    }
    
    open override func configure(with block: Block, imageStore: ImageStore) {
        super.configure(with: block, imageStore: imageStore)
        
        guard let buttonBlock = block as? ButtonBlock else {
            label.isHidden = true
            return
        }
        
        label.isHidden = false
        
        let text = buttonBlock.text
        label.highlightedTextColor = text.color.uiColor.withAlphaComponent(0.5)
        label.text = text.rawValue
        label.textColor = text.color.uiColor
        label.textAlignment = text.alignment.textAlignment
        label.font = text.font.uiFont
    }
}
