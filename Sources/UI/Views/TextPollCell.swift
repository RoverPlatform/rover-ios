//
//  TextPollCell.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-19.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import os
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
        let fraction: Double
        let percentage: Int
    }
    
    enum State {
        case waitingForAnswer
        case answered(optionResults: OptionResults)
    }
    
    public var topMargin: Int {
        return self.option.topMargin
    }
    
    public var optionId: String {
        return self.option.id
    }
    
    private let backgroundView = UIImageView()
    private let answerTextView = UILabel()
    private let resultPercentage = UILabel()
    private let resultFillBarArea = UIView()
    private let resultFillBar = UIView()
    private var resultFillBarWidthConstraint: NSLayoutConstraint?
    private var resultPercentageWidthConstraint: NSLayoutConstraint?
    
    public let option: TextPollBlock.TextPoll.Option
    
    private let optionTapped: () -> Void
    
    init(
        option: TextPollBlock.TextPoll.Option,
        initialState: State,
        optionTapped: @escaping () -> Void
    ) {
        self.option = option
        self.state = initialState
        self.optionTapped = optionTapped
        
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
        
        let backgroundConstraints = [
            self.backgroundView.topAnchor.constraint(equalTo: self.topAnchor),
            self.backgroundView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.backgroundView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.backgroundView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
        ]
        
        // MARK: Result Fill Bar
        
        self.resultFillBarWidthConstraint = self.resultFillBar.widthAnchor.constraint(equalToConstant: 0)
        let resultFillBarConstraints = [
            self.resultFillBarArea.topAnchor.constraint(equalTo: self.topAnchor),
            self.resultFillBarArea.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.resultFillBarArea.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.resultFillBarArea.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.resultFillBar.topAnchor.constraint(equalTo: self.resultFillBarArea.topAnchor),
            self.resultFillBar.bottomAnchor.constraint(equalTo: self.resultFillBarArea.bottomAnchor),
            self.resultFillBar.leadingAnchor.constraint(equalTo: self.resultFillBarArea.leadingAnchor),
            self.resultFillBarWidthConstraint!
        ]
        self.resultFillBar.backgroundColor = option.resultFillColor.opaque.uiColor
        
        // MARK: Result Percentage
        
        self.resultPercentageWidthConstraint = self.resultPercentage.widthAnchor.constraint(
            equalToConstant: 0
        )
        let percentageConstraints = [
            self.resultPercentage.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: OPTION_TEXT_SPACING * -1),
            self.resultPercentage.topAnchor.constraint(equalTo: self.topAnchor),
            self.resultPercentage.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.resultFillBarWidthConstraint!
        ]
        self.resultPercentage.textAlignment = .right
        // we want the content to expand out to the horizontal space permitted by the percentage view.
        self.answerTextView.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
        self.resultPercentage.font = option.text.font.bumpedForPercentageIndicator.uiFont
        self.resultPercentage.textColor = option.text.color.uiColor
        
        // MARK: Answer Text View
        
        let answerConstraints = [
            self.answerTextView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.answerTextView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: OPTION_TEXT_SPACING),
            self.answerTextView.trailingAnchor.constraint(equalTo: self.resultPercentage.leadingAnchor, constant: OPTION_TEXT_SPACING * -1)
        ]
        self.answerTextView.backgroundColor = .clear
        self.answerTextView.numberOfLines = 1
        self.answerTextView.attributedText = option.attributedText
        self.answerTextView.lineBreakMode = .byTruncatingTail
        
        // MARK: Container
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleOptionTapped))
       gestureRecognizer.numberOfTapsRequired = 1
       self.addGestureRecognizer(gestureRecognizer)
        
        let constraints = backgroundConstraints + resultFillBarConstraints + percentageConstraints + answerConstraints + [
            self.heightAnchor.constraint(equalToConstant: CGFloat(option.height))
        ]
        NSLayoutConstraint.activate(constraints)
        
        self.configureOpacity(opacity: option.opacity)
        self.clipsToBounds = true
        
        self.configureBackgroundColor(color: option.background.color, opacity: option.opacity)
        
        switch self.state {
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
        self.resultFillBarWidthConstraint?.isActive = false
        self.resultPercentageWidthConstraint!.constant = 0
        self.isUserInteractionEnabled = true
        self.percentageAnimationTimer?.invalidate()
        self.percentageAnimationTimer = nil
    }
    
    /// In lieu of a UIKit animation, we animate the percentage values with a manually managed timer.
    private var percentageAnimationTimer: Timer?
    
    /// Since percentages are animated manually with Timers rather than using UIKit animations, we have to manually interpolate from any prior value.
    private var previousPercentageProportion: Double = 0
    
    private func revealResultsState(animated: Bool, optionResults: OptionResults) {
        self.percentageAnimationTimer?.invalidate()
        self.percentageAnimationTimer = nil
        let animateFactor = Double(animated ? 1 : 0)
        
        UIView.animate(withDuration: RESULT_PERCENTAGE_REVEAL_TIME * animateFactor, delay: 0, options: [.curveEaseInOut], animations: {
            self.resultPercentage.alpha = 1.0
        })
        
        UIView.animate(withDuration: RESULT_FILL_BAR_REVEAL_TIME * animateFactor, delay: 0, options: [.curveEaseInOut], animations: {
            self.resultFillBarArea.alpha = CGFloat(self.option.resultFillColor.alpha)
        })
        
        self.resultFillBarWidthConstraint?.isActive = false
        self.resultFillBarWidthConstraint = self.resultFillBar.widthAnchor.constraint(equalTo: self.resultFillBarArea.widthAnchor, multiplier: CGFloat(optionResults.fraction))
        self.resultFillBarWidthConstraint?.isActive = true
        
        UIView.animate(withDuration: RESULT_FILL_BAR_FILL_TIME * animateFactor, delay: 0, options: [.curveEaseInOut], animations: {
            self.resultFillBarArea.layoutIfNeeded()
        })
        
        let percentageTextFont = self.option.text.font.bumpedForPercentageIndicator

        // expand the percentage view to accomodate all possible percentage values as we animate through them, to avoid any possible wobble in the layout.
        self.resultPercentageWidthConstraint?.constant = percentageTextFont.attributedText(forPlainText: "100%", color: self.option.text.color)?.boundingRect(with: .init(width: 1_000, height: 1_000), options: [], context: nil).width ?? CGFloat(0)
        
        let startTime = Date()
        let startProportion = self.previousPercentageProportion
        if animated && startProportion != optionResults.fraction {
            self.percentageAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true, block: { [weak self] timer in
                // TODO: calculate a "start position" from the current value on the constraint, in order for repeat calls to `revealResultsState` to properly animate through the percentages between the current value rather than just 0.
                let elapsed = Double(startTime.timeIntervalSinceNow) * -1
                let elapsedProportion = elapsed / RESULT_FILL_BAR_FILL_TIME
                if elapsedProportion > 1.0 {
                    self?.resultPercentage.text = String(format: "%d%%", optionResults.percentage)
                    timer.invalidate()
                    self?.percentageAnimationTimer = nil
                } else {
                    let percentage = (startProportion * 100).rounded(.down) + ((optionResults.fraction - startProportion) * 100).rounded(.down) * elapsedProportion
                    self?.resultPercentage.text = String(format: "%.0f%%", percentage)
                }
            })
        } else {
            self.resultPercentage.text = String(format: "%d%%", optionResults.percentage)
        }
        
        self.previousPercentageProportion = optionResults.fraction
        
        self.isUserInteractionEnabled = false
    }
    
    // MARK: Interaction
    
    @objc
    private func handleOptionTapped(_: UIGestureRecognizer) {
        os_log("OPTION TAPPED")
        self.optionTapped()
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Usage in XIB not supported.")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.configureBorder(border: option.border, constrainedByFrame: self.frame)
        // we defer configuring background image to here so that the layout has been calculated, and thus frame is available.
        self.backgroundView.configureAsBackgroundImage(background: option.background)
        self.resultFillBar.layoutIfNeeded()
    }
}

// MARK: Cell View

class TextPollCell: BlockCell {
    private let containerView = UIView()
    
    private var optionViews = [TextPollOptionView]()
    private var optionStack: UIStackView?
    
    override var content: UIView? {
        return containerView
    }
    
    private var questionView: PollQuestionView?
    private var pollSubscription: AnyObject?
    
    override func configure(with block: Block, for experience: Experience) {
        super.configure(with: block, for: experience)
     
        questionView?.removeFromSuperview()
        self.optionStack?.removeFromSuperview()
        
        // unsubscribe from existing poll subscription.
        self.pollSubscription = nil
        
        guard let textPollBlock = block as? TextPollBlock else {
            return
        }
        
        questionView = PollQuestionView(questionText: textPollBlock.textPoll.question)
        containerView.addSubview(questionView!)
        
        let questionConstraints = [
            questionView!.topAnchor.constraint(equalTo: containerView.topAnchor),
            questionView!.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            questionView!.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ]
        
        let (initialPollStatus, subscription) = PollsVotingService.shared.subscribeToUpdates(pollId: textPollBlock.pollId(containedBy: experience), givenCurrentOptionIds: textPollBlock.textPoll.votableOptionIds) { [weak self] newPollStatus in
            
            switch newPollStatus {
                case .answered(let resultsForOptions):
                let viewOptionStatuses = resultsForOptions.viewOptionStatuses
                self?.optionViews.forEach { (optionView) in
                    let optionId = optionView.optionId
                    guard let optionResults = viewOptionStatuses[optionId] else {
                        os_log("A result was not given for option: %s.  Did you remember to unsubscribe on recycle?", log: .rover, type: .error, optionId)
                        return
                    }
                    optionView.state = .answered(optionResults: optionResults)
                }

                case .waitingForAnswer:
                    self?.optionViews.forEach({ (optionView) in
                        optionView.state = .waitingForAnswer
                    })
            }
        }
        
        self.pollSubscription = subscription
        
        switch initialPollStatus {
            case .answered(let optionResults):
                let viewOptionStatuses = optionResults.viewOptionStatuses
                self.optionViews = textPollBlock.textPoll.options.map { option in
                    TextPollOptionView(option: option, initialState: .answered(optionResults: viewOptionStatuses[option.id]!)) {
                        PollsVotingService.shared.castVote(pollId: textPollBlock.pollId(containedBy: experience), optionId: option.id)
                    }
                }
            case .waitingForAnswer:
                self.optionViews = textPollBlock.textPoll.options.map { option in
                    TextPollOptionView(option: option, initialState: .waitingForAnswer) {
                        PollsVotingService.shared.castVote(pollId: textPollBlock.pollId(containedBy: experience), optionId: option.id)
                    }
                }
        }
        
        let verticalStack = UIStackView(arrangedSubviews: self.optionViews)
        verticalStack.translatesAutoresizingMaskIntoConstraints = false
        let verticalSpacing = CGFloat(self.optionViews.first?.topMargin ?? 0)
        verticalStack.axis = .vertical
        verticalStack.spacing = verticalSpacing
        
        containerView.addSubview(verticalStack)
        self.optionStack = verticalStack
        
        let stackConstraints = [
            verticalStack.topAnchor.constraint(equalTo: questionView!.bottomAnchor, constant: CGFloat(verticalSpacing)),
            verticalStack.leadingAnchor.constraint(equalTo: self.containerView.leadingAnchor),
            verticalStack.trailingAnchor.constraint(equalTo: self.containerView.trailingAnchor)
        ]
        
        NSLayoutConstraint.activate(questionConstraints + stackConstraints)
    }
}

// MARK: Measurement

extension TextPollBlock {
    func intrinsicHeight(blockWidth: CGFloat) -> CGFloat {
        let innerWidth = blockWidth - CGFloat(insets.left) - CGFloat(insets.right)
        
        let size = CGSize(width: innerWidth, height: CGFloat.greatestFiniteMagnitude)
        
        let questionAttributedText = self.textPoll.question.attributedText(forFormat: .plain)
        
        let questionHeight = questionAttributedText?.boundingRect(with: size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height ?? CGFloat(0)
        
        let optionsHeightAndSpacing = self.textPoll.options.flatMap { option in
            return [option.height, option.topMargin]
        }.reduce(0) { (accumulator, addend) in
            return accumulator + addend
        }
        
        return CGFloat(optionsHeightAndSpacing) + questionHeight + CGFloat(insets.top + insets.bottom)
    }
}

// MARK: Helpers

extension TextPollBlock.TextPoll.Option {
    var attributedText: NSAttributedString? {
        return self.text.attributedText(forFormat: .plain)
    }
}

private extension Dictionary where Key == String, Value == PollsVotingService.OptionStatus {
    var viewOptionStatuses: [String: TextPollOptionView.OptionResults] {
        let votesByOptionIds = self.mapValues { $0.voteCount }
        let totalVotes = votesByOptionIds.values.reduce(0, +)
        let roundedPercentagesByOptionIds = votesByOptionIds.percentagesWithDistributedRemainder()
        
        return self.mapValuesWithKey { (optionId, optionStatus) in
            let fraction = Double(optionStatus.voteCount) / Double(totalVotes)
            return TextPollOptionView.OptionResults(
                selected: optionStatus.selected,
                fraction: fraction,
                percentage: roundedPercentagesByOptionIds[optionId]!
            )
        }
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
