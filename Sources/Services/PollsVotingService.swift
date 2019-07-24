//
//  PollsVotingService.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-07-23.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

class PollsVotingService {
    // TODO: Api Client
    
    // TODO: local storage for each poll: the last seen options list for the poll.  results for the poll, if any have been retrieved. What our vote was, if any.
    
    // TODO: aggregation behaviour -> for example, waiting to emit a poll result until the poll results have been retrieved.

    // Interface is going to be thus: separation of casting of votes and subscribing to updates.  also allow getting current state synchronously, to make the UI code simpler so an initial state can be available. so getting current state synchronously and subscribing to updates will be two separate methods, for convenience.
    
    //
    
    // MARK: State & Storage
    
    private let storage = UserDefaults()
    
    /// synchronous, fire-and-forget, best-effort.
    func castVote(pollId: String, optionId: String) {
       // TODO: dispatch update task onto the queue.
    }
    
    /// we will emit updates on the main thread.
    func subscribeToUpdates(pollId: String, subscriber: (PollStatus) -> Void) {
        
    }
    
    /// Get the current state for the poll.
    func currentStateForPoll(optionIds: [String], pollId: String) {
        
    }
    
    private struct PollState: Codable {
        let pollId: String
        
        /// The options last seen for this poll.  If the options have changed, we will reset that state to allow the user to vote again.
        let seenOptions: [String]
        
        /// The results retrieved for the poll, if available.  Poll Id -> Number of Votes.
        let optionResults: [String: Int]?
        
        /// If the user has voted, for which option did they vote?
        let userVotedForOptionId: String?
    }
    
    public struct OptionStatus {
        let selected: Bool
        let fraction: Float
    }
    
    ///
    public enum PollStatus {
        case waitingForAnswer
        case answered(optionResults: OptionStatus)
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


