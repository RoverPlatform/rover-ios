//
//  TextPollCell.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-19.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

// MARK: Option View

// TODO: andrew start here and make this a UIView (analagous to contentView in blockCell) so we can add both the UILabel AND a "backgroundView" (again, akin to blockCell)
class TextPollOptionView: UIView {
    private let backgroundView = UIImageView()
    private let content = UILabel()
    
    init(
        optionText: String,
        style: TextPollBlock.OptionStyle
    ) {
        super.init(frame: CGRect.zero)
        self.addSubview(backgroundView)
        self.addSubview(content)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        backgroundView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        backgroundView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        backgroundView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        self.clipsToBounds = true
        
        content.backgroundColor = UIColor.clear
        content.numberOfLines = 1
        
        content.font = style.font.uiFont
        content.textColor = style.color.uiColor
        content.text = optionText
        
        self.configureContent(content: content, withInsets: .zero)
        // TODO: the original configureOpacity from Rover blocks worked on a contained contentView rather than on the containing block cell.  I have no equivalent here, and I have no idea if that distinction was important or not.  I will find out.
        self.configureOpacity(opacity: style.opacity)
        self.configureBorder(border: style.border, constrainedByFrame: nil)
        self.configureBackgroundColor(color: style.background.color, opacity: style.opacity)
        self.backgroundView.configureAsBackgroundImage(background: style.background) {
            // Option views are not recycled in the containing CollectionView driving the Rover experience, so we don't need to worry about checking that the background image loading callback is associated with a "stale" option.
            true
        }
        
        // TODO: set up alignment
        
        self.heightAnchor.constraint(equalToConstant: CGFloat(style.height)).isActive = true
    }
    
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Usage in XIB not supported.")
    }
}

// MARK: Question View

class PollQuestionView: UIView {
    private let backgroundView = UIImageView()
    private let content = UITextView()
    
    init(
        questionText: String,
        style: QuestionStyle
    ) {
        super.init(frame: .zero)
        self.addSubview(backgroundView)
        self.addSubview(content)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        self.clipsToBounds = true
        
        content.text = questionText
        content.font = style.font.uiFont
        content.isScrollEnabled = false
        content.backgroundColor = UIColor.clear
        content.isUserInteractionEnabled = false
        content.textContainer.lineFragmentPadding = 0
        content.textContainerInset = UIEdgeInsets.zero
        
        // TODO: set up alignment.
        
        self.configureContent(content: content, withInsets: .zero)
        // TODO: the original configureOpacity from Rover blocks worked on a contained contentView rather than on the containing block cell.  I have no equivalent here, and I have no idea if that distinction was important or not.  I will find out.
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Usage in XIB not supported.")
    }
}

// MARK: Cell

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

// MARK: Measurement

extension TextPollBlock {
    func intrinsicHeight(blockWidth: CGFloat) -> CGFloat {
        let innerWidth = blockWidth - CGFloat(insets.left) - CGFloat(insets.right)
        
        let size = CGSize(width: innerWidth, height: CGFloat.greatestFiniteMagnitude)
        
        let questionAttributedText = self.questionStyle.attributedText(for: self.question)
        
        let questionHeight = questionAttributedText?.boundingRect(with: size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height ?? CGFloat(0)
        
        let optionStyleHeight = self.optionStyle.height
        let verticalSpacing = self.optionStyle.verticalSpacing
        
        let optionsHeight: CGFloat = CGFloat(optionStyleHeight) * CGFloat(self.options.count)
        let optionSpacing: CGFloat = CGFloat(verticalSpacing) * CGFloat(self.options.count)

        return optionsHeight + optionSpacing + questionHeight
    }
}

extension QuestionStyle {
    func attributedText(for text: String) -> NSAttributedString? {
        let text = Text(rawValue: text, alignment: .left, color: self.color, font: self.font)
        return text.attributedText(forFormat: .plain)
    }
}
