//
//  ExperienceStore.swift
//  Rover
//
//  Created by Sean Rucker on 2019-05-10.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import os.log

class ExperienceStore {
    /// The shared singleton experience store.
    static let shared = ExperienceStore()
    
    // MARK: Cache
    
    enum Identifier: Equatable, Hashable {
        case experienceURL(url: URL)
        case experienceID(id: String, useDraft: Bool)
    }
    
    private class CacheKey: NSObject {
        let identifier: Identifier
        
        init(identifier: Identifier) {
            self.identifier = identifier
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let rhs = object as? CacheKey else {
                return false
            }
            
            let lhs = self
            return lhs.identifier == rhs.identifier
        }
        
        override var hash: Int {
            return identifier.hashValue
        }
    }
    
    private class CacheValue: NSObject {
        let experience: Experience
        
        init(experience: Experience) {
            self.experience = experience
        }
    }
    
    private var cache = NSCache<CacheKey, CacheValue>()
    
    /// Return the experience for the given identifier from cache, provided that it has already been retrieved once
    /// in this session. Returns nil if the experience is not present in the cache.
    func experience(for identifier: Identifier) -> Experience? {
        let key = CacheKey(identifier: identifier)
        return cache.object(forKey: key)?.experience
    }
    
    // MARK: Fetching
    
    enum Failure: LocalizedError {
        case emptyResponseData
        case invalidResponseData(Error)
        case invalidStatusCode(Int)
        case networkError(Error?)
        
        var errorDescription: String? {
            switch self {
            case .emptyResponseData:
                return "Empty response data"
            case let .invalidResponseData(error):
                return "Invalid response data: \(error.localizedDescription)"
            case let .invalidStatusCode(statusCode):
                return "Invalid status code: \(statusCode)"
            case let .networkError(error):
                if let error = error {
                    return "Network error: \(error.localizedDescription)"
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
    
    private let session = URLSession(configuration: .default)
    private var tasks = [Identifier: URLSessionTask]()
    private var completionHandlers = [Identifier: [(Result<Experience, ExperienceStore.Failure>) -> Void]]()
    
    /// Fetch an experience for the given identifier from Rover's servers.
    ///
    /// Before making a network request the experience store will first attempt to retreive the experience from
    /// its cache and will return the cache result if found.
    func fetchExperience(for identifier: Identifier, completionHandler newHandler: @escaping (Result<Experience, ExperienceStore.Failure>) -> Void) {
        if !Thread.isMainThread {
            os_log("ExperienceStore is not thread-safe – fetchExperience should only be called from main thread.", log: .rover, type: .default)
        }
        
        let existingHandlers = completionHandlers[identifier, default: []]
        completionHandlers[identifier] = existingHandlers + [newHandler]
        
        if tasks[identifier] != nil {
            return
        }
        
        if let experience = experience(for: identifier) {
            invokeCompletionHandlers(
                for: identifier,
                with: .success(experience)
            )
            
            return
        }
        
        let queryItems = self.queryItems(identifier: identifier)
        let urlRequest = self.urlRequest(queryItems: queryItems)
        let task = session.dataTask(with: urlRequest) { data, urlResponse, error in
            let result: Result<Experience, ExperienceStore.Failure> = self.result(data: data, urlResponse: urlResponse, error: error)
            
            self.tasks[identifier] = nil
            
            defer {
                self.invokeCompletionHandlers(for: identifier, with: result)
            }
            
            switch result {
            case let .failure(error):
                os_log("Failed to fetch experience: %@", log: .rover, type: .error, error.localizedDescription)
            case let .success(experience):
                let key = CacheKey(identifier: identifier)
                let value = CacheValue(experience: experience)
                self.cache.setObject(value, forKey: key)
            }
        }
        
        tasks[identifier] = task
        task.resume()
    }
    
    private func queryItems(identifier: Identifier) -> [URLQueryItem] {
        var queryItems = [URLQueryItem]()
        
        let query: String
        switch identifier {
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
        
        struct RequestVariables: Encodable {
            let campaignURL: String?
            let id: String?
        }
        
        let variables: RequestVariables
        switch identifier {
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
    
    private func urlRequest(queryItems: [URLQueryItem]) -> URLRequest {
        let endpoint = URL(string: "https://api.rover.io/graphql")!
        var urlComponents = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = queryItems
        
        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("gzip", forHTTPHeaderField: "accept-encoding")
        
        assert(accountToken != nil, "Your Rover auth token has not been set.  Use Rover.accountToken = \"MY_TOKEN\".")
        urlRequest.setValue(accountToken, forHTTPHeaderField: "x-rover-account-token")
        urlRequest.setRoverUserAgent()
        return urlRequest
    }
    
    private func result(data: Data?, urlResponse: URLResponse?, error: Error?) -> Result<Experience, Failure> {
        if let error = error {
            return .failure(ExperienceStore.Failure.networkError(error))
        }
        
        guard let httpURLResponse = urlResponse as? HTTPURLResponse else {
            return .failure(ExperienceStore.Failure.networkError(nil))
        }
        
        if httpURLResponse.statusCode != 200 {
            let error = ExperienceStore.Failure.invalidStatusCode(httpURLResponse.statusCode)
            return .failure(error)
        }
        
        guard let data = data else {
            return .failure(ExperienceStore.Failure.emptyResponseData)
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(DateFormatter.rfc3339)
            
            struct Response: Decodable {
                struct Data: Decodable {
                    var experience: Experience
                }
                
                var data: Data
            }
            
            let response = try decoder.decode(Response.self, from: data)
            return .success(response.data.experience)
        } catch {
            let error = ExperienceStore.Failure.invalidResponseData(error)
            return .failure(error)
        }
    }
    
    private func invokeCompletionHandlers(for identifier: Identifier, with result: Result<Experience, ExperienceStore.Failure>) {
        let completionHandlers = self.completionHandlers[identifier, default: []]
        self.completionHandlers[identifier] = nil
        
        for completionHandler in completionHandlers {
            completionHandler(result)
        }
    }
}
