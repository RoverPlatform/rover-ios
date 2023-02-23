// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation
import UIKit
import os

// MARK: Network Requests

private let POLLS_SERVICE_ENDPOINT = "https://polls.rover.io/v1/polls/"

extension URLSession {
    func fetchPollResults(for pollID: String, optionIDs: [String], callback: @escaping (PollFetchResults) -> Void) {
        var url = URLComponents(string: "\(POLLS_SERVICE_ENDPOINT)\(pollID)")!
        url.queryItems = optionIDs.map { URLQueryItem(name: "options", value: $0) }
        var request = URLRequest(url: url.url!)
        request.httpMethod = "GET"
        request.setRoverUserAgent()
        let task = self.dataTask(with: request) { data, urlResponse, error in
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
                callback(.fetched(results: response.results))
            } catch {
                os_log("Unable to decode poll results fetch response body: %s", log: .rover, type: .error, error.debugDescription)
            }
        }
        task.resume()
    }
    
    func castVote(pollID: String, optionID: String, callback: @escaping (CastVoteResults) -> Void) {
        let url = URL(string: "\(POLLS_SERVICE_ENDPOINT)\(pollID)/vote")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setRoverUserAgent()
        let requestBody = VoteCastRequest(option: optionID)
        let data: Data
        do {
            let encoder = JSONEncoder()
            data = try encoder.encode(requestBody)
        } catch {
            os_log("Failed to encode poll cast vote request: %@", log: .rover, type: .error, error.debugDescription)
            return
        }

        
        let task = self.uploadTask(with: request, from: data) { data, urlResponse, error in
            if let error = error {
                os_log("Unable to request a poll vote cast because: %s", log: .rover, type: .error, error.debugDescription)
                callback(.failed)
                return
            }
            
            guard let httpURLResponse = urlResponse as? HTTPURLResponse else {
                os_log("Unable to request a poll vote cast for an unknown reason.", log: .rover, type: .error)
                callback(.failed)
                return
            }
            
            if httpURLResponse.statusCode != 200 {
                if let errorBody = data {
                    let errorString = String(bytes: errorBody, encoding: .utf8)
                    os_log("Unable to request a poll vote cast due to application error: status code: %d, reason: %s", log: .rover, type: .error, httpURLResponse.statusCode, errorString ?? "empty")
                } else {
                    os_log("Unable to request a poll vote cast due to application error: status code %d.", log: .rover, type: .error, httpURLResponse.statusCode)
                }
                
                callback(.failed)
                return
            }

            callback(.succeeded)
        }
        
        os_log("Submitting vote...", log: .rover, type: .debug)
        task.resume()
    }
}

// MARK: Voting Service REST DTOs

private struct VoteCastRequest: Codable {
    var option: String
}

private struct PollFetchResponseBody: Codable {
    var results: PollResults
}

enum PollFetchResults {
    case fetched(results: PollResults)
    case failed
}

enum CastVoteResults {
    case succeeded
    case failed
}

// MARK: Types

/// Poll results, mapping Option IDs -> Vote Counts.
typealias PollResults = [String: Int]

/// An option voted for by the user, the Option ID.
typealias PollAnswer = String
