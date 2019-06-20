//
//  ImagePollCell.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-19.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

class ImagePollCell: BlockCell {
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
        
        guard let textPollBlock = block as? ImagePollBlock else {
            textView.isHidden = true
            return
        }
        
        textView.isHidden = false
        textView.text = "PRAISE JEBUS I AM IMAGE POLL"
    }
}
