//
//  ImagePollCell.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-19.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import os
import UIKit

// MARK: Constants

private let OPTION_TEXT_HEIGHT = CGFloat(40)
private let OPTION_TEXT_SPACING = CGFloat(8)
private let RESULT_FILL_BAR_HEIGHT = CGFloat(8)
private let RESULT_FILL_BAR_HORIZONTAL_SPACING = CGFloat(4)
private let RESULT_FILL_BAR_VERTICAL_SPACING = CGFloat(8)
private let RESULT_PERCENTAGE_FONT_SIZE = CGFloat(16)
private let RESULT_REVEAL_TIME = 0.167 // (167 ms)
private let RESULT_FILL_BAR_FILL_TIME = 1.00  // (1 s)

// MARK: Option View

class ImagePollOptionView: UIView {
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
    
    public var leftMargin: Int {
        return self.option.leftMargin
    }
    
    public var optionId: String {
        return self.option.id
    }
    
    private let content = UIImageView()
    private let answerTextView = UILabel()
    
    /// This view introduces a 50% opacity layer on top of the image in the results state.
    private let resultFadeOverlay = UIView()
    private let resultPercentage = UILabel()

    private let resultFillBarArea = UIView()
    private let resultFillBar = UIView()
    private var resultFillBarWidthConstraint: NSLayoutConstraint?
    
    private let option: ImagePollBlock.ImagePoll.Option
    
    private let optionTapped: () -> Void
    
    init(
        option: ImagePollBlock.ImagePoll.Option,
        initialState: State,
        optionTapped: @escaping () -> Void
    ) {
        self.option = option
        self.state = initialState
        self.optionTapped = optionTapped
        super.init(frame: CGRect.zero)
        self.addSubview(self.content)
        self.addSubview(self.answerTextView)
        self.addSubview(self.resultFadeOverlay)
        self.addSubview(self.resultPercentage)
        self.addSubview(self.resultFillBarArea)
        self.resultFillBarArea.addSubview(self.resultFillBar)
        
        // MARK: Enable AutoLayout
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.content.translatesAutoresizingMaskIntoConstraints = false
        self.answerTextView.translatesAutoresizingMaskIntoConstraints = false
        self.resultFadeOverlay.translatesAutoresizingMaskIntoConstraints = false
        self.resultPercentage.translatesAutoresizingMaskIntoConstraints = false
        self.resultFillBarArea.translatesAutoresizingMaskIntoConstraints = false
        self.resultFillBar.translatesAutoresizingMaskIntoConstraints = false

        // MARK: Image Content
        
        // the image itself should be rendered as 1:1 tile.
        let contentConstraints = [
            self.content.heightAnchor.constraint(equalTo: self.widthAnchor),
            self.content.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.content.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.content.topAnchor.constraint(equalTo: self.topAnchor)
        ]
        
        // MARK: Answer/Caption Text View
        
        let answerConstraints = [
            self.answerTextView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: OPTION_TEXT_SPACING),
            self.answerTextView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: OPTION_TEXT_SPACING * -1),
            self.answerTextView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: OPTION_TEXT_SPACING * -1 ),
            self.answerTextView.heightAnchor.constraint(equalToConstant: OPTION_TEXT_HEIGHT - OPTION_TEXT_SPACING * 2),
            self.answerTextView.topAnchor.constraint(equalTo: self.content.bottomAnchor, constant: OPTION_TEXT_SPACING)
        ]
        self.answerTextView.backgroundColor = .clear
        self.answerTextView.numberOfLines = 1
        self.answerTextView.attributedText = option.attributedText
        self.answerTextView.lineBreakMode = .byTruncatingTail
        self.answerTextView.backgroundColor = .clear
        self.answerTextView.textAlignment = .center
        
        // MARK: Results Fade Overlay
        
        let fadeOverlayConstraints = [
            self.resultFadeOverlay.topAnchor.constraint(equalTo: self.content.topAnchor),
            self.resultFadeOverlay.leadingAnchor.constraint(equalTo: self.content.leadingAnchor),
            self.resultFadeOverlay.trailingAnchor.constraint(equalTo: self.content.trailingAnchor),
            self.resultFadeOverlay.bottomAnchor.constraint(equalTo: self.content.bottomAnchor)
        ]
        self.resultFadeOverlay.backgroundColor = .black
        self.resultFadeOverlay.alpha = 0.0
        
        // MARK: Result Fill Bar
        
        self.resultFillBarWidthConstraint = self.resultFillBar.widthAnchor.constraint(equalToConstant: 0)
        let resultFillBarConstraints = [
            self.resultFillBarArea.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: RESULT_FILL_BAR_HORIZONTAL_SPACING),
            self.resultFillBarArea.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: RESULT_FILL_BAR_HORIZONTAL_SPACING * -1),
            self.resultFillBarArea.bottomAnchor.constraint(equalTo: self.content.bottomAnchor, constant: CGFloat(RESULT_FILL_BAR_VERTICAL_SPACING * -1)),
            self.resultFillBarArea.heightAnchor.constraint(equalToConstant: RESULT_FILL_BAR_HEIGHT),
            self.resultFillBar.topAnchor.constraint(equalTo: self.resultFillBarArea.topAnchor),
            self.resultFillBar.bottomAnchor.constraint(equalTo: self.resultFillBarArea.bottomAnchor),
            self.resultFillBar.leadingAnchor.constraint(equalTo: self.resultFillBarArea.leadingAnchor),
            self.resultFillBarWidthConstraint!
        ]
        self.resultFillBarArea.clipsToBounds = true
        self.resultFillBarArea.layer.cornerRadius = RESULT_FILL_BAR_HEIGHT / 2
        self.resultFillBarArea.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        self.resultFillBar.backgroundColor = option.resultFillColor.uiColor
        self.resultFillBar.layer.cornerRadius = RESULT_FILL_BAR_HEIGHT / 2
        self.resultFillBar.clipsToBounds = true
        
        let resultPercentageConstraints = [
            self.resultPercentage.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            self.resultPercentage.bottomAnchor.constraint(equalTo: self.resultFillBarArea.topAnchor, constant: RESULT_FILL_BAR_VERTICAL_SPACING * -1)
        ]
        self.resultPercentage.font = UIFont.systemFont(ofSize: RESULT_PERCENTAGE_FONT_SIZE, weight: .medium)
        self.resultPercentage.textColor = .white
        
        // MARK: Container
        
        self.configureOpacity(opacity: option.opacity)
        self.clipsToBounds = true

        self.backgroundColor = option.background.color.uiColor
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleOptionTapped))
        gestureRecognizer.numberOfTapsRequired = 1
        self.addGestureRecognizer(gestureRecognizer)
        
        NSLayoutConstraint.activate(contentConstraints + answerConstraints + fadeOverlayConstraints + resultFillBarConstraints + resultPercentageConstraints)
    }
    
    // MARK: View States and Animation
    
    private func revealQuestionState() {
        self.resultPercentage.alpha = 0.0
        self.resultFillBarArea.alpha = 0.0
        self.resultFadeOverlay.alpha = 0.0
        self.resultFillBarWidthConstraint!.constant = 0
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
        self.resultPercentage.text = String(format: "%.0f %%", optionResults.fraction * 100)
        
        let animateFactor = Double(animated ? 1 : 0)
        
        UIView.animate(withDuration: RESULT_REVEAL_TIME * animateFactor, delay: 0.0, options: [.curveEaseInOut], animations: {
            self.resultPercentage.alpha = 1.0
            self.resultFillBarArea.alpha = 1.0
            self.resultFadeOverlay.alpha = 0.3
        })
        
        let width = self.resultFillBarArea.frame.width * CGFloat(optionResults.fraction)
        self.resultFillBarWidthConstraint!.constant = width
        if animated {
            UIView.animate(withDuration: RESULT_FILL_BAR_FILL_TIME, delay: 0.0, options: [.curveEaseInOut], animations: {
                self.resultFillBarArea.layoutIfNeeded()
            })
        } else {
            self.resultFillBarArea.layoutIfNeeded()
        }
        
        let startTime = Date()
        let startProportion = self.previousPercentageProportion
        if animated && startProportion != optionResults.fraction {
            self.percentageAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.0167, repeats: true, block: { [weak self] timer in
                let elapsed = Double(startTime.timeIntervalSinceNow) * -1
                let elapsedProportion = elapsed / RESULT_FILL_BAR_FILL_TIME
                if elapsedProportion >= 1.0 {
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
        self.content.configureAsFilledImage(image: self.option.image)
        
        switch self.state {
        case .waitingForAnswer:
            revealQuestionState()
        case .answered(let optionResults):
            revealResultsState(animated: false, optionResults: optionResults)
        }
    }
}

// MARK: Cell View

class ImagePollCell: BlockCell {
    /// a simple container view to the relatively complex layout of the text poll.
    private let containerView = UIView()
    
    private var optionViews = [ImagePollOptionView]()
    private var optionStack: UIStackView?
    
    override var content: UIView? {
        return containerView
    }
    
    private var questionView: PollQuestionView?

    
    private var pollSubscription: AnyObject?
    
    override func configure(with block: Block, for experience: Experience) {
        super.configure(with: block, for: experience)
        
        self.questionView?.removeFromSuperview()
        self.optionStack?.removeFromSuperview()
        
        // unsubscribe from existing poll subscription.
        self.pollSubscription = nil
        
        guard let imagePollBlock = block as? ImagePollBlock else {
            return
        }
        
        self.questionView = PollQuestionView(questionText: imagePollBlock.imagePoll.question)
        self.containerView.addSubview(questionView!)
        let questionConstraints = [
            self.questionView!.topAnchor.constraint(equalTo: containerView.topAnchor),
            self.questionView!.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            self.questionView!.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ]
        
        let (initialPollStatus, subscription) = PollsVotingService.shared.subscribeToUpdates(pollId: imagePollBlock.pollId(containedBy: experience), givenCurrentOptionIds: imagePollBlock.imagePoll.votableOptionIds) { [weak self] newPollStatus in
            
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
                self.optionViews = imagePollBlock.imagePoll.options.map { option in
                    ImagePollOptionView(option: option, initialState: .answered(optionResults: viewOptionStatuses[option.id]!)) {
                        PollsVotingService.shared.castVote(pollId: imagePollBlock.pollId(containedBy: experience), optionId: option.id)
                    }
                }
            case .waitingForAnswer:
                self.optionViews = imagePollBlock.imagePoll.options.map { option in
                    ImagePollOptionView(option: option, initialState: .waitingForAnswer) {
                        PollsVotingService.shared.castVote(pollId: imagePollBlock.pollId(containedBy: experience), optionId: option.id)
                    }
                }
        }
        
        // we render the poll options in two columns, regardless of device size.  so pair them off.
        let optionViewPairs = optionViews.tuples
        
        let verticalSpacing = CGFloat((imagePollBlock.imagePoll.options.first?.topMargin) ?? 0)
        let verticalStack = UIStackView(arrangedSubviews: optionViewPairs.map({ (leftOption, rightOption) in
            let row = UIStackView(arrangedSubviews: [leftOption, rightOption])
            row.axis = .horizontal
            row.spacing = CGFloat(rightOption.leftMargin) / 2
            row.translatesAutoresizingMaskIntoConstraints = false
            return row
        }))
        verticalStack.translatesAutoresizingMaskIntoConstraints = false
        verticalStack.axis = .vertical
        verticalStack.spacing = verticalSpacing / 2.0
        self.containerView.addSubview(verticalStack)
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

extension ImagePollBlock {
    func intrinisicHeight(blockWidth: CGFloat) -> CGFloat {
        let innerWidth = blockWidth - CGFloat(insets.left) - CGFloat(insets.right)
        
        let size = CGSize(width: innerWidth, height: CGFloat.greatestFiniteMagnitude)
        
        let questionAttributedText = self.imagePoll.question.attributedText(forFormat: .plain)
        
        let questionHeight = questionAttributedText?.boundingRect(with: size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height ?? CGFloat(0)
        
        let optionsHeightAndSpacing = self.imagePoll.options.tuples.map { (firstOption, secondOption) in
            let horizontalSpacing = CGFloat(secondOption.leftMargin)
            let optionTextHeight = OPTION_TEXT_HEIGHT
            let verticalSpacing = CGFloat(max(firstOption.topMargin, secondOption.topMargin))
            
            let optionImageHeight = (blockWidth - horizontalSpacing) / 2
            return verticalSpacing + optionTextHeight + optionImageHeight
        }.reduce(CGFloat(0)) { (accumulator, addend) in
            return accumulator + addend
        }
        
        return optionsHeightAndSpacing + questionHeight + CGFloat(insets.top + insets.bottom)
    }
}

// MARK: Helpers

extension Array {
    /// Pair off a set of two items in sequence in the array.
    fileprivate var tuples: [(Element, Element)] {
        var optionPairs = [(Element, Element)]()
        for optionIndex in 0..<self.count {
            if optionIndex % 2 == 1 {
                optionPairs.append((self[optionIndex - 1], self[optionIndex]))
            }
        }
        return optionPairs
    }
}

private extension UIImageView {
    func configureAsFilledImage(image: Image, checkStillMatches: @escaping () -> Bool = { true }) {
        // Reset any existing background image
        self.alpha = 0.0
        self.image = nil
    
        self.contentMode = .scaleAspectFill
        
        if let image = ImageStore.shared.image(for: image, filledInFrame: self.frame) {
            self.image = image
            self.alpha = 1.0
        } else {
            let originalFrame = self.frame
            ImageStore.shared.fetchImage(for: image, filledInFrame: self.frame) { [weak self] image in
                guard let image = image, checkStillMatches(), self?.frame == originalFrame else {
                    return
                }
                
                self?.image = image
                
                UIView.animate(withDuration: 0.25) {
                    self?.alpha = 1.0
                }
            }
        }
    }
}

private extension ImagePollBlock.ImagePoll.Option {
    var attributedText: NSAttributedString? {
        return self.text.attributedText(forFormat: .plain)
    }
}

private extension Dictionary where Key == String, Value == PollsVotingService.OptionStatus {
    var viewOptionStatuses: [String: ImagePollOptionView.OptionResults] {
        let votesByOptionIds = self.mapValues { $0.voteCount }
        let totalVotes = votesByOptionIds.values.reduce(0, +)
        let roundedPercentagesByOptionIds = votesByOptionIds.percentagesWithDistributedRemainder()
        
        return self.mapValuesWithKey { (optionId, optionStatus) in
            let fraction = Double(optionStatus.voteCount) / Double(totalVotes)
            return ImagePollOptionView.OptionResults(
                selected: optionStatus.selected,
                fraction: fraction,
                percentage: roundedPercentagesByOptionIds[optionId]!
            )
        }
    }
}
