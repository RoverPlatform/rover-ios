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
        let fraction: Float
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
    
    private let content = UIImageView()
    private let answerTextView = UILabel()
    
    /// This view introduces a 50% opacity layer on top of the image in the results state.
    private let resultFadeOverlay = UIView()
    private let resultPercentage = UILabel()

    private let resultFillBarArea = UIView()
    private let resultFillBar = UIView()
    private var resultFillBarWidthConstraint: NSLayoutConstraint?
    
    private let option: ImagePollBlock.ImagePoll.Option
    
    init(
        option: ImagePollBlock.ImagePoll.Option,
        initialState: State
    ) {
        self.option = option
        self.state = initialState
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
        self.content.heightAnchor.constraint(equalTo: self.widthAnchor).isActive = true
        
        self.content.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        self.content.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        self.content.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        
        // MARK: Answer/Caption Text View
        
        self.answerTextView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: OPTION_TEXT_SPACING).isActive = true
        self.answerTextView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: OPTION_TEXT_SPACING * -1).isActive = true
        self.answerTextView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: OPTION_TEXT_SPACING * -1 ).isActive = true
        self.answerTextView.heightAnchor.constraint(equalToConstant: OPTION_TEXT_HEIGHT - OPTION_TEXT_SPACING * 2).isActive = true
        self.answerTextView.topAnchor.constraint(equalTo: self.content.bottomAnchor, constant: OPTION_TEXT_SPACING).isActive = true
        
        self.answerTextView.backgroundColor = .clear
        self.answerTextView.numberOfLines = 1
        self.answerTextView.attributedText = option.attributedText
        self.answerTextView.lineBreakMode = .byTruncatingTail
        self.answerTextView.backgroundColor = .clear
        self.answerTextView.textAlignment = .center
        
        // MARK: Results Fade Overlay
        
        self.resultFadeOverlay.topAnchor.constraint(equalTo: self.content.topAnchor).isActive = true
        self.resultFadeOverlay.leadingAnchor.constraint(equalTo: self.content.leadingAnchor).isActive = true
        self.resultFadeOverlay.trailingAnchor.constraint(equalTo: self.content.trailingAnchor).isActive = true
        self.resultFadeOverlay.bottomAnchor.constraint(equalTo: self.content.bottomAnchor).isActive = true
        self.resultFadeOverlay.backgroundColor = .black
        self.resultFadeOverlay.alpha = 0.0
        
        // MARK: Result Fill Bar
        
        self.resultFillBarArea.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: RESULT_FILL_BAR_HORIZONTAL_SPACING).isActive = true
        self.resultFillBarArea.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: RESULT_FILL_BAR_HORIZONTAL_SPACING * -1).isActive = true
        self.resultFillBarArea.bottomAnchor.constraint(equalTo: self.content.bottomAnchor, constant: CGFloat(RESULT_FILL_BAR_VERTICAL_SPACING * -1)).isActive = true
        self.resultFillBarArea.heightAnchor.constraint(equalToConstant: RESULT_FILL_BAR_HEIGHT).isActive = true
        self.resultFillBar.topAnchor.constraint(equalTo: self.resultFillBarArea.topAnchor).isActive = true
        self.resultFillBar.bottomAnchor.constraint(equalTo: self.resultFillBarArea.bottomAnchor).isActive = true
        self.resultFillBar.leadingAnchor.constraint(equalTo: self.resultFillBarArea.leadingAnchor).isActive = true
        self.resultFillBarWidthConstraint = self.resultFillBar.widthAnchor.constraint(equalToConstant: 0)
        self.resultFillBarWidthConstraint!.isActive = true
        self.resultFillBarArea.clipsToBounds = true
        self.resultFillBarArea.layer.cornerRadius = RESULT_FILL_BAR_HEIGHT / 2
        self.resultFillBarArea.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        self.resultFillBar.backgroundColor = option.resultFillColor.uiColor
        
        self.resultPercentage.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        self.resultPercentage.bottomAnchor.constraint(equalTo: self.resultFillBarArea.topAnchor, constant: RESULT_FILL_BAR_VERTICAL_SPACING * -1).isActive = true
        self.resultPercentage.font = UIFont.systemFont(ofSize: RESULT_PERCENTAGE_FONT_SIZE, weight: .medium)
        self.resultPercentage.textColor = .white
        
        // MARK: Container
        
        self.configureOpacity(opacity: option.opacity)
        self.clipsToBounds = true
        self.configureBorder(border: option.border, constrainedByFrame: nil)
        self.backgroundColor = option.background.color.uiColor
        
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
        self.resultFadeOverlay.alpha = 0.0
        self.resultFillBarWidthConstraint!.constant = 0
    }
    
    private var percentageAnimationTimer: Timer?
    private func revealResultsState(animated: Bool, optionResults: OptionResults) {
        self.resultPercentage.text = String(format: "%.0f %%", optionResults.fraction * 100)
        
        UIView.animate(withDuration: RESULT_REVEAL_TIME, delay: 0.0, options: [.curveEaseInOut], animations: {
            self.resultPercentage.alpha = 1.0
            self.resultFillBarArea.alpha = 1.0
            self.resultFadeOverlay.alpha = 0.3
        })
        
        let width = self.resultFillBarArea.frame.width * CGFloat(optionResults.fraction)
        self.resultFillBarWidthConstraint!.constant = width
        UIView.animate(withDuration: RESULT_FILL_BAR_FILL_TIME, delay: 0.0, options: [.curveEaseInOut], animations: {
            self.resultFillBarArea.layoutIfNeeded()
        })
        
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
        self.content.configureAsFilledImage(image: self.option.image)
    }
}

// MARK: Cell View

class ImagePollCell: BlockCell {
    /// a simple container view to the relatively complex layout of the text poll.
    private let containerView = UIView()
    
    private var optionViews = [ImagePollOptionView]()
    
    override var content: UIView? {
        return containerView
    }
    
    private var questionView: PollQuestionView?
    
    private var temporaryTapDemoTimer: Timer?
    
    override func configure(with block: Block) {
        super.configure(with: block)
        
        self.questionView?.removeFromSuperview()
        self.optionViews.forEach { $0.removeFromSuperview() }
        
        guard let imagePollBlock = block as? ImagePollBlock else {
            return
        }
        
        self.questionView = PollQuestionView(questionText: imagePollBlock.imagePoll.question)
        self.containerView.addSubview(questionView!)
        self.questionView?.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
        self.questionView?.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
        self.questionView?.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        self.optionViews = imagePollBlock.imagePoll.options.map { option in
            // TODO: get initial state synchronously from the local VotingService.
            ImagePollOptionView(option: option, initialState: .waitingForAnswer)
        }
        
        // we render the poll options in two columns, regardless of device size.  so pair them off.
        let optionViewPairs = optionViews.tuples
        
        for pairIndex in 0..<optionViewPairs.count {
            let (firstView, secondView) = optionViewPairs[pairIndex]
            self.containerView.addSubview(firstView)
            self.containerView.addSubview(secondView)
            if pairIndex == 0 {
                // first row
                firstView.topAnchor.constraint(equalTo: questionView!.bottomAnchor, constant: CGFloat(firstView.topMargin)).isActive = true
                secondView.topAnchor.constraint(equalTo: questionView!.bottomAnchor, constant: CGFloat(secondView.topMargin)).isActive = true
            } else {
                // subsequent rows stack on one another
                let (previousFirstView, previousSecondView) = optionViewPairs[pairIndex - 1]
                
                firstView.topAnchor.constraint(equalTo: previousFirstView.bottomAnchor, constant: CGFloat(firstView.topMargin)).isActive = true
                secondView.topAnchor.constraint(equalTo: previousSecondView.bottomAnchor, constant: CGFloat(secondView.topMargin)).isActive = true
            }
            
            firstView.leadingAnchor.constraint(equalTo: self.containerView.leadingAnchor).isActive = true
            
            // the leftMargin value on the right hand column of image options defines the space between the two. So we'll space each column from the center line by half that amount.
            let centerSpacing = CGFloat(secondView.leftMargin) / 2.0
            firstView.trailingAnchor.constraint(equalTo: self.containerView.centerXAnchor, constant: -1 * centerSpacing).isActive = true
            secondView.leadingAnchor.constraint(equalTo: self.containerView.centerXAnchor, constant: centerSpacing).isActive = true
            secondView.trailingAnchor.constraint(equalTo: self.containerView.trailingAnchor).isActive = true
        }
        
        // TODO: A stand-in for the user tapping.
        self.temporaryTapDemoTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in
            self.optionViews.forEach { (optionView) in
                optionView.state = .answered(optionResults: ImagePollOptionView.OptionResults.init(selected: false, fraction: 0.67))
            }
        }

        // TODO: A stand-in for the user tapping.
        self.temporaryTapDemoTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
            self.optionViews.forEach { (optionView) in
                optionView.state = .answered(optionResults: ImagePollOptionView.OptionResults.init(selected: false, fraction: 0.25))
            }
        }
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

extension UIImageView {
    fileprivate func configureAsFilledImage(image: Image, checkStillMatches: @escaping () -> Bool = { true }) {
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

extension ImagePollBlock.ImagePoll.Option {
    var attributedText: NSAttributedString? {
        return self.text.attributedText(forFormat: .plain)
    }
}
