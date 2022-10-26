//
//  ExperiencesClient.swift
//  Rover
//
//  Created by Sean Rucker on 2018-09-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//


import Foundation
import os.log
import RoverData

protocol FetchExperienceClient {
    func task(with experienceIdentifier: ExperienceIdentifier, completionHandler: @escaping (Result<Experience, Failure>) -> Void) -> URLSessionTask
}

extension FetchExperienceClient {
    func queryItems(experienceIdentifier: ExperienceIdentifier) -> [URLQueryItem] {
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
        case let .experienceID(_, useDraft):
            if useDraft {
                query = """
                    query FetchExperienceByID($id: ID!) {
                        experience(id: $id, versionID: "current") {
                            ...experienceFields
                        }
                    }
                """
            } else {
                query = """
                    query FetchExperienceByID($id: ID!) {
                        experience(id: $id) {
                            ...experienceFields
                        }
                    }
                """
            }
        }
        
        let condensed = query.components(separatedBy: .whitespacesAndNewlines).filter {
            !$0.isEmpty
        }.joined(separator: " ")
        
        let queryItem = URLQueryItem(name: "query", value: condensed)
        queryItems.append(queryItem)
        
        let variables: RequestVariables
        switch experienceIdentifier {
        case let .experienceURL(url):
            variables = RequestVariables(campaignURL: url.absoluteString, id: nil)
        case let .experienceID(id, _):
            variables = RequestVariables(campaignURL: nil, id: id)
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(DateFormatter.rfc3339)
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
    
    func result(result: HTTPResult) -> Result<Experience, Failure> {
        switch result {
        case let .error(error, true), let .error(error, false):
            return .failure(Failure.networkError(error))
        case let .success(data):
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .formatted(DateFormatter.rfc3339)
                
                let response = try decoder.decode(Response.self, from: data)
                return .success(response.data.experience)
            } catch {
                let error = Failure.invalidResponseData(error, data)
                return .failure(error)
            }
        }
    }
}

// MARK: HTTPClient

extension HTTPClient: FetchExperienceClient {
    func task(with experienceIdentifier: ExperienceIdentifier, completionHandler: @escaping (Result<Experience, Failure>) -> Void) -> URLSessionTask {
        let queryItems = self.queryItems(experienceIdentifier: experienceIdentifier)
        let request = self.downloadRequest(queryItems: queryItems)
        
        return self.downloadTask(with: request) { httpResult in
            let result = self.result(result: httpResult)
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

enum Failure: LocalizedError {
    case emptyResponseData
    case invalidResponseData(Error, Data)
    case invalidStatusCode(Int)
    case networkError(Error?)
    
    var errorDescription: String? {
        switch self {
        case .emptyResponseData:
            return "Empty response data"
        case let .invalidResponseData(error, messageBody):
            return "Invalid response data: \(error.debugDescription), given message body: \(String(data: messageBody, encoding: .utf8) ?? "<binary>")"
        case let .invalidStatusCode(statusCode):
            return "Invalid status code: \(statusCode)"
        case let .networkError(error):
            if let error = error {
                return "Network error: \(error.debugDescription)"
            } else {
                return "Network error"
            }
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .emptyResponseData, .networkError:
            return true
        case .invalidResponseData, .invalidStatusCode:
            return false
        }
    }
}

// MARK: ExperienceIdentifier

enum ExperienceIdentifier: Equatable, Hashable {
    case experienceURL(url: URL)
    case experienceID(id: String, useDraft: Bool)
}

// MARK: AuthTokenNotConfiguredError

public class AuthTokenNotConfiguredError: Error {
}

