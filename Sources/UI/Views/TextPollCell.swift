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
    private let answerTextView = UILabel()
    private let resultFractionPercentage = UILabel()
    private let resultFractionIndicator = UIView()
    private let resultFractionIndicatorBar = UIView()
    private var resultFractionIndicatorBarWidthConstraint: NSLayoutConstraint?
    private var resultFractionPercentageWidthConstraint: NSLayoutConstraint?
    
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
        self.addSubview(self.answerTextView)
        self.addSubview(self.resultFractionPercentage)
        self.resultFractionIndicator.addSubview(self.resultFractionIndicatorBar)
        
        // MARK: Enable AutoLayout
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.answerTextView.translatesAutoresizingMaskIntoConstraints = false
        self.backgroundView.translatesAutoresizingMaskIntoConstraints = false
        self.resultFractionPercentage.translatesAutoresizingMaskIntoConstraints = false
        self.resultFractionIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.resultFractionIndicatorBar.translatesAutoresizingMaskIntoConstraints = false
        
        // MARK: Background Image
        
        self.backgroundView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        self.backgroundView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        self.backgroundView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        self.backgroundView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        
        // MARK: Result Bar
        
        self.resultFractionIndicator.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        self.resultFractionIndicator.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        self.resultFractionIndicator.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        self.resultFractionIndicator.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        self.resultFractionIndicatorBar.backgroundColor = style.resultFillColor.opaque.uiColor
        self.resultFractionIndicatorBar.topAnchor.constraint(equalTo: self.resultFractionIndicator.topAnchor).isActive = true
        self.resultFractionIndicatorBar.bottomAnchor.constraint(equalTo: self.resultFractionIndicator.bottomAnchor).isActive = true
        self.resultFractionIndicatorBar.leadingAnchor.constraint(equalTo: self.resultFractionIndicator.leadingAnchor).isActive = true
         resultFractionIndicatorBarWidthConstraint = self.resultFractionIndicatorBar.widthAnchor.constraint(equalToConstant: 0)
        resultFractionIndicatorBarWidthConstraint!.isActive = true
        self.resultFractionPercentage.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: OPTION_TEXT_SPACING * -1).isActive = true
        self.resultFractionPercentage.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        self.resultFractionPercentage.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        self.resultFractionPercentage.textAlignment = .right
        self.resultFractionPercentageWidthConstraint = self.resultFractionPercentage.widthAnchor.constraint(
            equalToConstant: 0
        )
        self.resultFractionPercentageWidthConstraint!.isActive = true
        // we want the content to expand out to the horizontal space permitted by the percentage view.
        self.answerTextView.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
        self.resultFractionPercentage.font = style.font.bumpedForPercentageIndicator.uiFont
        self.resultFractionPercentage.textColor = style.color.uiColor
        
        // MARK: Answer Text View
        
        self.answerTextView.backgroundColor = .clear
        self.answerTextView.numberOfLines = 1
        self.answerTextView.attributedText = style.attributedText(for: optionText)
        self.answerTextView.lineBreakMode = .byTruncatingTail
        
        self.answerTextView.topAnchor.constraint(equalTo: self.topAnchor, constant: OPTION_TEXT_SPACING).isActive = true
        self.answerTextView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: OPTION_TEXT_SPACING * -1).isActive = true
        self.answerTextView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: OPTION_TEXT_SPACING).isActive = true
        self.answerTextView.trailingAnchor.constraint(equalTo: self.resultFractionPercentage.leadingAnchor, constant: OPTION_TEXT_SPACING * -1).isActive = true
        
        // MARK: Container
        
        self.heightAnchor.constraint(equalToConstant: CGFloat(style.height)).isActive = true
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
        self.resultFractionPercentageWidthConstraint!.constant = 0
    }
    
    private var percentageAnimationTimer: Timer?
    private func revealResultsState(animated: Bool, optionResults: OptionResults) {
        UIView.animate(withDuration: 0.75, delay: 0, options: [.curveEaseInOut], animations: {
            self.resultFractionPercentage.alpha = 1.0
        })
        
        UIView.animate(withDuration: 0.05, delay: 0, options: [.curveEaseInOut], animations: {
            self.resultFractionIndicator.alpha = CGFloat(self.style.resultFillColor.alpha)
        })
        
        let width = self.resultFractionIndicator.frame.width * CGFloat(optionResults.fraction)
        self.resultFractionIndicatorBarWidthConstraint!.constant = width
        UIView.animate(withDuration: 1, delay: 0, options: [.curveEaseInOut], animations: {
            self.resultFractionIndicator.layoutIfNeeded()
        })
        
        let percentageTextFont = self.style.font.bumpedForPercentageIndicator

        // expand the percentage view to accomodate all possible percentage values as we rotate through, to avoid any possible wobble in the layout.
        self.resultFractionPercentageWidthConstraint?.constant = percentageTextFont.attributedText(forPlainText: "100%", color: self.style.color)?.boundingRect(with: .init(width: 1000, height: 1000), options: [], context: nil).width ?? CGFloat(0)
        
        self.percentageAnimationTimer?.invalidate()
        let startTime = Date()
        self.percentageAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true, block: { [weak self] timer in
            let elapsed = Float(startTime.timeIntervalSinceNow) * -1
            let elapsedProportion = elapsed / 1.0 // (1 s)
            if elapsedProportion > 1.0 {
                self?.resultFractionPercentage.text = String(format: "%.0f%%", optionResults.fraction * 100)
                timer.invalidate()
            } else {
                self?.resultFractionPercentage.text = String(format: "%.0f%%", (optionResults.fraction * 100) * elapsedProportion)
            }
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
        
        // TODO: A stand-in for the user tapping.
        self.timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
            self.optionViews[0].state = .answered(optionResults: TextPollOptionView.OptionResults(selected: true, fraction: 0.80))
            self.optionViews[1].state = .answered(optionResults: TextPollOptionView.OptionResults(selected: false, fraction: 0.25))
            self.optionViews[2].state = .answered(optionResults: TextPollOptionView.OptionResults(selected: false, fraction: 0.66))
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
        
        return optionsHeight + optionSpacing + questionHeight + CGFloat(insets.top + insets.bottom)
    }
}

// MARK: Helpers

extension TextPollBlock.OptionStyle {
    func attributedText(for text: String) -> NSAttributedString? {
        return self.font.attributedText(forPlainText: text, color: self.color)
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
    func attributedText(forPlainText text: String, color: Color) -> NSAttributedString? {
        let text = Text(rawValue: text, alignment: .left, color: color, font: self)
        return text.attributedText(forFormat: .plain)
    }
    
    var bumpedForPercentageIndicator: Text.Font {
        return Text.Font(size: self.size * 1.05, weight: self.weight.bumped)
    }
}

extension Color {
    var opaque: Color {
        return Color.init(red: self.red, green: self.green, blue: self.blue, alpha: 1.0)
    }
}
