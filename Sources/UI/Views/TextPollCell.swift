//
//  TextPollCell.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-19.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

fileprivate let OPTION_TEXT_SPACING = CGFloat(16)

// MARK: Option View

class TextPollOptionView: UIView {
    var state: State {
        didSet {
            switch state {
            case .waitingForAnswer:
                revealQuestionState()
            case .answered(let optionResults):
                revealResultsState(animated: true, optionResults: optionResults)
            }
        }
    }
    
    struct OptionResults {
        let selected: Bool
        let fraction: Float
    }
    
    enum State {
        case waitingForAnswer
        case answered(optionResults: OptionResults)
    }
    
    private let backgroundView = UIImageView()
    private let content = UILabel()
    private let resultFractionPercentage = UILabel()
    private let resultFractionIndicator = UIView()
    private let resultFractionIndicatorBar = UIView()
    private var resultFractionIndicatorBarWidthConstraint: NSLayoutConstraint?
    
    private let style: TextPollBlock.OptionStyle
    
    init(
        optionText: String,
        style: TextPollBlock.OptionStyle,
        initialState: State
    ) {
        self.style = style
        self.state = initialState
        
        super.init(frame: CGRect.zero)
        self.addSubview(self.backgroundView)
        self.addSubview(self.resultFractionIndicator)
        self.addSubview(self.content)
        self.addSubview(self.resultFractionPercentage)
        self.resultFractionIndicator.addSubview(self.resultFractionIndicatorBar)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.content.translatesAutoresizingMaskIntoConstraints = false
        self.backgroundView.translatesAutoresizingMaskIntoConstraints = false
        self.resultFractionPercentage.translatesAutoresizingMaskIntoConstraints = false
        self.resultFractionIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.resultFractionIndicatorBar.translatesAutoresizingMaskIntoConstraints = false
        
        self.backgroundView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        self.backgroundView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        self.backgroundView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        self.backgroundView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        
        self.resultFractionIndicator.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        self.resultFractionIndicator.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        self.resultFractionIndicator.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        self.resultFractionIndicator.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        self.resultFractionIndicatorBar.backgroundColor = style.resultFillColor.uiColor
        self.resultFractionIndicatorBar.topAnchor.constraint(equalTo: self.resultFractionIndicator.topAnchor).isActive = true
        self.resultFractionIndicatorBar.bottomAnchor.constraint(equalTo: self.resultFractionIndicator.bottomAnchor).isActive = true
        self.resultFractionIndicatorBar.leadingAnchor.constraint(equalTo: self.resultFractionIndicator.leadingAnchor).isActive = true
         resultFractionIndicatorBarWidthConstraint = self.resultFractionIndicatorBar.widthAnchor.constraint(equalToConstant: 0)
        resultFractionIndicatorBarWidthConstraint!.isActive = true
        
        self.heightAnchor.constraint(equalToConstant: CGFloat(style.height)).isActive = true
        
        
        self.resultFractionPercentage.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: OPTION_TEXT_SPACING * -1).isActive = true
        self.resultFractionPercentage.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        self.resultFractionPercentage.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        self.resultFractionPercentage.text = "67%"
        // we want the content to expand out to the horizontal space permitted by the percentage view.
        self.content.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
        self.resultFractionPercentage.font = style.font.uiFontForPercentageIndciator
        self.resultFractionPercentage.textColor = style.color.uiColor
        
        // Configure text view:
        self.content.backgroundColor = .clear
        self.content.numberOfLines = 1
        self.content.attributedText = style.attributedText(for: optionText)
        self.content.lineBreakMode = .byTruncatingTail
        
        self.content.topAnchor.constraint(equalTo: self.topAnchor, constant: OPTION_TEXT_SPACING).isActive = true
        self.content.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: OPTION_TEXT_SPACING * -1).isActive = true
        self.content.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: OPTION_TEXT_SPACING).isActive = true
        self.content.trailingAnchor.constraint(equalTo: self.resultFractionPercentage.leadingAnchor, constant: OPTION_TEXT_SPACING * -1).isActive = true
        

        
        self.configureOpacity(opacity: style.opacity)
        self.clipsToBounds = true
        self.configureBorder(border: style.border, constrainedByFrame: nil)
        self.configureBackgroundColor(color: style.background.color, opacity: style.opacity)
        
        switch initialState {
        case .waitingForAnswer:
            revealQuestionState()
        case .answered(let optionResults):
            revealResultsState(animated: false, optionResults: optionResults)
        }
    }
    
    private func revealQuestionState() {
        self.resultFractionPercentage.alpha = 0.0
        self.resultFractionIndicator.alpha = 0.0
        self.resultFractionIndicatorBarWidthConstraint!.constant = 0
    }
    
    private func revealResultsState(animated: Bool, optionResults: OptionResults) {
        self.resultFractionPercentage.text = String(format: "%.0f %%", optionResults.fraction * 100)
        
        UIView.animate(withDuration: 0.75, delay: 0, options: [.curveEaseInOut], animations: {
            self.resultFractionPercentage.alpha = 1.0
        })
        
        UIView.animate(withDuration: 0.05, delay: 0, options: [.curveEaseInOut], animations: {
            self.resultFractionIndicator.alpha = 1.0
        })
        
        let width = self.resultFractionIndicator.frame.width * CGFloat(optionResults.fraction)
        self.resultFractionIndicatorBarWidthConstraint!.constant = width
        UIView.animate(withDuration: 1, delay: 0, options: [.curveEaseInOut], animations: {
            self.resultFractionIndicator.layoutIfNeeded()
        })
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Usage in XIB not supported.")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.backgroundView.configureAsBackgroundImage(background: style.background)
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
    
    var timer: Timer?
    
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
            // TODO: get initial state synchronously from the local VotingService.
            TextPollOptionView(optionText: option, style: textPollBlock.optionStyle, initialState: .waitingForAnswer)
        }
        for optionViewIndex in 0..<optionViews.count {
            let currentOptionView = self.optionViews[optionViewIndex]
            containerView.addSubview(currentOptionView)
            if optionViewIndex > 0 {
                let previousOptionView = self.optionViews[optionViewIndex - 1]
                currentOptionView.topAnchor.constraint(equalTo: previousOptionView.bottomAnchor, constant: CGFloat(textPollBlock.optionStyle.verticalSpacing)).isActive = true
            } else {
                currentOptionView.topAnchor.constraint(equalTo: questionView!.bottomAnchor, constant: CGFloat(textPollBlock.optionStyle.verticalSpacing)).isActive = true
            }
            currentOptionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
            currentOptionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        }
        
        // TODO: A stand-in for the user tapping.
        self.timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in
            self.optionViews[0].state = .answered(optionResults: TextPollOptionView.OptionResults(selected: true, fraction: 0.67))
            self.optionViews[1].state = .answered(optionResults: TextPollOptionView.OptionResults(selected: false, fraction: 0.166))
            self.optionViews[2].state = .answered(optionResults: TextPollOptionView.OptionResults(selected: false, fraction: 0.166))
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



// MARK: Helpers

extension TextPollBlock.OptionStyle {
    func attributedText(for text: String) -> NSAttributedString? {
        let text = Text(rawValue: text, alignment: .left, color: self.color, font: self.font)
        return text.attributedText(forFormat: .plain)
    }
}

extension Text.Font.Weight {
    /// Return a weight two stops heavier.
    var bumped: Text.Font.Weight {
        switch self {
        case .ultraLight:
            return .light
        case .thin:
            return .regular
        case .light:
            return .medium
        case .regular:
            return .semiBold
        case .medium:
            return .bold
        case .semiBold:
            return .heavy
        case .bold:
            return .black
        case .heavy:
            return .black
        case .black:
            return .black
        }
    }
}

extension Text.Font {
    var uiFontForPercentageIndciator: UIFont {
        return UIFont.systemFont(ofSize: CGFloat(size) * 1.05, weight: weight.bumped.uiFontWeight)
    }
}
