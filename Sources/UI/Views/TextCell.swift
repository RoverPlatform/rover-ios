//
//  TextCell.swift
//  Rover
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

open class TextCell: BlockCell {
    public let textView: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = UIColor.clear
        textView.isUserInteractionEnabled = false
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets.zero
        return textView
    }()
    
    override open var content: UIView? {
        return textView
    }
    
    override open func configure(with block: Block, imageStore: ImageStore) {
        super.configure(with: block, imageStore: imageStore)
        
        guard let textBlock = block as? TextBlock else {
            textView.isHidden = true
            return
        }
        
        textView.isHidden = false
        textView.attributedText = textBlock.text.attributedText
    }
}
