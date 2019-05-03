//
//  ExperiencesClient.swift
//  Rover
//
//  Created by Sean Rucker on 2018-09-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import os.log

public protocol FetchExperienceClient {
    func task(with experienceIdentifier: ExperienceIdentifier, completionHandler: @escaping (FetchExperienceResult) -> Void) -> URLSessionTask
}

extension FetchExperienceClient {
    // swiftlint:disable function_body_length // Function is decently readable.
    public func queryItems(experienceIdentifier: ExperienceIdentifier) -> [URLQueryItem] {
        var queryItems = [URLQueryItem]()
        
        let query: String
        switch experienceIdentifier {
        case .experienceURL:
            query = """
                query FetchExperienceByCampaignURL($campaignURL: String!) {
                    experience(campaignURL: $campaignURL) {
                        ...experienceFields
                    }
                }
                """
        case .experienceID:
            query = """
                query FetchExperienceByID($id: ID!) {
                    experience(id: $id) {
                        ...experienceFields
                    }
                }
                """
        }
        
        let condensed = query.components(separatedBy: .whitespacesAndNewlines).filter {
            !$0.isEmpty
        }.joined(separator: " ")
        
        let queryItem = URLQueryItem(name: "query", value: condensed)
        queryItems.append(queryItem)
        
        let variables: RequestVariables
        switch experienceIdentifier {
        case .experienceURL(let url):
            variables = RequestVariables(campaignURL: url.absoluteString, id: nil)
        case .experienceID(let id):
            variables = RequestVariables(campaignURL: nil, id: id)
        }
        
        let encoder = JSONEncoder.default
        if let encoded = try? encoder.encode(variables) {
            let value = String(data: encoded, encoding: .utf8)
            let queryItem = URLQueryItem(name: "variables", value: value)
            queryItems.append(queryItem)
        }
        
        let fragments = ["experienceFields"]
        if let encoded = try? encoder.encode(fragments) {
            let value = String(data: encoded, encoding: .utf8)
            let queryItem = URLQueryItem(name: "fragments", value: value)
            queryItems.append(queryItem)
        }
        
        return queryItems
    }
}

// MARK: HTTPClient

extension HTTPClient: FetchExperienceClient {
    public func task(with experienceIdentifier: ExperienceIdentifier, completionHandler: @escaping (FetchExperienceResult) -> Void) -> URLSessionTask {
        let queryItems = self.queryItems(experienceIdentifier: experienceIdentifier)
        let request = self.downloadRequest(queryItems: queryItems)
        
        return self.downloadTask(with: request) {
            let result: FetchExperienceResult
            switch $0 {
            case let .error(error, isRetryable):
                if let error = error {
                    os_log("Failed to fetch experience: %@", log: .rover, type: .error, error.localizedDescription)
                } else {
                    os_log("Failed to fetch experience", log: .rover, type: .error)
                }
                
                result = .error(error: error, isRetryable: isRetryable)
            case .success(let data):
                let response: Response
                do {
                    response = try JSONDecoder.default.decode(Response.self, from: data)
                    result = .success(experience: response.data.experience)
                } catch {
                    os_log("Failed to decode experience: %@", log: .rover, type: .error, error.localizedDescription)
                    result = .error(error: error, isRetryable: false)
                }
            }
            
            completionHandler(result)
        }
    }
}

// MARK: Responses

private struct RequestVariables: Encodable {
    let campaignURL: String?
    let id: String?
}

private struct Response: Decodable {
    struct Data: Decodable {
        var experience: Experience
    }
    
    var data: Data
}

// MARK: FetchExperienceResult

public enum FetchExperienceResult {
    case error(error: Error?, isRetryable: Bool)
    case success(experience: Experience)
}

// MARK: ExperienceIdentifier

public enum ExperienceIdentifier: Equatable, Hashable {
    case experienceURL(url: URL)
    case experienceID(id: String)
}

// MARK: AuthTokenNotConfiguredError

public class AuthTokenNotConfiguredError: Error {
}

// MARK: Serialization

extension DateFormatter {
    public static let rfc3339: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

extension JSONDecoder {
    public static let `default`: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.rfc3339)
        return decoder
    }()
}

extension JSONEncoder {
    public static let `default`: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(DateFormatter.rfc3339)
        return encoder
    }()
}
