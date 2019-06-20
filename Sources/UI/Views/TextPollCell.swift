//
//  TextPollCell.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-19.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

class TextPollCell: BlockCell {
//    let textView: UITextView = {
//        let textView = UITextView()
//        textView.backgroundColor = UIColor.clear
//        textView.isUserInteractionEnabled = false
//        textView.textContainer.lineFragmentPadding = 0
//        textView.textContainerInset = UIEdgeInsets.zero
//        return textView
//    }()
    
    private var createdOptions
    
    override var content: UIView? {
        return textView
    }
    
    override func configure(with block: Block) {
        super.configure(with: block)
        
        guard let textPollBlock = block as? TextPollBlock else {
            textView.isHidden = true
            return
        }
        
        
        
        textView.isHidden = false
        textView.text = "PRAISE JEBUS I AM TEXT POLL"
    }
}

extension TextPollBlock {
    func intrinsicHeight(blockWidth: CGFloat) -> CGFloat {
        return CGFloat(42.0)
//        // Roundtrip to avoid rounding when converting floats to ints causing mismatches in measured size vs views actual size
//        let optionStyleHeight = self.optionStyle.height
//        let borderWidth = self.optionStyle.borderWidth
//        let verticalSpacing = self.optionStyle.verticalSpacing
//
//        let questionHeight = measurementService.measureHeightNeededForMultiLineTextInTextView(
//            textPollBlock.question,
//            textPollBlock.questionStyle.font.getFontAppearance(textPollBlock.questionStyle.color, textPollBlock.questionStyle.textAlignment),
//        bounds.width())
//        let optionsHeight = ((optionStyleHeight + (borderWidth * 2)) * self.options.size)
//        let optionSpacing = verticalSpacing * (self.options.size)
//
//        return optionsHeight + optionSpacing + questionHeight
        return 20
    }
}
