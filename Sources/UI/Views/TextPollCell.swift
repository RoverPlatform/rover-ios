//
//  TextPollCell.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-19.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

// MARK: Constants

private let OPTION_TEXT_SPACING = CGFloat(16)
private let RESULT_PERCENTAGE_REVEAL_TIME = 0.75 // ms
private let RESULT_FILL_BAR_REVEAL_TIME = 0.05 // ms
private let RESULT_FILL_BAR_FILL_TIME = 1.00 // ms

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
    private let resultPercentage = UILabel()
    private let resultFillBarArea = UIView()
    private let resultFillBar = UIView()
    private var resultFillBarWidthConstraint: NSLayoutConstraint?
    private var resultPercentageWidthConstraint: NSLayoutConstraint?
    
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
        self.addSubview(self.resultFillBarArea)
        self.addSubview(self.answerTextView)
        self.addSubview(self.resultPercentage)
        self.resultFillBarArea.addSubview(self.resultFillBar)
        
        // MARK: Enable AutoLayout
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.answerTextView.translatesAutoresizingMaskIntoConstraints = false
        self.backgroundView.translatesAutoresizingMaskIntoConstraints = false
        self.resultPercentage.translatesAutoresizingMaskIntoConstraints = false
        self.resultFillBarArea.translatesAutoresizingMaskIntoConstraints = false
        self.resultFillBar.translatesAutoresizingMaskIntoConstraints = false
        
        // MARK: Background Image
        
        self.backgroundView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        self.backgroundView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        self.backgroundView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        self.backgroundView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        
        // MARK: Result Fill Bar
        
        self.resultFillBarArea.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        self.resultFillBarArea.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        self.resultFillBarArea.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        self.resultFillBarArea.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        self.resultFillBar.backgroundColor = style.resultFillColor.opaque.uiColor
        self.resultFillBar.topAnchor.constraint(equalTo: self.resultFillBarArea.topAnchor).isActive = true
        self.resultFillBar.bottomAnchor.constraint(equalTo: self.resultFillBarArea.bottomAnchor).isActive = true
        self.resultFillBar.leadingAnchor.constraint(equalTo: self.resultFillBarArea.leadingAnchor).isActive = true
        self.resultFillBarWidthConstraint = self.resultFillBar.widthAnchor.constraint(equalToConstant: 0)
        self.resultFillBarWidthConstraint!.isActive = true
        
        // MARK: Result Percentage
        
        self.resultPercentage.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: OPTION_TEXT_SPACING * -1).isActive = true
        self.resultPercentage.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        self.resultPercentage.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        self.resultPercentage.textAlignment = .right
        self.resultPercentageWidthConstraint = self.resultPercentage.widthAnchor.constraint(
            equalToConstant: 0
        )
        self.resultPercentageWidthConstraint!.isActive = true
        // we want the content to expand out to the horizontal space permitted by the percentage view.
        self.answerTextView.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
        self.resultPercentage.font = style.font.bumpedForPercentageIndicator.uiFont
        self.resultPercentage.textColor = style.color.uiColor
        
        // MARK: Answer Text View
        
        self.answerTextView.backgroundColor = .clear
        self.answerTextView.numberOfLines = 1
        self.answerTextView.attributedText = style.attributedText(for: optionText)
        self.answerTextView.lineBreakMode = .byTruncatingTail
        self.answerTextView.topAnchor.constraint(equalTo: self.topAnchor, constant: OPTION_TEXT_SPACING).isActive = true
        self.answerTextView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: OPTION_TEXT_SPACING * -1).isActive = true
        self.answerTextView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: OPTION_TEXT_SPACING).isActive = true
        self.answerTextView.trailingAnchor.constraint(equalTo: self.resultPercentage.leadingAnchor, constant: OPTION_TEXT_SPACING * -1).isActive = true
        
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
    
    // MARK: States and Animation
    
    private func revealQuestionState() {
        self.resultPercentage.alpha = 0.0
        self.resultFillBarArea.alpha = 0.0
        self.resultFillBarWidthConstraint!.constant = 0
        self.resultPercentageWidthConstraint!.constant = 0
    }
    
    private var percentageAnimationTimer: Timer?
    private func revealResultsState(animated: Bool, optionResults: OptionResults) {
        UIView.animate(withDuration: RESULT_PERCENTAGE_REVEAL_TIME, delay: 0, options: [.curveEaseInOut], animations: {
            self.resultPercentage.alpha = 1.0
        })
        
        UIView.animate(withDuration: RESULT_FILL_BAR_REVEAL_TIME, delay: 0, options: [.curveEaseInOut], animations: {
            self.resultFillBarArea.alpha = CGFloat(self.style.resultFillColor.alpha)
        })
        
        let width = self.resultFillBarArea.frame.width * CGFloat(optionResults.fraction)
        self.resultFillBarWidthConstraint!.constant = width
        UIView.animate(withDuration: RESULT_FILL_BAR_FILL_TIME, delay: 0, options: [.curveEaseInOut], animations: {
            self.resultFillBarArea.layoutIfNeeded()
        })
        
        let percentageTextFont = self.style.font.bumpedForPercentageIndicator

        // expand the percentage view to accomodate all possible percentage values as we animate through them, to avoid any possible wobble in the layout.
        self.resultPercentageWidthConstraint?.constant = percentageTextFont.attributedText(forPlainText: "100%", color: self.style.color)?.boundingRect(with: .init(width: 1_000, height: 1_000), options: [], context: nil).width ?? CGFloat(0)
        
        self.percentageAnimationTimer?.invalidate()
        let startTime = Date()
        self.percentageAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true, block: { [weak self] timer in
            // TODO: calculate a "start position" from the current value on the constraint, in order for repeat calls to `revealResultsState` to properly animate through the percentages between the current value rather than just 0.
            let elapsed = Double(startTime.timeIntervalSinceNow) * -1
            let elapsedProportion = elapsed / RESULT_FILL_BAR_FILL_TIME
            if elapsedProportion > 1.0 {
                self?.resultPercentage.text = String(format: "%.0f%%", optionResults.fraction * 100)
                timer.invalidate()
            } else {
                self?.resultPercentage.text = String(format: "%.0f%%", Double(optionResults.fraction * 100) * elapsedProportion)
            }
        })
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Usage in XIB not supported.")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // we defer configuring background image to here so that the layout has been calculated, and thus frame is available.
        self.backgroundView.configureAsBackgroundImage(background: style.background)
    }
}

// MARK: Cell View

class TextPollCell: BlockCell {
    /// a simple container view to the relatively complex layout of the text poll.
    private let containerView = UIView()
    
    private var optionViews = [TextPollOptionView]()
    
    override var content: UIView? {
        return containerView
    }
    
    private var questionView: PollQuestionView?
    
    private var temporaryTapDemoTimer: Timer?
    
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
        self.temporaryTapDemoTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in
            self.optionViews[0].state = .answered(optionResults: TextPollOptionView.OptionResults(selected: true, fraction: 0.67))
            self.optionViews[1].state = .answered(optionResults: TextPollOptionView.OptionResults(selected: false, fraction: 0.166))
            self.optionViews[2].state = .answered(optionResults: TextPollOptionView.OptionResults(selected: false, fraction: 0.166))
        }
        
        // TODO: A stand-in for the user tapping.
        self.temporaryTapDemoTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
            self.optionViews[0].state = .answered(optionResults: TextPollOptionView.OptionResults(selected: true, fraction: 0.50))
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
    fileprivate func attributedText(for text: String) -> NSAttributedString? {
        return self.font.attributedText(forPlainText: text, color: self.color)
    }
}

extension Text.Font.Weight {
    /// Return a weight two stops heavier.
    fileprivate var bumped: Text.Font.Weight {
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
    fileprivate func attributedText(forPlainText text: String, color: Color) -> NSAttributedString? {
        let text = Text(rawValue: text, alignment: .left, color: color, font: self)
        return text.attributedText(forFormat: .plain)
    }
    
    fileprivate var bumpedForPercentageIndicator: Text.Font {
        return Text.Font(size: self.size * 1.05, weight: self.weight.bumped)
    }
}

extension Color {
    fileprivate var opaque: Color {
        return Color(red: self.red, green: self.green, blue: self.blue, alpha: 1.0)
    }
}
