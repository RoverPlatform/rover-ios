//
//  PollsVotingService.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-07-23.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

class PollsVotingService {
    public struct OptionStatus {
        let selected: Bool
        let fraction: Float
    }
    
    /// Yielded
    public enum PollStatus {
        case waitingForAnswer
        case answered(optionResults: OptionStatus)
    }
    
    // TODO: Api Client
    
    // TODO: local storage for each poll: the last seen options list for the poll.  results for the poll, if any have been retrieved. What our vote was, if any.
    
    // TODO: aggregation behaviour -> for example, waiting to emit a poll result until the poll results have been retrieved.

    // Interface is going to be thus: separation of casting of votes and subscribing to updates.  also allow getting current state synchronously, to make the UI code simpler so an initial state can be available. so getting current state synchronously and subscribing to updates will be two separate methods, for convenience.
    
    //
    
    // MARK: State & Storage
    
    private let storage = UserDefaults()
    
    /// Synchronize operations that mutate local poll state.
    private let serialQueue: Foundation.OperationQueue = {
        let q = Foundation.OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    }()
    
    /// Get the current state for the poll.
    func currentStateForPoll(optionIds: [String], pollId: String) {
        
    }
    
    // TODO: decide when and where the results request should be fired. As a side-effect of currentStateForPoll or subscribeToUpdates?
    
    /// Cast a vote on the poll.  Naturally may only be done once.  Synchronous, fire-and-forget, and best-effort. Any subscribers will be instantly notified (if possible) of the update.
    func castVote(pollId: String, optionId: String) {
        // TODO synchronously in local storage check for optionResults stored locally.  If present, update local state with dead-reckoned (+1 bump) values and then immediately emit an poll status update to subscribers.
        // then dispatch vote request task onto the queue.
        
        // if local state wasn't present, then either the results request didn't complete successfully or user tapped fast and thus we're racing it.
    }
    
    /// Be notified of poll state.  Updates will be emitted on the main thread. Note that this will not immediately yield current state. Synchronously call `currentStateForPoll()` instead.
    func subscribeToUpdates(pollId: String, subscriber: (PollStatus) -> Void) {
        
    }
    
    /// Internal representation for storage of poll state on disk.
    private struct PollState: Codable {
        let pollId: String
        
        /// The options last seen for this poll.  If the options have changed, we will reset that state to allow the user to vote again.
        let seenOptions: [String]
        
        /// The results retrieved for the poll, if available.  Poll Id -> Number of Votes.
        let optionResults: [String: Int]?
        
        /// If the user has voted, for which option did they vote?
        let userVotedForOptionId: String?
    }
}

extension TextPollBlock.TextPoll {
    var votableOptionIds: [String] {
        return self.options.map { option in
            option.id
        }
    }
}

extension ImagePollBlock.ImagePoll {
    var votableOptionIds: [String] {
        return self.options.map { option in
            option.id
        }
    }
}


