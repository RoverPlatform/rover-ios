//
//  ExperiencesClient.swift
//  RoverExperiences
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
    public func queryItems(experienceIdentifier: ExperienceIdentifier) -> [URLQueryItem] {
        var queryItems = [URLQueryItem]()
        
        let query: String
        switch experienceIdentifier {
        case .campaignID:
            query = """
                query FetchExperienceByCampaignID($campaignID: ID!) {
                    experience(campaignID: $campaignID) {
                        ...experienceFields
                    }
                }
                """
        case .campaignURL:
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
        
        let variables: Attributes
        switch experienceIdentifier {
        case .campaignID(let id):
            variables = ["campaignID": id]
        case .campaignURL(let url):
            variables = ["campaignURL": url]
        case .experienceID(let id):
            variables = ["id": id]
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
            case .error(let error, let isRetryable):
                if let error = error {
                    os_log("Failed to fetch experience: %@", log: .networking, type: .error, error.localizedDescription)
                } else {
                    os_log("Failed to fetch experience", log: .networking, type: .error)
                }
                
                result = .error(error: error, isRetryable: isRetryable)
            case .success(let data):
                let response: Response
                do {
                    response = try JSONDecoder.default.decode(Response.self, from: data)
                    result = .success(experience: response.data.experience)
                } catch {
                    os_log("Failed to decode experience: %@", log: .networking, type: .error, error.localizedDescription)
                    result = .error(error: error, isRetryable: false)
                }
            }
            
            completionHandler(result)
        }
    }
}

// MARK: Response

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
    case campaignID(id: ID)
    case campaignURL(url: URL)
    case experienceID(id: ID)
}
