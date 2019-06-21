//
//  TextPollCell.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-19.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

///
class TextPollOptionView: UITextView {
    init(
        optionText: String,
        style: TextPollBlock.OptionStyle
    ) {
        super.init(frame: CGRect.zero, textContainer: nil)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.text = optionText
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
//        self.optionViews = textPollBlock.options.map { option in
//            TextPollOptionView(optionText: option, style: textPollBlock.optionStyle)
//        }
//        for optionViewIndex in 0..<optionViews.count {
//            let currentOptionView = self.optionViews[optionViewIndex]
//            containerView.addSubview(currentOptionView)
//            currentOptionView.heightAnchor.constraint(equalToConstant: CGFloat(textPollBlock.optionStyle.height)).isActive = true
//            if optionViewIndex > 0 {
//                let previousOptionView = self.optionViews[optionViewIndex - 1]
//                currentOptionView.topAnchor.constraint(equalTo: previousOptionView.bottomAnchor).isActive = true
//            } else {
//                currentOptionView.topAnchor.constraint(equalTo: questionView!.bottomAnchor).isActive = true
//            }
//        }
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
    }
}
