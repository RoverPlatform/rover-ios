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
private let INDICATOR_BULLET_CHARACTER = "•"

// MARK: Option View

class ImagePollOptionView: UIView {
//    var state: State {
//        didSet {
//            switch state {
//            case .waitingForAnswer:
//                revealQuestionState()
//            case .answered(let optionResults):
//                revealResultsState(animated: true, optionResults: optionResults)
//            }
//        }
//    }
    
    struct OptionResults {
        let selected: Bool
        let fraction: Double
        let percentage: Int
    }
    
    enum State {
        case waitingForAnswer
        case answered(optionResults: OptionResults)
    }
    
    var topMargin: Int {
        return self.option.topMargin
    }
    
    var leftMargin: Int {
        return self.option.leftMargin
    }
    
    var optionID: String {
        return self.option.id
    }
    
    private let content = UIImageView()
    private let answerTextView = UILabel()
    private let indicator = UILabel()
    /// This view introduces a 50% opacity layer on top of the image in the results state.
    private let indicatorAndAnswer: UIStackView
    private let resultFadeOverlay = UIView()
    private let resultPercentage = UILabel()

    private let resultFillBarArea = UIView()
    private let resultFillBar = UIView()
    private var resultFillBarWidthConstraint: NSLayoutConstraint?
    
    private let option: ImagePollBlock.ImagePoll.Option
    
    private let optionTapped: () -> Void
    
    init(
        option: ImagePollBlock.ImagePoll.Option,
        optionTapped: @escaping () -> Void
    ) {
        self.option = option
        self.optionTapped = optionTapped
        self.indicatorAndAnswer = UIStackView(arrangedSubviews: [
            answerTextView,
            indicator
        ])
        super.init(frame: CGRect.zero)
        self.addSubview(self.content)
        self.addSubview(self.indicatorAndAnswer)
        self.addSubview(self.resultFadeOverlay)
        self.addSubview(self.resultPercentage)
        self.addSubview(self.resultFillBarArea)
        self.resultFillBarArea.addSubview(self.resultFillBar)
        
        // MARK: Enable AutoLayout
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.content.translatesAutoresizingMaskIntoConstraints = false
        self.indicatorAndAnswer.translatesAutoresizingMaskIntoConstraints = false
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

        self.answerTextView.backgroundColor = .clear
        self.answerTextView.numberOfLines = 1
        self.answerTextView.attributedText = option.attributedText
        self.answerTextView.lineBreakMode = .byTruncatingTail
        self.answerTextView.backgroundColor = .clear
        self.answerTextView.textAlignment = .center
        
        // MARK: Indicator
        self.indicator.text = INDICATOR_BULLET_CHARACTER
        self.indicator.font = option.text.font.uiFont
        self.indicator.textColor = option.text.color.uiColor
        
        let answerAndIndicatorConstraints = [
            self.indicatorAndAnswer.leadingAnchor.constraint(greaterThanOrEqualTo: self.leadingAnchor, constant: OPTION_TEXT_SPACING),
            self.indicatorAndAnswer.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor, constant: OPTION_TEXT_SPACING * -1),
            self.indicatorAndAnswer.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: OPTION_TEXT_SPACING * -1 ),
            self.indicatorAndAnswer.heightAnchor.constraint(equalToConstant: OPTION_TEXT_HEIGHT - OPTION_TEXT_SPACING * 2),
            self.indicatorAndAnswer.topAnchor.constraint(equalTo: self.content.bottomAnchor, constant: OPTION_TEXT_SPACING),
            self.indicatorAndAnswer.centerXAnchor.constraint(equalTo: self.centerXAnchor)
        ]
        
        self.indicatorAndAnswer.axis = .horizontal
        self.indicatorAndAnswer.alignment = .center
        self.indicatorAndAnswer.spacing = OPTION_TEXT_SPACING
        
        self.indicator.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        self.answerTextView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

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
        
        let resultFillBarConstraints = [
            self.resultFillBarArea.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: RESULT_FILL_BAR_HORIZONTAL_SPACING),
            self.resultFillBarArea.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: RESULT_FILL_BAR_HORIZONTAL_SPACING * -1),
            self.resultFillBarArea.bottomAnchor.constraint(equalTo: self.content.bottomAnchor, constant: CGFloat(RESULT_FILL_BAR_VERTICAL_SPACING * -1)),
            self.resultFillBarArea.heightAnchor.constraint(equalToConstant: RESULT_FILL_BAR_HEIGHT),
            self.resultFillBar.topAnchor.constraint(equalTo: self.resultFillBarArea.topAnchor),
            self.resultFillBar.bottomAnchor.constraint(equalTo: self.resultFillBarArea.bottomAnchor),
            self.resultFillBar.leadingAnchor.constraint(equalTo: self.resultFillBarArea.leadingAnchor)
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
        
        NSLayoutConstraint.activate(contentConstraints + fadeOverlayConstraints + answerAndIndicatorConstraints + resultFillBarConstraints + resultPercentageConstraints)
    }
    
    // MARK: View States and Animation
    
    func revealQuestionState() {
        self.resultPercentage.alpha = 0.0
        self.resultFillBarArea.alpha = 0.0
        self.resultFadeOverlay.alpha = 0.0
        self.resultFillBarWidthConstraint?.isActive = false
        self.isUserInteractionEnabled = true
        self.percentageAnimationTimer?.invalidate()
        self.percentageAnimationTimer = nil
        self.indicator.isHidden = true
    }
    
    /// In lieu of a UIKit animation, we animate the percentage values with a manually managed timer.
    private var percentageAnimationTimer: Timer?
    
    /// Since percentages are animated manually with Timers rather than using UIKit animations, we have to manually interpolate from any prior value.
    private var previousPercentageProportion: Double = 0
    
    func revealResultsState(animated: Bool, optionResults: OptionResults) {
        self.percentageAnimationTimer?.invalidate()
        self.percentageAnimationTimer = nil
        self.resultPercentage.text = String(format: "%.0f %%", optionResults.fraction * 100)
        
        self.indicator.isHidden = !optionResults.selected
        
        let animateFactor = Double(animated ? 1 : 0)
        
        UIView.animate(withDuration: RESULT_REVEAL_TIME * animateFactor, delay: 0.0, options: [.curveEaseInOut], animations: {
            self.resultPercentage.alpha = 1.0
            self.resultFillBarArea.alpha = 1.0
            self.resultFadeOverlay.alpha = 0.3
        })
        
        self.resultFillBarWidthConstraint?.isActive = false
        self.resultFillBarWidthConstraint = self.resultFillBar.widthAnchor.constraint(equalTo: self.resultFillBarArea.widthAnchor, multiplier: CGFloat(optionResults.fraction))
        self.resultFillBarWidthConstraint?.isActive = true
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
        os_log("Image poll option tapped.", log: .rover, type: .debug)
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
    }
}

/// Poll results, mapping Option IDs -> Vote Counts.
typealias PollResults = [String: Int]

/// An option voted for by the user, the Option ID.
typealias PollAnswer = String

// MARK: Cell View

class ImagePollCell: BlockCell {
    /// This delegate is informed of a poll option being tapped.
    weak var delegate: ImagePollCellDelegate?
    
    var experienceID: String?
        
    private let urlSession = URLSession.shared
    
    /// Drive possible state transitions as required by user input in the form of a tap (meant as a vote) on a given option.
    private func handleOptionTapped(imagePollBlock: ImagePollBlock, for optionID: String) {
        switch self.state {
        case .initialState:
            self.state = .pollAnswered(myAnswer: optionID)
        case let .resultsSeeded(initialResults):
            self.state = .submittingAnswer(myAnswer: optionID, initialResults: initialResults)
        default:
            os_log("Vote attempt landed, but not currently in correct state to accept it.", log: .rover, type: .fault)
            return
        }
    }
    
    // MARK: View Hierarchy
    
    private func killUi() {
        self.questionView?.removeFromSuperview()
        self.optionStack?.removeFromSuperview()
    }
    
    private func buildUiForPoll(imagePollBlock: ImagePollBlock) {
        self.questionView = PollQuestionView(questionText: imagePollBlock.imagePoll.question)
        self.containerView.addSubview(questionView!)
        let questionConstraints = [
            self.questionView!.topAnchor.constraint(equalTo: containerView.topAnchor),
            self.questionView!.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            self.questionView!.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ]
                
        self.optionViews = imagePollBlock.imagePoll.options.map { option in
            ImagePollOptionView(option: option) { [weak self] in
                guard let self = self else {
                    return
                }
                
                self.handleOptionTapped(imagePollBlock: imagePollBlock, for: option.id)
            }
        }
        
        // we render the poll options in two columns, regardless of device size.  so pair them off.
        let optionViewPairs = optionViews.tuples
        
        let verticalSpacing = CGFloat((imagePollBlock.imagePoll.options.first?.topMargin) ?? 0)
        let verticalStack = UIStackView(arrangedSubviews: optionViewPairs.map({ (leftOption, rightOption) in
            let row = UIStackView(arrangedSubviews: [leftOption, rightOption])
            row.axis = .horizontal
            row.spacing = CGFloat(rightOption.leftMargin)
            row.translatesAutoresizingMaskIntoConstraints = false
            return row
        }))
        verticalStack.translatesAutoresizingMaskIntoConstraints = false
        verticalStack.axis = .vertical
        verticalStack.spacing = verticalSpacing
        self.containerView.addSubview(verticalStack)
        self.optionStack = verticalStack
        
        let stackConstraints = [
            verticalStack.topAnchor.constraint(equalTo: questionView!.bottomAnchor, constant: CGFloat(verticalSpacing)),
            verticalStack.leadingAnchor.constraint(equalTo: self.containerView.leadingAnchor),
            verticalStack.trailingAnchor.constraint(equalTo: self.containerView.trailingAnchor)
        ]

        NSLayoutConstraint.activate(questionConstraints + stackConstraints)
    }
    
    // MARK: State Machine

    // TODO: implement non-volatile state restore for State.
    
    private indirect enum PollState: Codable {
        private enum CodingKeys: String, CodingKey {
            case typeName
            case initialResults
            case myAnswer
            case currentResults
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeName = try container.decode(String.self, forKey: .typeName)
            switch typeName {
            case "unbound":
                self = .unbound
            case "initialState":
                self = .initialState
            case "resultsSeeded":
                let initialResults = try container.decode(PollResults.self, forKey: .initialResults)
                self = .resultsSeeded(initialResults: initialResults)
            case "pollAnswered":
                let myAnswer = try container.decode(PollAnswer.self, forKey: .myAnswer)
                self = .pollAnswered(myAnswer: myAnswer)
            case "submittingAnswer":
                let myAnswer = try container.decode(PollAnswer.self, forKey: .myAnswer)
                let initialResults = try container.decode(PollResults.self, forKey: .initialResults)
                self = .submittingAnswer(myAnswer: myAnswer, initialResults: initialResults)
            case "refreshingResults":
                let myAnswer = try container.decode(PollAnswer.self, forKey: .myAnswer)
                let currentResults = try container.decode(PollResults.self, forKey: .currentResults)
                self = .refreshingResults(myAnswer: myAnswer, currentResults: currentResults)
            default:
                throw DecodingError.dataCorruptedError(forKey: .typeName, in: container, debugDescription: "Invalid value: \(typeName)")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .initialState:
                try container.encode("initialState", forKey: .typeName)
            case let .resultsSeeded(initialResults):
                try container.encode("resultsSeeded", forKey: .typeName)
                try container.encode(initialResults, forKey: .initialResults)
            case let .pollAnswered(myAnswer):
                try container.encode("pollAnswered", forKey: .typeName)
                try container.encode(myAnswer, forKey: .myAnswer)
            case let .submittingAnswer(myAnswer, initialResults):
                try container.encode("submittingAnswer", forKey: .typeName)
                try container.encode(myAnswer, forKey: .myAnswer)
                try container.encode(initialResults, forKey: .initialResults)
            case let .refreshingResults(myAnswer, currentResults):
                try container.encode("refreshingResults", forKey: .typeName)
                try container.encode(myAnswer, forKey: .myAnswer)
                try container.encode(currentResults, forKey: .currentResults)
            case .restoreTo:
                throw EncodingError.invalidValue(self, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Persisting a .restoreTo value is not permitted."))
            default:
                throw EncodingError.invalidValue(self, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "No support for encoding value \(self)"))
            }
        }
        
        var name: String {
            switch self {
            case .unbound:
                return "unbound"
            case .initialState:
                return "initialState"
            case .resultsSeeded:
                return "resultsSeeded"
            case .submittingAnswer:
                return "submittingAnswer"
            case .refreshingResults:
                return "refreshingResults"
            case .restoreTo:
                return "restoreTo"
            case .pollAnswered:
                return "pollAnswered"
            }
        }
        
        case unbound
        case initialState
        case resultsSeeded(initialResults: PollResults)
        case pollAnswered(myAnswer: PollAnswer)
        case submittingAnswer(myAnswer: PollAnswer, initialResults: PollResults)
        case refreshingResults(myAnswer: PollAnswer, currentResults: PollResults)
        case restoreTo(state: PollState)
    }
    
    private func canTransition(from currentState: PollState, to newState: PollState) -> Bool {
        switch (currentState, newState) {
        case(.unbound, .initialState):
            return true
        case(.unbound, .restoreTo):
            return true
        case (.initialState, .resultsSeeded):
            return true
        case (.initialState, .pollAnswered):
            return true
        case (.resultsSeeded, .submittingAnswer):
            return true
        case (.pollAnswered, .submittingAnswer):
            return true
        case (.submittingAnswer, .refreshingResults):
            return true
        case (.refreshingResults, .refreshingResults):
            return true
        default:
            switch currentState {
                // allow restoreTo to transition to any state except for pollAnswered.
                case let .restoreTo(newState):
                       // .restoreTo is a special case.  It allows you to restore to all states except for pollAnswered (because that one expects a background side effect to be running).
                       switch newState {
                       case .pollAnswered:
                           return false
                       default:
                           return true
                       }
            default:
                switch newState {
                  // allow any state to transition back to unbound.
                  case .unbound:
                      return true
                  default:
                      return false
                  }
            }
        }
    }
    
    private var state: PollState = .unbound {
        willSet {
            assert(canTransition(from: state, to: newValue), "Invalid state transition from \(state.name) to \(state.name)!")
            os_log("Poll block transitioning from %s state to %s.", state.name, newValue.name)
        }
        
        didSet {
            // results should only be animated if we are not restoring.
            let shouldAnimateResults: Bool
            switch oldValue {
            case .restoreTo:
                shouldAnimateResults = false
            default:
                shouldAnimateResults = true
            }
            
            
            switch state {
            case .unbound:
                killUi()
                
                // do not allow the state saving logic below to operate, because without being bound to a poll we aren't able to persist anything on its behalf.
                return
            case .initialState:
                killUi()
                // Start loading initial results.
                // Present UI to allow user to select an answer.
                // If results load before users selects an answer, transition to .resultsSeeded
                // If user selects answer before initial results load, transition to .pollAnswered
                
                guard let imagePollBlock = self.block as? ImagePollBlock else {
                    os_log("Transitioned into .initialState state without the block being configured.")
                    return
                }

                guard let experienceID = self.experienceID else {
                    os_log("Attempt to configure poll block cell before informing it of the containing experience. Reverting to unbound.", log: .rover, type: .error)
                    state = .unbound
                    return
                }
            
                buildUiForPoll(imagePollBlock: imagePollBlock)
                
                self.optionViews.forEach({ (optionView) in
                    optionView.revealQuestionState()
                })
                
                let currentlyAssignedBlock = imagePollBlock
                self.urlSession.fetchPollResults(for: imagePollBlock.pollID(containedBy: experienceID), optionIds: imagePollBlock.imagePoll.votableOptionIDs) { [weak self] pollResults in
                    DispatchQueue.main.async {
                        guard let self = self else {
                            return
                        }
                        
                        switch pollResults {
                        case let .fetched(results):
                            // we are landing an async request. If current state is one that can accept our freshly acquired results, then transition.
                            switch self.state {
                            case .initialState:
                                if currentlyAssignedBlock.id != imagePollBlock.id {
                                    return
                                }
                                
                                self.state = .resultsSeeded(initialResults: results.results)
                                
                            case let .pollAnswered(myAnswer):
                                if currentlyAssignedBlock.id != imagePollBlock.id {
                                    return
                                }
                                
                                self.state = .submittingAnswer(myAnswer: myAnswer, initialResults: results.results)
                            default:
                                return
                            }
                        case .failed:
                            // TODO: retry.
                            os_log("Initial poll results fetch failed.", log: .rover, type: .error)
                        }
                    }
                }
                
                // handleOptionTapped() will check for this state and transition to .pollAnswered if needed.
                
            case let .resultsSeeded(initialResults):
                // The initial results have loaded.
                // Keep waiting for user to select an answer.
                // After the user answers, transition to .submittingAnswer
                
                // handleOptionTapped() will check for this state and transition to .submittingAnswer.
                self.optionViews.forEach({ (optionView) in
                    optionView.revealQuestionState()
                })
                
                break
            case let .pollAnswered(myAnswer):
                // We've got an answer but we haven't received the seed results yet.
                // Show a loading indicator while we wait.
                // When results finish loading, transition to .submittingAnswer
                os_log("Seed results haven't yet arrived, TODO UI indication.")
                break
            case let .submittingAnswer(myAnswer, initialResults):
                // At this point the initial results have loaded AND the user has answered the poll.
                // The initialResults will not include the user's answer yet because it hasn't been submitted to the server.
                // Display the results version of the UI using the initialResults data.
                // Use the myAnswer data to add +1 to the answer selected by the user and display the indicator circle.
                // Begin a network request to submit the user's answer to the server.
                // If the network request fails, try again.
                // If the network request succeeds, transition to .refreshingResults
                // The value of currentResults passed to the .refreshingResults case should INCLUDE the user's answer
                
                guard let imagePollBlock = self.block as? ImagePollBlock else {
                    os_log("Transitioned into .submittingAnswer state without the block being configured.")
                    return
                }
                
                guard let experienceID = self.experienceID else {
                    os_log("Attempt to configure poll block cell before informing it of the containing experience. Reverting to unbound.", log: .rover, type: .error)
                    state = .unbound
                    return
                }
                
                let withUsersVoteAdded = initialResults.map { tuple -> (String, Int) in
                    let (optionID, votes) = tuple
                    return (optionID, optionID == myAnswer ? votes + 1 : votes)
                }.reduce(into: PollResults()) { (dictionary, tuple) in
                    let (optionID, votes) = tuple
                    dictionary[optionID] = votes
                }
                let viewOptionStatuses = withUsersVoteAdded.viewOptionStatuses(userAnswer: myAnswer)
                self.optionViews.forEach { (optionView) in
                    let optionID = optionView.optionID
                    guard let optionResults = viewOptionStatuses[optionID] else {
                        os_log("A result was not given for option: %s.  Did you remember to unsubscribe on recycle?", log: .rover, type: .error, optionID)
                        return
                    }
                    optionView.revealResultsState(animated: shouldAnimateResults, optionResults: optionResults)
                }
                
                if let selectedOption = imagePollBlock.imagePoll.options.first(where: { $0.id == myAnswer }) {
                    self.delegate?.didCastVote(on: imagePollBlock, for: selectedOption)
                }
                
                let currentlyAssignedBlock = imagePollBlock
                
                self.urlSession.castVote(pollID: imagePollBlock.pollID(containedBy: experienceID), optionID: myAnswer) { [weak self] castVoteResults in
                    DispatchQueue.main.async {
                        guard let self = self else {
                            return
                        }
                        
                        switch castVoteResults {
                        case .succeeded:
                            // we are landing an async request. If current state is one that can accept our freshly submitted vote, then transition.
                            switch self.state {
                            case let .submittingAnswer(myAnswer, _):
                                if currentlyAssignedBlock.id != imagePollBlock.id {
                                    return
                                }
                                
                                self.state = .refreshingResults(myAnswer: myAnswer, currentResults: withUsersVoteAdded)
                                
                            default:
                                break
                            }
                        case .failed:
                            // TODO: make this do the same recursive retry pattern as the other requests.
                            os_log("Cast vote request failed.", log: .rover, type: .error)
                            
                        }
                    }
                }
            case let .refreshingResults(myAnswer, currentResults):
                // At this point we have answered the poll and have the current results which INCLUDE the user's answer.
                // Use the currentResults to populate the UI and the myAnswer property to display the indicator circle.
                // Start a 5-second timer and make a network request to refresh the results.
                // If network request fails, try again in 5-seconds.
                // If network request succeeds, update the currentResults property with the new results.
                
                // TODO: particularly when restoring, confirm that currentResults still matches that in imagePollBlock!
                
                guard let imagePollBlock = self.block as? ImagePollBlock else {
                    os_log("Transitioned into .refreshingResults state without the block being configured.")
                    return
                }
                
                guard let experienceID = self.experienceID else {
                    os_log("Attempt to configure poll block cell before informing it of the containing experience. Reverting to unbound.", log: .rover, type: .error)
                    state = .unbound
                    return
                }
                
                let viewOptionStatuses = currentResults.viewOptionStatuses(userAnswer: myAnswer)
                self.optionViews.forEach { (optionView) in
                    let optionID = optionView.optionID
                    guard let optionResults = viewOptionStatuses[optionID] else {
                        os_log("A result was not given for option: %s.  Did you remember to unsubscribe on recycle?", log: .rover, type: .error, optionID)
                        return
                    }
                    optionView.revealResultsState(animated: shouldAnimateResults, optionResults: optionResults)
                }
                
                let currentlyAssignedBlock = imagePollBlock
                func recursiveFetch(delay: TimeInterval = 0) {
                    self.urlSession.fetchPollResults(for: imagePollBlock.pollID(containedBy: experienceID), optionIds: imagePollBlock.imagePoll.votableOptionIDs) { [weak self] results in
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(Int(delay * 1000))) {
                            switch self?.state {
                            case .refreshingResults:
                                if currentlyAssignedBlock.id != imagePollBlock.id {
                                    return
                                }
                                break;
                            default:
                                os_log("Poll Block has transitioned away from .refreshingResults, ending automatic refresh.", log: .rover, type: .error)
                                return
                            }
                            
                            switch results {
                                case .failed:
                                    os_log("Unable to fetch poll results. Will retry.", log: .rover, type: .fault)
                                case let .fetched(results):
                                    // update local state!
                                    os_log("Successfully fetched current poll results.", log: .rover, type: .debug)
                                    
                                    self?.state = .refreshingResults(myAnswer: myAnswer, currentResults: results.results)
                            }
                            // queue up next attempt.
                            recursiveFetch(delay: 5)
                        }
                    }
                }
                
                // kick off the recursive fetch, but only if we are transitioning into .refreshingResults. If we are already there, then a recursive fetch is already running.
                switch oldValue {
                case .refreshingResults:
                    break
                default:
                    recursiveFetch()
                }
            case let .restoreTo(newState):
                DispatchQueue.main.async {
                    self.state = newState
                }
                
                // do not allow the state saving logic below to operate.
                return
            }
            
            // Now persist the state to disk.
            
            guard let imagePollBlock = self.block as? ImagePollBlock else {
                os_log("Trying to save the state to disk, but the block has not yet been configured.")
                return
            }
            
            guard let experienceID = self.experienceID else {
                os_log("Trying to save the state to disk, but the block has not yet been informed of the containing experience. Reverting to unbound.", log: .rover, type: .error)
                state = .unbound
                return
            }
            
            UserDefaults().writeStateJsonForPoll(id: imagePollBlock.pollID(containedBy: experienceID), json: self.state)
            os_log("Wrote new state for Poll %s to disk.", log: .rover, type: .error, imagePollBlock.id)
        }
        
    }
    
    /// a simple container view to the relatively complex layout of the text poll.
    private let containerView = UIView()
    
    private var optionViews = [ImagePollOptionView]()
    private var optionStack: UIStackView?
    
    override var content: UIView? {
        return containerView
    }
    
    private var questionView: PollQuestionView?
    
    override func configure(with block: Block) {
        self.state = .unbound
        super.configure(with: block)
        
        guard let imagePollBlock = self.block as? ImagePollBlock else {
            os_log("ImagePollCell configured with a block that is not an Image Poll block.")
            return
        }
        
        guard let experienceID = self.experienceID else {
            os_log("Attempt to configure poll block cell before informing it of the containing experience. Reverting to unbound.", log: .rover, type: .error)
            state = .unbound
            return
        }
        
        
        killUi()
        buildUiForPoll(imagePollBlock: imagePollBlock)
        
        // if an existing state is available for the poll, jump to it:
        
        if let restoredState: PollState = UserDefaults().retrieveStateJsonForPoll(id: imagePollBlock.pollID(containedBy: experienceID)) {
            switch restoredState {
            case .pollAnswered:
                // The Poll Answered state is a transitive one and expects that a background task is running, which would not be in the event of a restore.  So skip back to the beginning in that case.
                self.state = .initialState
            default:
                os_log("Restoring state to %s.", restoredState.name)
                self.state = .restoreTo(state: restoredState)
            }
        } else {
            self.state = .initialState
        }
    }
}

// MARK: Cell Delegate

protocol ImagePollCellDelegate: AnyObject {
    func didCastVote(on imagePollBlock: ImagePollBlock, for option: ImagePollBlock.ImagePoll.Option)
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

private extension PollResults {
    func viewOptionStatuses(userAnswer: String) -> [String: ImagePollOptionView.OptionResults] {
        let votesByOptionIds = self
        let totalVotes = votesByOptionIds.values.reduce(0, +)
        let roundedPercentagesByOptionIds = votesByOptionIds.percentagesWithDistributedRemainder()
        
        return self.keys.map { optionID -> (String, ImagePollOptionView.OptionResults) in
            let optionCount = self[optionID]!
            
            let fraction: Double
            if totalVotes == 0 {
                fraction = 0
            } else {
                fraction = Double(optionCount) / Double(totalVotes)
            }
            let optionResults = ImagePollOptionView.OptionResults(
                selected: optionID == userAnswer,
                fraction: fraction,
                percentage: roundedPercentagesByOptionIds[optionID]!
            )
            
            return (optionID, optionResults)
        }.reduce(into: [String: ImagePollOptionView.OptionResults]()) { (dictionary, tuple) in
            let (optionID, optionStatus) = tuple
            dictionary[optionID] = optionStatus
        }
    }
}
