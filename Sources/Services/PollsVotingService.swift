//
//  PollsVotingService.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-07-23.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import os
import UIKit

private let POLLS_SERVICE_ENDPOINT = "https://polls.rover.io/v1/polls/"
private let USER_DEFAULTS_STORAGE_KEY = "io.rover.Polls.storage"

class PollsVotingService {
    /// The shared singleton Voting Service.
    static let shared = PollsVotingService()
    
    // MARK: Types
    
    struct OptionStatus {
        let selected: Bool
        let voteCount: Int
    }
    
    enum PollStatus {
        case waitingForAnswer
        case answered(resultsForOptions: [String: OptionStatus])
    }

    /// Cast a vote on the poll.  Naturally may only be done once.  Synchronous, fire-and-forget, and best-effort. Any subscribers will be instantly notified (if possible) of the update.
    func castVote(pollId: String, givenOptionIds optionIds: [String], optionId: String) {
        switch self.localStatusForPoll(pollId: pollId, givenOptionIds: optionIds) {
        case .answered:
            os_log("Can't vote twice.", log: .rover, type: .fault)
            return
        default:
            break;
        }
        
        dispatchCastVoteRequest(pollId: pollId, optionId: optionId)

        // in the meantime, update local state that we voted and also to dead-reckon the increment of our vote being applied.
        commitVoteToLocalState(pollId: pollId, givenOptionIds: optionIds, optionId: optionId)
    }
    
    /// Be notified of poll state.  Updates will be emitted on the main thread. Note that this will not immediately yield current state, but it it synchronously.
    /// Returns the current poll status synchronously, along with a subscriber chit that you should retain a reference to until you wish to unsubscribe.
    func subscribeToUpdates(pollId: String, givenCurrentOptionIds optionIds: [String], subscriber: @escaping (PollStatus) -> Void) -> (PollStatus, AnyObject) {
        // side-effect: kick off async attempt to refresh PollResults.  That request will update the state in UserDefaults.
        
        if self.stateSubscribers[pollId] == nil {
            self.stateSubscribers[pollId] = []
        }
        var chit = Subscriber(callback: subscriber)
        self.stateSubscribers[pollId]!.append(
            SubscriberBox(subscriber: chit)
        )
        self.stateSubscribers = self.stateSubscribers.garbageCollected()
        
        func recursiveFetch(delay: TimeInterval = 0) {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(Int(delay * 1000))) {
                self.fetchPollResults(for: pollId, optionIds: optionIds) { [weak self] results in
                    switch results {
                        case .failed:
                            os_log("Unable to fetch poll results.", log: .rover, type: .error)
                        case let .fetched(results):
                            // update local state!
                            os_log("Successfully fetched current poll results.", log: .rover, type: .debug)
                            self?.updateLocalStateWithResults(pollId: pollId, givenOptionIds: optionIds, pollFetchResponse: results)
                            
                            // chain fetch requests recursively, provided at least one subscriber exists for this poll.
                            if let _ = self?.stateSubscribers[pollId]?.first?.subscriber {
                                // 5 second delay on subsequent requests.
                                recursiveFetch(delay: 5)
                            }
                    }
                }
            }
        }
        
        recursiveFetch()
        
        // in the meantime, synchronously check local storage and immediately return the results:
        return (self.localStatusForPoll(pollId: pollId, givenOptionIds: optionIds), chit)
    }
    
    // MARK: State & Storage
    
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
    
    /// Internal representation for storage of poll state on disk.
    private struct PollState: Codable {
        let pollId: String
        
        /// The results retrieved for the poll, if available.  Poll Id -> Number of Votes.
        let optionResults: [String: Int]?
        
        /// If the user has voted, for which option did they vote?
        let userVotedForOptionId: String?
        
        func pollStatus() -> PollStatus {
            if let vote = self.userVotedForOptionId {
                // user voted, so show them the response.
                guard let optionResults = self.optionResults else {
                    // user voted but optionResults not stored.
                    os_log("User voted but local copy of option results is missing.", log: .rover, type: .fault)
                    return .waitingForAnswer
                }

                // couldn't use mapValues because I needed the key (option id) to do the transform.
                let optionStatuses = optionResults.keys.map { (optionId) in
                    return (optionId, PollsVotingService.OptionStatus(selected: vote == optionId, voteCount: optionResults[optionId]!))
                }.reduce(into: [String: PollsVotingService.OptionStatus]()) { (dictionary, tuple) in
                    let (optionId, optionStatus) = tuple
                    dictionary[optionId] = optionStatus
                }
                
                return .answered(resultsForOptions: optionStatuses)
            }
            return .waitingForAnswer
        }
    }
    
    private let storage = UserDefaults()

    private let urlSession = URLSession(configuration: URLSessionConfiguration.default)

    private func localStateForPoll(pollId: String, givenCurrentOptionIds optionIds: [String]) -> PollState {
        let decoder = JSONDecoder.init()
        if let existingPollsJson = self.storage.data(forKey: USER_DEFAULTS_STORAGE_KEY) {
            do {
                let pollStates = try decoder.decode([PollState].self, from: existingPollsJson)
                
                if let state = pollStates.first(where: { $0.pollId == pollId }), let storedOptions = state.optionResults {
                    if storedOptions.keys.sorted() == optionIds.sorted() {
                        // currently stored poll options match!
                        return state
                    } else {
                        os_log("Local poll state no longer matches the options given on the Poll itself. Considering poll state reset.", log: .rover, type: .fault)
                        return .init(pollId: pollId, optionResults: nil, userVotedForOptionId: nil)
                    }
                } else {
                    return .init(pollId: pollId, optionResults: nil, userVotedForOptionId: nil)
                }
            } catch {
                os_log("Existing storage for polls was corrupted: %s", error.debugDescription)
                return .init(pollId: pollId, optionResults: nil, userVotedForOptionId: nil)
            }
        }
        return .init(pollId: pollId, optionResults: nil, userVotedForOptionId: nil)
    }
    
    private func updateStorageForPoll(newState: PollState) {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let pollId = newState.pollId
        
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
        let newStates = [newState] + pollStates.filter { $0.pollId != pollId }
        
        // drop any stored states past 100:
        let trimmedNewStates: [PollState] = Array(newStates.prefix(100))
        
        do {
            let newStateJson = try encoder.encode(trimmedNewStates)
            // TODO: storage update dispatch.
            self.storage.set(newStateJson, forKey: USER_DEFAULTS_STORAGE_KEY)
            self.stateSubscribers[pollId]?.forEach { subscriber in
                DispatchQueue.main.async {
                    subscriber.subscriber?.callback(newState.pollStatus())
                }
            }
        } catch {
            os_log("Unable to update local poll storage: %s", log: .rover, type: .error, error.debugDescription)
            return
        }
        os_log("Updated local state for poll %s.", log: .rover, type: .debug, pollId)
    }
    
    private func localStatusForPoll(pollId: String, givenOptionIds optionIds: [String]) -> PollStatus {
        return localStateForPoll(pollId: pollId, givenCurrentOptionIds: optionIds).pollStatus()
    }
    
    private func updateLocalStateWithResults(pollId: String, givenOptionIds optionIds: [String], pollFetchResponse: PollFetchResponseBody) {
        // replace locally stored results with a new copy with the results part updated.
        let localState: PollState = self.localStateForPoll(pollId: pollId, givenCurrentOptionIds: optionIds)

        let newState = PollState(pollId: pollId, optionResults: pollFetchResponse.results, userVotedForOptionId: localState.userVotedForOptionId)
        self.updateStorageForPoll(newState: newState)
    }
    
    private func commitVoteToLocalState(pollId: String, givenOptionIds optionIds: [String], optionId: String) {
        let localState: PollState = self.localStateForPoll(pollId: pollId, givenCurrentOptionIds: optionIds)
       
        guard localState.userVotedForOptionId == nil else {
            os_log("User already voted.", log: .rover, type: .fault)
            return
        }
                
        let newState: PollState
        if var optionResults = localState.optionResults {
            // results with user's selection incremented.
            optionResults[optionId]? += 1
            newState = PollState(pollId: pollId, optionResults: optionResults, userVotedForOptionId: optionId)
        } else {
            newState = PollState(pollId: pollId, optionResults: localState.optionResults, userVotedForOptionId: optionId)
        }
        
        os_log("Recording vote for option %s on poll %s", log: .rover, type: .info, optionId, pollId)
        
        updateStorageForPoll(newState: newState)
    }
    
    // MARK: Network Requests

    private func fetchPollResults(for pollId: String, optionIds: [String], callback: @escaping (PollFetchResults) -> Void) {
        var url = URLComponents(string: "\(POLLS_SERVICE_ENDPOINT)\(pollId)")!
        url.queryItems = optionIds.map { URLQueryItem(name: "options", value: $0) }
        var request = URLRequest(url: url.url!)
        request.httpMethod = "GET"
        request.setRoverUserAgent()
        let task = self.urlSession.dataTask(with: request) { data, urlResponse, error in
            if let error = error {
                os_log("Unable to request poll results because: %s", log: .rover, type: .error, error.debugDescription)
                callback(.failed)
                return
            }
            
            guard let httpURLResponse = urlResponse as? HTTPURLResponse else {
                os_log("Unable to request poll results for an unknown reason.", log: .rover, type: .error)
                callback(.failed)
                return
            }
            
            if httpURLResponse.statusCode != 200 {
                if let errorBody = data {
                    let errorString = String(bytes: errorBody, encoding: .utf8)
                    os_log("Unable to request poll results due to application error: status code: %d, reason: %s", log: .rover, type: .error, httpURLResponse.statusCode, errorString ?? "empty")
                } else {
                    os_log("Unable to request poll results due to application error: status code %d.", log: .rover, type: .error, httpURLResponse.statusCode)
                }
                
                callback(.failed)
                return
            }
            
            guard let data = data else {
                os_log("Poll results fetch response body missing.", log: .rover, type: .error)
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .formatted(DateFormatter.rfc3339)
                
                let response = try decoder.decode(PollFetchResponseBody.self, from: data)
                callback(.fetched(results: response))
            } catch {
                os_log("Unable to decode poll results fetch response body: %s", log: .rover, type: .error, error.debugDescription)
            }
        }
        task.resume()
    }
    
    private func dispatchCastVoteRequest(pollId: String, optionId: String) {
        let url = URL(string: "\(POLLS_SERVICE_ENDPOINT)\(pollId)/vote")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setRoverUserAgent()
        let requestBody = VoteCastRequest(option: optionId)
        let data: Data
        do {
            let encoder = JSONEncoder()
            data = try encoder.encode(requestBody)
        } catch {
            os_log("Failed to encode poll cast vote request: %@", log: .rover, type: .error, error.debugDescription)
            return
        }
        
        var backgroundTaskID: UIBackgroundTaskIdentifier!
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Cast Poll Vote") {
            os_log("Failed to submit poll cast vote request: %@", log: .rover, type: .error, "App was suspended during submit")
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        
        let sessionTask = urlSession.uploadTask(with: request, from: data) { _, _, error in
            if let error = error {
                os_log("Failed to submit poll cast vote request: %@", log: .rover, type: .error, error.debugDescription)
            }
            
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        
        os_log("Submitting vote...", log: .rover, type: .debug)
        sessionTask.resume()
    }
    
    // MARK: Voting Service REST DTOs
    
    private struct VoteCastRequest: Codable {
        var option: String
    }
    
    private enum PollFetchResults {
        case fetched(results: PollFetchResponseBody)
        case failed
    }
    
    private struct PollFetchResponseBody: Codable {
        var results: [
            String: Int
        ]
    }
}

// MARK: External Helpers

extension TextPollBlock.TextPoll {
    /// Gather up votable option IDs from the options on this Poll, for  use with the PollsVotingService.
    var votableOptionIds: [String] {
        return self.options.map { option in
            option.id
        }
    }
}

extension ImagePollBlock.ImagePoll {
    /// Gather up votable option IDs from the options on this Poll, for  use with the PollsVotingService.
    var votableOptionIds: [String] {
        return self.options.map { option in
            option.id
        }
    }
}

// MARK: Internal Helpers

private extension Array where Element == PollsVotingService.SubscriberBox {
    func garbageCollected() -> [PollsVotingService.SubscriberBox] {
        self.filter { subscriberBox in
            subscriberBox.subscriber != nil
        }
    }
}

private extension Dictionary where Key == String, Value == [PollsVotingService.SubscriberBox] {
    func garbageCollected() -> [String: [PollsVotingService.SubscriberBox]] {
        self.mapValues { subscribers in
            return subscribers.garbageCollected()
        }
    }
}
