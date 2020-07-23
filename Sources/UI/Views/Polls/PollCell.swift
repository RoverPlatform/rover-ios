//
//  PollCell.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-08-14.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit
import os

protocol PollCellDelegate: AnyObject {
    func didCastVote(on pollBlock: PollBlock, for option: PollOption)
}

class PollCell: BlockCell {
    struct OptionResult {
        let selected: Bool
        let fraction: Double
        let percentage: Int
    }
    
    var experienceID: String?
    weak var delegate: PollCellDelegate?
    
    override var content: UIView? {
        return containerView
    }
    
    var isLoading = false {
        didSet {
            alpha = isLoading ? 0.5 : 1.0
            isUserInteractionEnabled = !isLoading
        }
    }
    
    let containerView = UIView()
    let question = UILabel()
    
    var questionText: Text? {
        didSet {
            guard let questionText = questionText else {
                question.text = nil
                return
            }
            
            question.text = questionText.rawValue
            question.font = questionText.font.uiFont
            question.textColor = questionText.color.uiColor
            question.textAlignment = questionText.alignment.textAlignment
            
            // Accessibility
            let numberOfOptions = (block as! PollBlock).poll.pollOptions.count
            question.accessibilityLabel = "Poll with \(numberOfOptions) options: \(questionText.rawValue)"
        }
    }
    
    let optionsList = UIStackView()
    
    var verticalSpacing: CGFloat = 0 {
        didSet {
            optionsList.spacing = verticalSpacing
            spacingConstraint.constant = verticalSpacing
        }
    }
    
    var spacingConstraint: NSLayoutConstraint!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // question
        
        question.numberOfLines = 0
        question.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(question)
        
        NSLayoutConstraint.activate([
            question.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            question.topAnchor.constraint(equalTo: containerView.topAnchor),
            question.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        // optionsList
        
        optionsList.axis = .vertical
        optionsList.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(optionsList)
        
        NSLayoutConstraint.activate([
            optionsList.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            optionsList.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        // spacingConstraint
        
        spacingConstraint = optionsList.topAnchor.constraint(equalTo: question.bottomAnchor, constant: 0)
        spacingConstraint.isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func configure(with block: Block) {
        state = .unbound
        super.configure(with: block)
        
        guard let pollBlock = self.block as? PollBlock else {
            os_log("Attempt to configure a PollCell with a block that is not a Poll Block", log: .rover, type: .error)
            return
        }
        
        guard let experienceID = self.experienceID else {
            os_log("Attempt to configure poll block cell before informing it of the containing experience. Reverting to unbound.", log: .rover, type: .error)
            state = .unbound
            return
        }
        
        // if an existing state is available for the poll, jump to it:
        
        if let restoredState: PollState = UserDefaults().retrieveStateJSONForPoll(id: pollBlock.pollID(containedBy: experienceID)) {
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
    
    // MARK: Template Methods
    
    func setResults(_ results: [PollCell.OptionResult], animated: Bool) {
        fatalError("Must be overridden")
    }
    
    func clearResults() {
        fatalError("Must be overridden")
    }
    
    func optionSelected(_ option: PollOption) {        
        switch self.state {
        case .initialState:
            self.state = .pollAnswered(myAnswer: option.id)
        case let .resultsSeeded(initialResults):
            self.state = .submittingAnswer(myAnswer: option.id, initialResults: initialResults)
        default:
            os_log("Vote attempt landed, but not currently in correct state to accept it.", log: .rover, type: .fault)
            return
        }
    }
    
    // MARK: State Machine
    
    private let urlSession = URLSession.shared
    
    private indirect enum PollState: Codable {
        /// The Poll Cell is not attached to the Poll block, and thus will be displaying nothing.
        case unbound
        
        /// Present UI to allow user to select an answer. If results load before users selects an answer, transition to .resultsSeeded. If user selects answer before initial results load, transition to .pollAnswered
        case initialState
        
        /// The initial results have loaded. Keep waiting for user to select an answer. After the user answers, transition to .submittingAnswer
        case resultsSeeded(initialResults: PollResults)
        
        /// We've got an answer but we haven't received the seed results yet. Show a loading indicator while we wait. When results finish loading, transition to .submittingAnswer
        case pollAnswered(myAnswer: PollAnswer)
        
        /// At this point the initial results have loaded AND the user has answered the poll. The initialResults will not include the user's answer yet because it hasn't been submitted to the server. Display the results version of the UI using the initialResults data. Use the myAnswer data to add +1 to the answer selected by the user and display the indicator circle. Begin a network request to submit the user's answer to the server. If the network request fails, try again. If the network request succeeds, transition to .refreshingResults. The value of currentResults passed to the .refreshingResults case should INCLUDE the user's answer.
        case submittingAnswer(myAnswer: PollAnswer, initialResults: PollResults)
        
        /// At this point we have answered the poll and have the current results which INCLUDE the user's answer. Use the currentResults to populate the UI and the myAnswer property to display the indicator circle. Start a 5-second timer and make a network request to refresh the results. If network request fails, try again in 5-seconds. If network request succeeds, update the currentResults property with the new results.
        case refreshingResults(myAnswer: PollAnswer, currentResults: PollResults)
        
        /// A stored copy of the [PollState] is available on disk. Transition directly to the prior state, where permitted.
        case restoreTo(state: PollState)
        
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
        case (.submittingAnswer, .initialState):
            return true
        case (.refreshingResults, .refreshingResults):
            return true
        case (.refreshingResults, .initialState):
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
            assert(canTransition(from: state, to: newValue), "Invalid state transition from \(state.name) to \(newValue.name)!")
            os_log("Poll block transitioning from %s state to %s.", log: .rover, type: .debug, state.name, newValue.name)
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
            // MARK: Unbound
            case .unbound:
                // do not allow the state saving logic below to operate, because without being bound to a poll we aren't able to persist anything on its behalf.
                return
                
            // MARK: Initial State
            case .initialState:
                
                
                guard let pollBlock = self.block as? PollBlock & Block else {
                    os_log("Transitioned into .initialState state without the block being configured.")
                    return
                }

                guard let experienceID = self.experienceID else {
                    os_log("Attempt to configure poll block cell before informing it of the containing experience. Reverting to unbound.", log: .rover, type: .error)
                    state = .unbound
                    return
                }
            
                clearResults()
                self.isLoading = false
            
                var recursiveFetch: ((TimeInterval) -> Void)!
                recursiveFetch = { [weak self] delay in
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(Int(delay * 1000))) {
                        self?.urlSession.fetchPollResults(for: pollBlock.pollID(containedBy: experienceID), optionIDs: pollBlock.poll.optionIDs) { pollResults in
                            DispatchQueue.main.async {
                                guard let self = self else {
                                    return
                                }
                                
                                let currentlyAssignedBlock = self.block as? PollBlock
                                if currentlyAssignedBlock?.id != pollBlock.id {
                                    return
                                }
                                
                                switch pollResults {
                                case let .fetched(results):
                                    // we are landing an async request. If current state is one that can accept our freshly acquired results, then transition.
                                    switch self.state {
                                    case .initialState:
                                        self.state = .resultsSeeded(initialResults: results)
                                    case let .pollAnswered(myAnswer):
                                        self.state = .submittingAnswer(myAnswer: myAnswer, initialResults: results)
                                    default:
                                        return
                                    }
                                case .failed:
                                    // retry!
                                    os_log("Initial poll results fetch failed.  Will retry momentarily.", log: .rover, type: .error)
                                    recursiveFetch(1)
                                }
                            }
                        }
                    }
                }
                
                recursiveFetch(0)
                
                // handleOptionTapped() will check for this state and transition to .pollAnswered if needed.
                
            // MARK: Results Seeded
            case .resultsSeeded:
                // handleOptionTapped() will check for this state and transition to .submittingAnswer.
                self.clearResults()
                self.isLoading = false
                
            // MARK: Poll Answered
            case .pollAnswered:
                // Waiting for initial results to arrive, which will then transition to .submittingAnswer.
                self.clearResults()
                self.isLoading = true
                
            // MARK: Submitting Answer
            case let .submittingAnswer(myAnswer, initialResults):
                guard let pollBlock = self.block as? PollBlock else {
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
                let viewOptionResults = withUsersVoteAdded.viewOptionStatuses(userAnswer: myAnswer)
                
                // Instead of a dictionary keyed by Option IDs, instead make an array ordered by the original order of the options in the poll.
                let viewOptionResultsArray = pollBlock.poll.optionIDs.compactMap {
                    viewOptionResults[$0]
                }
                
                if viewOptionResultsArray.count != viewOptionResults.count {
                    os_log("Options have changed since they were seeded, starting over.", type: .info)
                    self.isLoading = false
                    DispatchQueue.main.async {
                        self.state = .initialState
                    }
                    return
                }
                
                setResults(viewOptionResultsArray, animated: shouldAnimateResults)
                self.isLoading = false
                
                if let selectedOption = pollBlock.poll.pollOptions.first(where: { $0.id == myAnswer }) {
                    self.delegate?.didCastVote(on: pollBlock, for: selectedOption)
                }
                
                var recursiveVoteAttempt: ((TimeInterval) -> Void)!
                recursiveVoteAttempt = { [weak self] delay in
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(Int(delay * 1000))) {
                        self?.urlSession.castVote(pollID: pollBlock.pollID(containedBy: experienceID), optionID: myAnswer) { castVoteResults in
                            DispatchQueue.main.async {
                                guard let self = self else {
                                    return
                                }
                                
                                let currentlyAssignedBlock = self.block as? PollBlock
                                if currentlyAssignedBlock?.id != pollBlock.id {
                                    return
                                }
                                
                                switch castVoteResults {
                                case .succeeded:
                                    // we are landing an async request. If current state is one that can accept our freshly submitted vote, then transition.
                                    switch self.state {
                                    case let .submittingAnswer(myAnswer, _):

                                        
                                        self.state = .refreshingResults(myAnswer: myAnswer, currentResults: withUsersVoteAdded)
                                        
                                    default:
                                        break
                                    }
                                case .failed:
                                    os_log("Cast vote request failed. Will retry momentarily.", log: .rover, type: .error)
                                    recursiveVoteAttempt(1)
                                }
                            }
                        }
                    }
                }
                recursiveVoteAttempt(0)
                
            // MARK: Refreshing Results
            case let .refreshingResults(myAnswer, currentResults):
                guard let pollBlock = self.block as? PollBlock else {
                    os_log("Transitioned into .refreshingResults state without the block being configured.")
                    return
                }
                
                guard let experienceID = self.experienceID else {
                    os_log("Attempt to configure poll block cell before informing it of the containing experience. Reverting to unbound.", log: .rover, type: .error)
                    state = .unbound
                    return
                }
                                
                let viewOptionResults = currentResults.viewOptionStatuses(userAnswer: myAnswer)
                
                // Instead of a dictionary keyed by Option IDs, instead make an array ordered by the original order of the options in the poll.
                let viewOptionResultsArray = pollBlock.poll.optionIDs.compactMap {
                    viewOptionResults[$0]
                }
                
                if viewOptionResultsArray.count != pollBlock.poll.optionIDs.count {
                    let experienceOptionIDs = pollBlock.poll.optionIDs.sorted()
                    let stateOptionIDs = currentResults.keys.sorted()
                    os_log("Retrieved option results do not fully match those on the Experience Poll Block (block has %s, state has %s).  Resetting poll.", log: .rover, type: .fault, String(describing: experienceOptionIDs), String(describing: stateOptionIDs))
                    DispatchQueue.main.async {
                        self.state = .initialState
                    }
                    return
                }

                setResults(viewOptionResultsArray, animated: shouldAnimateResults)
                self.isLoading = false
                
                var recursiveFetch: ((TimeInterval) -> Void)!
                recursiveFetch = { [weak self] delay in
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(Int(delay * 1000))) {
                        self?.urlSession.fetchPollResults(for: pollBlock.pollID(containedBy: experienceID), optionIDs: pollBlock.poll.optionIDs) { results in
                            DispatchQueue.main.async {
                                guard let self = self else {
                                    return
                                }
                                
                                let currentlyAssignedBlock = self.block as? PollBlock
                                if currentlyAssignedBlock?.id != pollBlock.id {
                                    return
                                }
                                
                                switch self.state {
                                case .refreshingResults:
                                    
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
                                        
                                        if Set(currentResults.keys) == Set(results.keys) {
                                            self.state = .refreshingResults(myAnswer: myAnswer, currentResults: results)
                                        } else {
                                            os_log("Currently voted-on results changed since user last voted.  Resetting poll.", log: .rover, type: .info)
                                            self.state = .initialState
                                            return // prevent the refresh behaviour below from kicking in.
                                        }
                                }
                                // queue up next attempt.
                                recursiveFetch(5)
                            }
                        }
                    }
                }
                
                // kick off the recursive fetch, but only if we are transitioning into .refreshingResults. If we are already there, then a recursive fetch is already running.
                switch oldValue {
                case .refreshingResults:
                    break
                default:
                    recursiveFetch(5)
                }
                
            // MARK: State Restore
            case let .restoreTo(newState):
                DispatchQueue.main.async {
                    self.state = newState
                }
                
                // do not allow the state saving logic below to operate.
                return
            }
            
            // MARK: State Persistence
            
            // Now persist the state to disk.
            
            guard let pollBlock = self.block as? PollBlock else {
                os_log("Trying to save the state to disk, but the block has not yet been configured.")
                return
            }
            
            guard let experienceID = self.experienceID else {
                os_log("Trying to save the state to disk, but the block has not yet been informed of the containing experience. Reverting to unbound.", log: .rover, type: .error)
                state = .unbound
                return
            }
            
            UserDefaults().writeStateJSONForPoll(id: pollBlock.pollID(containedBy: experienceID), json: self.state)
            os_log("Wrote new state for Poll %s to disk.", log: .rover, type: .error, pollBlock.id)
        }
    }
}

// MARK: Utility

private extension Dictionary where Key == String, Value == Int  {
    func viewOptionStatuses(userAnswer: String) -> [String: PollCell.OptionResult] {
        let votesByOptionIds = self
        let totalVotes = votesByOptionIds.values.reduce(0, +)
        let roundedPercentagesByOptionIds = votesByOptionIds.percentagesWithDistributedRemainder()
        
        return self.keys.map { optionID -> (String, PollCell.OptionResult) in
            let optionCount = self[optionID]!
            
            let fraction: Double
            if totalVotes == 0 {
                fraction = 0
            } else {
                fraction = Double(optionCount) / Double(totalVotes)
            }
            let optionResults = PollCell.OptionResult(
                selected: optionID == userAnswer,
                fraction: fraction,
                percentage: roundedPercentagesByOptionIds[optionID]!
            )
            
            return (optionID, optionResults)
        }.reduce(into: [String: PollCell.OptionResult]()) { (dictionary, tuple) in
            let (optionID, optionStatus) = tuple
            dictionary[optionID] = optionStatus
        }
    }
}
