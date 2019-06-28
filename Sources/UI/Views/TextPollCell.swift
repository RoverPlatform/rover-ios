//
//  TextPollCell.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-19.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

///

// TODO: andrew start here and make this a UIView (analagous to contentView in blockCell) so we can add both the UILabel AND a "backgroundView" (again, akin to blockCell)
class TextPollOptionView: UILabel {
    init(
        optionText: String,
        style: TextPollBlock.OptionStyle
    ) {
        super.init(frame: CGRect.zero)
        self.translatesAutoresizingMaskIntoConstraints = false
//        self.isScrollEnabled = false
        self.text = optionText
        
        // TODO: the original configureOpacity from Rover blocks worked on a contained contentView rather than on the containing block cell.  I have no equivalent here, and I have no idea if that distinction was important or not.  I will find out.
        self.configureOpacity(opacity: style.opacity)
        self.configureBorder(border: style.border)
        self.configureBackgroundColor(color: style.background.color, opacity: style.opacity)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Usage in XIB not supported.")
    }
}

class PollQuestionView: UILabel {
    init(
        questionText: String,
        style: QuestionStyle
    ) {

//        super.init(frame: CGRect.zero, textContainer: nil)
        super.init(frame: .zero)
        self.numberOfLines = 0
        self.translatesAutoresizingMaskIntoConstraints = false
        self.text = questionText
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Usage in XIB not supported.")
    }
}

class TextPollCell: BlockCell {
    /// a simple container view to the relatively complex layout of the text poll.
    let containerView = UIView()
    
    private var optionViews = [TextPollOptionView]()
    
    override var content: UIView? {
        return containerView
    }
    
    var questionView: PollQuestionView?
    
    override func configure(with block: Block) {
        super.configure(with: block)
     
        containerView.translatesAutoresizingMaskIntoConstraints = false
        questionView?.removeFromSuperview()
        self.optionViews.forEach { $0.removeFromSuperview() }
        
        guard let textPollBlock = block as? TextPollBlock else {
            return
        }
    
        questionView = PollQuestionView(questionText: textPollBlock.question, style: textPollBlock.questionStyle)
        containerView.addSubview(questionView!)
        questionView?.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
        questionView?.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
        questionView?.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        self.optionViews = textPollBlock.options.map { option in
            TextPollOptionView(optionText: option, style: textPollBlock.optionStyle)
        }
        for optionViewIndex in 0..<optionViews.count {
            let currentOptionView = self.optionViews[optionViewIndex]
            containerView.addSubview(currentOptionView)
            // ANDREW START HERE AND IDENTIFY HOW TO MAKE THE UITEXTVIEW FOR POLL OPTIONS A FIXED HEIGHT (WITH TEXT CENTERED VERTICALLY). might need to disable scrolling?
            currentOptionView.heightAnchor.constraint(equalToConstant: CGFloat(textPollBlock.optionStyle.height)).isActive = true
            if optionViewIndex > 0 {
                let previousOptionView = self.optionViews[optionViewIndex - 1]
                currentOptionView.topAnchor.constraint(equalTo: previousOptionView.bottomAnchor).isActive = true
            } else {
                currentOptionView.topAnchor.constraint(equalTo: questionView!.bottomAnchor).isActive = true
            }
            currentOptionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
            currentOptionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        }
    }
}

extension TextPollBlock {
    func intrinsicHeight(blockWidth: CGFloat) -> CGFloat {
        return CGFloat(485.0)
//        // Roundtrip to avoid rounding when converting floats to ints causing mismatches in measured size vs views actual size
//        let optionStyleHeight = self.optionStyle.height
        //        let borderWidth = self.optionStyle.borderWidth // TODO: REMOVE THIS BORDER WIDTH CONCERN, NO LONGER VALID.
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
    }
}
