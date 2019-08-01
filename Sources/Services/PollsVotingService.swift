//
//  PollsVotingService.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-07-23.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import os
import UIKit

private let POLLS_SERVICE_ENDPOINT = "https://polls.staging.rover.io/v1/polls/"

class PollsVotingService {
    /// The shared singleton Voting Service.
    static let shared = PollsVotingService()
    
    // MARK: Types
    
    public struct OptionStatus {
        let selected: Bool
        let voteCount: Int
    }
    
    /// Yielded
    public enum PollStatus {
        case waitingForAnswer
        case answered(resultsForOptions: [String: OptionStatus])
    }
    
    private enum PollFetchResults {
        case fetched(results: PollFetchResponse)
        case failed
    }
    
    // TODO: decide if to actually promote this to API or not. If not, inline it right into the fetch function.
    public struct PollFetchResponse: Codable {
        var results: [
            String: Int
        ]
    }
    
    // TODO: Api Client
    
    // TODO: local storage for each poll: the last seen options list for the poll.  results for the poll, if any have been retrieved. What our vote was, if any.
    
    // TODO: aggregation behaviour -> for example, waiting to emit a poll result until the poll results have been retrieved.

    // Interface is going to be thus: separation of casting of votes and subscribing to updates.  also allow getting current state synchronously, to make the UI code simpler so an initial state can be available. so getting current state synchronously and subscribing to updates will be two separate methods, for convenience.
    
    /// Cast a vote on the poll.  Naturally may only be done once.  Synchronous, fire-and-forget, and best-effort. Any subscribers will be instantly notified (if possible) of the update.
    func castVote(pollId: String, optionId: String) {
        // TODO synchronously in local storage check for optionResults stored locally.  If present, update local state with dead-reckoned (+1 bump) values and then immediately emit an poll status update to subscribers.
        // then dispatch vote request task onto the queue.
        dispatchCastVoteRequest(pollId: pollId, optionId: optionId)
        
        commitVoteToLocalState(pollId: pollId, optionId: optionId)
        // if local state wasn't present, then either the results request didn't complete successfully or user tapped fast and thus we're racing it.
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
                    // dispatch to the serial queue:
                    self?.serialQueue.addOperation {
                        switch results {
                        case .failed:
                            os_log("Unable to fetch poll results.", log: .rover, type: .error)
                        case let .fetched(results):
                            // update local state!
                            os_log("Successfully fetched current poll results.", log: .rover, type: .debug)
                            self?.updateLocalStateWithResults(pollId: pollId, pollFetchResponse: results)
                            
                            // chain fetch requests recursively, provided at least one subscriber exists for this poll.
                            if let _ = self?.stateSubscribers[pollId]?.first?.subscriber {
                                // 5 second delay on subsequent requests.
                                recursiveFetch(delay: 5)
                            }
                        }
                    }
                }
            }
        }
        
        recursiveFetch()
        
        // in the meantime, synchronously check local storage and immediately return the results:
        return (self.localStateForPoll(pollId: pollId), chit)
        
        // TODO: implement a 5s timer, and then return a subscription chit to allow client to unsubscribe.
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
    
    //        private let storage = UserDefaults()
    // temporary shitty in-memory version just to get me going.
    private var storage = [String: String]()
    private let urlSession = URLSession(configuration: URLSessionConfiguration.default)
    
    private func localStateForPoll(pollId: String) -> PollStatus {
        let decoder = JSONDecoder.init()
        if let existingEntryJson = self.storage[pollId] {
            let localState: PollState
            do {
                localState = try decoder.decode(PollState.self, from: existingEntryJson.data(using: .utf8) ?? Data())
            } catch {
               os_log("Existing storage for poll was corrupted: %s", error.saneDescription)
               return .waitingForAnswer
            }
            
            return localState.pollStatus()
        }
        return .waitingForAnswer
    }
    
    private func updateLocalStateWithResults(pollId: String, pollFetchResponse: PollFetchResponse) {
        // replace locally stored results with a new copy with the results part updated.
        let localState: PollState
        if let existingEntryJson = self.storage[pollId] {
            do {
                let decoder = JSONDecoder()
                localState = try decoder.decode(PollState.self, from: existingEntryJson.data(using: .utf8) ?? Data())
            } catch {
               os_log("Existing storage for poll was corrupted: %s", error.saneDescription)
                localState = PollState(optionResults: pollFetchResponse.results, userVotedForOptionId: nil)
            }
        } else {
            localState = PollState(optionResults: nil, userVotedForOptionId: nil)
        }
        
        let newState = PollState(optionResults: pollFetchResponse.results, userVotedForOptionId: localState.userVotedForOptionId)
        self.updateStorageForPoll(pollId: pollId, withNewState: newState)
    }
    
    private func commitVoteToLocalState(pollId: String, optionId: String) {
        let localState: PollState
        if let existingEntryJson = self.storage[pollId] {
            do {
                let decoder = JSONDecoder()
                localState = try decoder.decode(PollState.self, from: existingEntryJson.data(using: .utf8) ?? Data())
            } catch {
               os_log("Existing storage for poll was corrupted: %s", log: .rover, type: .error, error.saneDescription)
                localState = PollState(optionResults: nil, userVotedForOptionId: nil)
            }
        } else {
            os_log("Recording a local vote before option results are available. This means user got their vote in before the results were fetched.  UI may wait for a moment while fetching continues.", log: .rover, type: .info)
            localState = PollState(optionResults: nil, userVotedForOptionId: nil)
        }
        
        guard localState.userVotedForOptionId == nil else {
            os_log("User already voted.", log: .rover, type: .fault)
            return
        }
                
        let newState: PollState
        if var optionResults = localState.optionResults {
            // results with user's selection incremented.
            optionResults[optionId]? += 1
            newState = PollState(optionResults: optionResults, userVotedForOptionId: optionId)
        } else {
            newState = PollState(optionResults: localState.optionResults, userVotedForOptionId: optionId)
        }
        
        os_log("Recording vote for option %s on poll %s", optionId, pollId)
        
        updateStorageForPoll(pollId: pollId, withNewState: newState)
    }
    
    private func updateStorageForPoll(pollId: String, withNewState newState: PollState) {
        let encoder = JSONEncoder()
        do {
            let newStateJson = try encoder.encode(newState)
            // TODO: storage update dispatch.
            self.storage[pollId] = String(data: newStateJson, encoding: .utf8)
            self.stateSubscribers[pollId]?.forEach { subscriber in
                DispatchQueue.main.async {
                    subscriber.subscriber?.callback(newState.pollStatus())
                }
            }
        } catch {
            os_log("Unable to update local poll storage: %s", error.saneDescription)
            return
        }
        os_log("Updated local state for poll %s.", log: .rover, type: .debug, pollId)
    }
    
    /// Synchronize operations that mutate local poll state.
    private let serialQueue: Foundation.OperationQueue = {
        let q = Foundation.OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    }()
    
    private func fetchPollResults(for pollId: String, optionIds: [String], callback: @escaping (PollFetchResults) -> Void) {
        var url = URLComponents(string: "\(POLLS_SERVICE_ENDPOINT)\(pollId)")!
        url.queryItems = optionIds.map { URLQueryItem(name: "options", value: $0) }
        var request = URLRequest(url: url.url!)
        request.httpMethod = "GET"
        request.setRoverUserAgent()
        let task = self.urlSession.dataTask(with: request) { data, urlResponse, error in
            if let error = error {
                os_log("Unable to request poll results because: %s", log: .rover, type: .error, error.saneDescription)
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
                
                let response = try decoder.decode(PollFetchResponse.self, from: data)
                callback(.fetched(results: response))
            } catch {
                os_log("Unable to decode poll results fetch response body: %s", log: .rover, type: .error, error.saneDescription)
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
            os_log("Failed to encode poll cast vote request: %@", log: .rover, type: .error, error.localizedDescription)
            return
        }
        
        var backgroundTaskID: UIBackgroundTaskIdentifier!
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Cast Poll Vote") {
            os_log("Failed to submit poll cast vote request: %@", log: .rover, type: .error, "App was suspended during submit")
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        
        let sessionTask = urlSession.uploadTask(with: request, from: data) { _, _, error in
            if let error = error {
                os_log("Failed to submit poll cast vote request: %@", log: .rover, type: .error, error.localizedDescription)
            }
            
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        
        os_log("Submitting vote...")
        sessionTask.resume()
    }
    
    private struct VoteCastRequest: Codable {
        var option: String
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


extension Error {
    var saneDescription: String {
        return "Error: \(self.localizedDescription), details: \((self as NSError).userInfo.debugDescription)"
    }
}

extension Dictionary where Value == Int {
    func percentagesWithDistributedRemainder() -> [Key: Int] {
        // Largest Remainder Method in order to enable us to produce nice integer percentage values for each option that all add up to 100%.
        let counts = self.map { $1 }
        
        let totalVotes = counts.reduce(0, +)
        
        let voteFractions = counts.map { votes in
            Double(votes) / Double(totalVotes)
        }
        
        let totalWithoutRemainders = voteFractions.map { value in
            Int(value.rounded(.down))
        }.reduce(0, +)
        
        let remainder = 100 - totalWithoutRemainders
        
        typealias OptionIdAndCount = (Key, Int)
        
        let optionsSortedByDecimal: [OptionIdAndCount] = self.sorted { (firstOption, secondOption) -> Bool in
            let firstOptionFraction = Double(firstOption.value) / Double(totalVotes)
            let secondOptionFraction = Double(secondOption.value) / Double(totalVotes)

            return secondOptionFraction > firstOptionFraction
        }

        // now to distribute the remainder (as whole integers) across the options.
        let distributed = optionsSortedByDecimal.enumerated().map { tuple -> OptionIdAndCount in
            let (offset, (optionId, voteCount)) = tuple
            if offset < remainder {
                return (optionId, voteCount + 1)
            } else {
                return (optionId, voteCount)
            }
        }
        
        // and turn it back into a dictionary:
        return distributed.reduce(into: [Key: Int]()) { (dictionary, optionIdAndCount) in
            let (optionId, voteCount) = optionIdAndCount
            dictionary[optionId] = voteCount
        }
    }
}

extension Array where Element == PollsVotingService.SubscriberBox {
    fileprivate func garbageCollected() -> [PollsVotingService.SubscriberBox] {
        self.filter { subscriberBox in
            subscriberBox.subscriber != nil
        }
    }
}

extension Dictionary where Key == String, Value == [PollsVotingService.SubscriberBox] {
    fileprivate func garbageCollected() -> [String: [PollsVotingService.SubscriberBox]] {
        self.mapValues { subscribers in
            return subscribers.garbageCollected()
        }
    }
}
