//
//  TextCell.swift
//  Rover
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

class TextCell: BlockCell {
    let textView: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = UIColor.clear
        textView.isUserInteractionEnabled = false
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets.zero
        return textView
    }()
    
    override var content: UIView? {
        return textView
    }
    
    override func configure(with block: Block) {
        super.configure(with: block)
        
        guard let textBlock = block as? TextBlock else {
            textView.isHidden = true
            return
        }
        
        textView.isHidden = false
        textView.attributedText = textBlock.text.attributedText
    }
}
