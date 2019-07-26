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

class PollsVotingService {
    // MARK: Types
    
    public struct OptionStatus {
        let selected: Bool
        let fraction: Float
    }
    
    /// Yielded
    public enum PollStatus {
        case waitingForAnswer
        case answered(optionResults: [String: OptionStatus])
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
    
    //
    

    
    
    /// Cast a vote on the poll.  Naturally may only be done once.  Synchronous, fire-and-forget, and best-effort. Any subscribers will be instantly notified (if possible) of the update.
    func castVote(pollId: String, optionId: String) {
        // TODO synchronously in local storage check for optionResults stored locally.  If present, update local state with dead-reckoned (+1 bump) values and then immediately emit an poll status update to subscribers.
        // then dispatch vote request task onto the queue.
        
        // if local state wasn't present, then either the results request didn't complete successfully or user tapped fast and thus we're racing it.
    }
    
    /// Be notified of poll state.  Updates will be emitted on the main thread. Note that this will not immediately yield current state. Synchronously call `currentStateForPoll()` instead.
    func subscribeToUpdates(pollId: String, optionIds: [String], subscriber: (PollStatus) -> Void) -> PollStatus {
        // side-effect: kick off attempt to refresh PollResults.  That request will update the state in UserDefaults.
        
        self.fetchPollResults(for: pollId) { results in
            <#code#>
        }
        
        // synchronously check local storage:
        
        
        return .waitingForAnswer
    }

    
    // MARK: State & Storage
    
    /// Internal representation for storage of poll state on disk.
    private struct PollState: Codable {
//        let pollId: String
        
//        /// The options last seen for this poll.  If the options have changed, we will reset that state to allow the user to vote again.
//        let seenOptions: [String]
        
        /// The results retrieved for the poll, if available.  Poll Id -> Number of Votes.
        let optionResults: [String: Int]?
        
        /// If the user has voted, for which option did they vote?
        let userVotedForOptionId: String?
    }
    
//        private let storage = UserDefaults()
    // temporary shitty in-memory version just to get me going.
    private var storage = [String: String]()
    private let urlSession = URLSession(configuration: URLSessionConfiguration.default)
    
    private func localStateForPoll(pollId: String, currentOptionIds: [String]) -> PollStatus {
        let decoder = JSONDecoder.init()
        if let existingEntryJson = self.storage[pollId] {
            do {
                let decoded = try decoder.decode(PollState.self, from: existingEntryJson.data(using: .utf8) ?? Data())
                guard let vote = decoded.userVotedForOptionId else {
                    // TODO: do the Largest Remainder Method
                    
                    guard let results = decoded.optionResults else {
                        return .waitingForAnswer
                    }
                    
                    // Largest Remainder Method in order to enable us to produce nice integer percentage values for each option that all add up to 100%.
                    
                    let counts = results.map { $1 }
                    
                    let totalVotes = counts.reduce(0, +)
                    
                    let voteFractions = counts.map { votes in
                        Double(votes) / Double(totalVotes)
                    }
                    
                    let totalWithoutRemainders = voteFractions.map { value in
                        Int(value.rounded(.down))
                    }.reduce(0, +)
                    
                    let remainder = 100 - totalWithoutRemainders
                    

                    let optionsSortedByDecimal = results.sorted { (firstOption, secondOption) -> Bool in
                        let firstOptionFraction = Double(firstOption.value) / Double(totalVotes)
                        let secondOptionFraction = Double(secondOption.value) / Double(totalVotes)
                        let firstOptionDecimal = firstOption.value
                    }
                    
//
//
//                    let pollIdsToRemainders = results.mapValues { votes -> Double in
//                        let percentage = (Double(votes) / Double(totalVotes)) * 100
//                        let flooredDivision = percentage.rounded(.down)
//                        return percentage - flooredDivision
//                    }
//
//                    let totalRemainders = pollIdsToRemainders.map { $1 }.reduce(0, +)

                    
                    
                    let roundedOptions = results.map { (pollId, votes) in
                        
                    }
                    
                    return .answered(optionResults:
                }
            } catch {
                os_log("Existing storage for poll was corrupted: %s", error.saneDescription)
                return .answered(optionResults: <#T##PollsVotingService.OptionStatus#>)
            }
        }
    }
    
    /// Synchronize operations that mutate local poll state.
    private let serialQueue: Foundation.OperationQueue = {
        let q = Foundation.OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    }()
    
    private func fetchPollResults(for pollId: String, callback: @escaping (PollFetchResults) -> Void) {
        let url = URL(string: "\(POLLS_SERVICE_ENDPOINT)\(pollId)/vote")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
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
