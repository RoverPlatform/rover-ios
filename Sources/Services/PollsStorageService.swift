//
//  PollsVotingService.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-07-23.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import os
import UIKit


private let USER_DEFAULTS_STORAGE_KEY = "io.rover.Polls.storage"

class PollsStorageService {
    /// The shared singleton Polls Storage Service.
    static let shared = PollsStorageService()
    
    // MARK: Types
    
    struct OptionStatus {
        let selected: Bool
        let voteCount: Int
    }
    
    enum PollStatus {
        case waitingForAnswer
        case answered(resultsForOptions: [String: OptionStatus])
    }
    
    // MARK: Behaviour & Aggregation
    // TODO: to be moved into UI layer (and subscribe broken into separate concerns, to enable the new sub-states, particularly).

    /// Cast a vote on the poll.  Naturally may only be done once.  Synchronous, fire-and-forget, and best-effort. Any subscribers will be instantly notified (if possible) of the update.
    func castVote(pollID: String, givenOptionIds optionIds: [String], optionID: String) {
        if let _ = self.localStateForPoll(pollID: pollID, givenCurrentOptionIds: optionIds).userVotedForOptionId {
            os_log("Can't vote twice.", log: .rover, type: .fault)
            return
        }
        
        self.urlSession.dispatchCastVoteRequest(pollID: pollID, optionID: optionID)

        // in the meantime, update local state that we voted and also to dead-reckon the increment of our vote being applied.
        commitVoteToLocalState(pollID: pollID, givenOptionIds: optionIds, optionID: optionID)
    }
    
    /// Be notified of poll state.  Updates will be emitted on the main thread. Note that this will not immediately yield current state, but it it synchronously.
    /// Returns the current poll status synchronously, along with a subscriber chit that you should retain a reference to until you wish to unsubscribe.
    func subscribeToUpdates(pollID: String, givenCurrentOptionIds optionIds: [String], subscriber: @escaping (PollStatus) -> Void) -> (PollStatus, AnyObject) {
        // side-effect: kick off async attempt to refresh PollResults.  That request will update the state in UserDefaults.
        
        if self.stateSubscribers[pollID] == nil {
            self.stateSubscribers[pollID] = []
        }
        var chit = Subscriber(callback: subscriber)
        self.stateSubscribers[pollID]!.append(
            SubscriberBox(subscriber: chit)
        )
        self.stateSubscribers = self.stateSubscribers.garbageCollected()
        
        func recursiveFetch(delay: TimeInterval = 0) {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(Int(delay * 1000))) {
                self.urlSession.fetchPollResults(for: pollID, optionIds: optionIds) { [weak self] results in
                    switch results {
                        case .failed:
                            os_log("Unable to fetch poll results.", log: .rover, type: .error)
                        case let .fetched(results):
                            // update local state!
                            os_log("Successfully fetched current poll results.", log: .rover, type: .debug)
                            self?.updateLocalStateWithResults(pollID: pollID, givenOptionIds: optionIds, fetchedPollResults: results.results)
                            
                            // chain fetch requests recursively, provided at least one subscriber exists for this poll.
                            if let _ = self?.stateSubscribers[pollID]?.first?.subscriber {
                                // 5 second delay on subsequent requests.
                                recursiveFetch(delay: 5)
                            }
                    }
                }
            }
        }
        
        recursiveFetch()
        
        // in the meantime, synchronously check local storage and immediately return the results:
        return (self.localStatusForPoll(pollID: pollID, givenOptionIds: optionIds), chit)
    }
    

    
    fileprivate class SubscriberBox {
        weak var subscriber: Subscriber?
        
        init(subscriber: Subscriber) {
            self.subscriber = subscriber
        }
        
        convenience init(callback: @escaping (PollStatus) -> Void) {
            self.init(subscriber: Subscriber(callback: callback))
        }
    }
    
    fileprivate class Subscriber {
        var callback: (PollStatus) -> Void
        
        init(callback: @escaping (PollStatus) -> Void) {
            self.callback = callback
        }
    }
    
    private var stateSubscribers = [String: [SubscriberBox]]()
    
    private func localStatusForPoll(pollID: String, givenOptionIds optionIds: [String]) -> PollStatus {
        return localStateForPoll(pollID: pollID, givenCurrentOptionIds: optionIds).pollStatus()
    }
    
        // MARK: State & Storage
    
    /// Internal representation for storage of poll state on disk.
    struct PollState: Codable {
        let pollID: String
        
        /// The results retrieved for the poll, if available.  Poll Id -> Number of Votes.
        let optionResults: [String: Int]?
        
        /// If the user has voted, for which option did they vote?
        let userVotedForOptionId: String?
    }
    
    private let storage = UserDefaults()

    private let urlSession = URLSession(configuration: URLSessionConfiguration.default)

    private func localStateForPoll(pollID: String, givenCurrentOptionIds optionIds: [String]) -> PollState {
        let decoder = JSONDecoder.init()
        if let existingPollsJson = self.storage.data(forKey: USER_DEFAULTS_STORAGE_KEY) {
            do {
                let pollStates = try decoder.decode([PollState].self, from: existingPollsJson)
                
                if let state = pollStates.first(where: { $0.pollID == pollID }), let storedOptions = state.optionResults {
                    if storedOptions.keys.sorted() == optionIds.sorted() {
                        // currently stored poll options match!
                        return state
                    } else {
                        os_log("Local poll state no longer matches the options given on the Poll itself. Considering poll state reset.", log: .rover, type: .fault)
                        return .init(pollID: pollID, optionResults: nil, userVotedForOptionId: nil)
                    }
                } else {
                    return .init(pollID: pollID, optionResults: nil, userVotedForOptionId: nil)
                }
            } catch {
                os_log("Existing storage for polls was corrupted: %s", error.debugDescription)
                return .init(pollID: pollID, optionResults: nil, userVotedForOptionId: nil)
            }
        }
        return .init(pollID: pollID, optionResults: nil, userVotedForOptionId: nil)
    }
    
    private func updateStorageForPoll(newState: PollState) {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let pollID = newState.pollID
        
        let pollStates: [PollState]
        if let existingPollsJson = self.storage.data(forKey: USER_DEFAULTS_STORAGE_KEY) {
            do {
                pollStates = try decoder.decode([PollState].self, from: existingPollsJson)
            } catch {
                os_log("Existing storage for polls was corrupted, resetting: %s", log: .rover, type: .error, error.debugDescription)
                pollStates = []
            }
        } else {
            pollStates = []
        }
        
        // delete existing entry if one is present and prepend the new one:
        let newStates = [newState] + pollStates.filter { $0.pollID != pollID }
        
        // drop any stored states past 100:
        let trimmedNewStates: [PollState] = Array(newStates.prefix(100))
        
        do {
            let newStateJson = try encoder.encode(trimmedNewStates)
            self.storage.set(newStateJson, forKey: USER_DEFAULTS_STORAGE_KEY)
            // TODO: this was where the update event was formerly dispatched as a side-effect. No longer.
        } catch {
            os_log("Unable to update local poll storage: %s", log: .rover, type: .error, error.debugDescription)
            return
        }
        os_log("Updated local state for poll %s.", log: .rover, type: .debug, pollID)
    }
    

    
    func updateLocalStateWithResults(pollID: String, givenOptionIds optionIds: [String], fetchedPollResults: [String: Int]) {
        // replace locally stored results with a new copy with the results part updated.
        let localState: PollState = self.localStateForPoll(pollID: pollID, givenCurrentOptionIds: optionIds)

        let newState = PollState(pollID: pollID, optionResults: fetchedPollResults, userVotedForOptionId: localState.userVotedForOptionId)
        self.updateStorageForPoll(newState: newState)
    }
    
    func commitVoteToLocalState(pollID: String, givenOptionIds optionIds: [String], optionID: String) {
        let localState: PollState = self.localStateForPoll(pollID: pollID, givenCurrentOptionIds: optionIds)
       
        guard localState.userVotedForOptionId == nil else {
            os_log("User already voted.", log: .rover, type: .fault)
            return
        }
                
        let newState: PollState
        if var optionResults = localState.optionResults {
            // results with user's selection incremented.
            optionResults[optionID]? += 1
            newState = PollState(pollID: pollID, optionResults: optionResults, userVotedForOptionId: optionID)
        } else {
            newState = PollState(pollID: pollID, optionResults: localState.optionResults, userVotedForOptionId: optionID)
        }
        
        os_log("Recording vote for option %s on poll %s", log: .rover, type: .info, optionID, pollID)
        
        updateStorageForPoll(newState: newState)
    }
    
}

// MARK: External Helpers

// TODO: kill
extension TextPollBlock.TextPoll {
    /// Gather up votable option IDs from the options on this Poll, for  use with the PollsVotingService.
    var votableOptionIds: [String] {
        return self.options.map { option in
            option.id
        }
    }
}

// MARK: Internal Helpers

private extension Array where Element == PollsStorageService.SubscriberBox {
    func garbageCollected() -> [PollsStorageService.SubscriberBox] {
        self.filter { subscriberBox in
            subscriberBox.subscriber != nil
        }
    }
}

private extension Dictionary where Key == String, Value == [PollsStorageService.SubscriberBox] {
    func garbageCollected() -> [String: [PollsStorageService.SubscriberBox]] {
        self.mapValues { subscribers in
            return subscribers.garbageCollected()
        }
    }
}

extension PollsStorageService.PollState {
    func pollStatus() -> PollsStorageService.PollStatus {
        if let vote = self.userVotedForOptionId {
            // user voted, so show them the response.
            guard let optionResults = self.optionResults else {
                // user voted but optionResults not stored.
                os_log("User voted but local copy of option results is missing.", log: .rover, type: .fault)
                return .waitingForAnswer
            }

            // couldn't use mapValues because I needed the key (option id) to do the transform.
            let optionStatuses = optionResults.keys.map { (optionID) in
                return (optionID, PollsStorageService.OptionStatus(selected: vote == optionID, voteCount: optionResults[optionID]!))
            }.reduce(into: [String: PollsStorageService.OptionStatus]()) { (dictionary, tuple) in
                let (optionID, optionStatus) = tuple
                dictionary[optionID] = optionStatus
            }
            
            return .answered(resultsForOptions: optionStatuses)
        }
        return .waitingForAnswer
    }
}



extension UserDefaults {
    
    struct PollStorageRecord<J: Codable>: Codable {
        var pollID: String
        var poll: J
    }
    
    func writeStateJsonForPoll<J: Codable>(id: String, json: J) {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let existingRecords: [PollStorageRecord<J>]
        if let existingPollsJson = self.data(forKey: USER_DEFAULTS_STORAGE_KEY) {
            do {
                existingRecords = try decoder.decode([PollStorageRecord<J>].self, from: existingPollsJson)
            } catch {
                os_log("Existing storage for polls was corrupted, resetting: %s", log: .rover, type: .error, error.debugDescription)
                existingRecords = []
            }
        } else {
            existingRecords = []
        }
        
        let record = PollStorageRecord<J>(pollID: id, poll: json)
        
        // delete existing entry if one is present and prepend the new one:
        let records = [record] + existingRecords.filter { $0.pollID != id }
        
        // drop any stored states past 100:
        let trimmedNewRecords: [PollStorageRecord<J>] = Array(records.prefix(100))
        
        do {
            let newStateJson = try encoder.encode(trimmedNewRecords)
            self.set(newStateJson, forKey: USER_DEFAULTS_STORAGE_KEY)
        } catch {
            os_log("Unable to update local poll storage: %s", log: .rover, type: .error, error.debugDescription)
            return
        }
        os_log("Updated local state for poll %s.", log: .rover, type: .debug, id)
        
    }
    
    func retrieveStateJsonForPoll<J: Codable>(id: String) -> J? {
        let decoder = JSONDecoder.init()
        if let existingPollsJson = self.data(forKey: USER_DEFAULTS_STORAGE_KEY) {
            do {
                let pollStates = try decoder.decode([PollStorageRecord<J>].self, from: existingPollsJson)
                
                return pollStates.first(where: { $0.pollID == id })?.poll
            } catch {
                os_log("Existing storage for polls was corrupted: %s", error.debugDescription)
                return nil
            }
        } else {
            return nil
        }
    }
}
