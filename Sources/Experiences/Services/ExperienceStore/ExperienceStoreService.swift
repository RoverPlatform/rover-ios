//
//  ExperienceStoreService.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2018-05-03.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

class ExperienceStoreService: ExperienceStore {
    let client: GraphQLClient
    let logger: Logger
    
    init(client: GraphQLClient, logger: Logger) {
        self.client = client
        self.logger = logger
    }
    
    func experience(for identifier: ExperienceIdentifier) -> Experience? {
        let key = CacheKey(experienceIdentifier: identifier)
        return cache.object(forKey: key)?.experience
    }
    
    // MARK: Cache
    
    class CacheKey: NSObject {
        let experienceIdentifier: ExperienceIdentifier
        
        init(experienceIdentifier: ExperienceIdentifier) {
            self.experienceIdentifier = experienceIdentifier
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let rhs = object as? CacheKey else {
                return false
            }
            
            let lhs = self
            return lhs.experienceIdentifier == rhs.experienceIdentifier
        }
        
        override var hash: Int {
            return experienceIdentifier.hashValue
        }
    }
    
    class CacheValue: NSObject {
        let experience: Experience
        
        init(experience: Experience) {
            self.experience = experience
        }
    }
    
    var cache = NSCache<CacheKey, CacheValue>()
    
    // MARK: Fetching Experiences
    
    struct FetchQuery: GraphQLOperation {
        struct Variables: Encodable {
            var identifier: ExperienceIdentifier
            
            private enum CodingKeys: String, CodingKey {
                case campaignID
                case campaignURL
                case id
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                switch identifier {
                case .campaignID(let id):
                    try container.encode(id, forKey: .campaignID)
                case .campaignURL(let url):
                    try container.encode(url, forKey: .campaignURL)
                case .experienceID(let id):
                    try container.encode(id, forKey: .id)
                }
            }
        }
        
        var query: String {
            switch variables!.identifier {
            case .campaignID:
                return """
                    query FetchExperienceByCampaignID($campaignID: ID!) {
                        experience(campaignID: $campaignID) {
                            ...experienceFields
                        }
                    }
                    """
            case .campaignURL:
                return """
                    query FetchExperienceByCampaignURL($campaignURL: String!) {
                        experience(campaignURL: $campaignURL) {
                            ...experienceFields
                        }
                    }
                    """
            case .experienceID:
                return """
                    query FetchExperienceByID($id: ID!) {
                        experience(id: $id) {
                        ...experienceFields
                        }
                    }
                    """
            }
        }
        
        var variables: Variables?
        
        var fragments: [String]? {
            return ["experienceFields"]
        }
        
        init(identifier: ExperienceIdentifier) {
            variables = Variables(identifier: identifier)
        }
    }
    
    struct FetchResponse: Decodable {
        struct Data: Decodable {
            var experience: Experience
        }
        
        var data: Data
    }
    
    var tasks = [ExperienceIdentifier: URLSessionTask]()
    var completionHandlers = [ExperienceIdentifier: [(FetchExperienceResult) -> Void]]()
    
    func fetchExperience(for identifier: ExperienceIdentifier, completionHandler: ((FetchExperienceResult) -> Void)?) {
        logger.warnUnlessMainThread("ExperienceStore is not thread-safe – fetchExperience should only be called from main thread.")
        
        if let newHandler = completionHandler {
            let existingHandlers = self.completionHandlers[identifier, default: []]
            self.completionHandlers[identifier] = existingHandlers + [newHandler]
        }
        
        if tasks[identifier] != nil {
            return
        }
        
        if let experience = experience(for: identifier) {
            let result = FetchExperienceResult.success(experience: experience)
            invokeCompletionHandlers(for: identifier, with: result)
        }
        
        let operation = FetchQuery(identifier: identifier)
        let task = client.task(with: operation) {
            self.tasks[identifier] = nil
            let result: FetchExperienceResult
            
            defer {
                self.invokeCompletionHandlers(for: identifier, with: result)
            }
            
            switch $0 {
            case .error(let error, let isRetryable):
                self.logger.error("Failed to fetch experience")
                if let error = error {
                    self.logger.error(error.localizedDescription)
                }
                
                result = FetchExperienceResult.error(error: error, isRetryable: isRetryable)
            case .success(let data):
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .formatted(DateFormatter.rfc3339)
                    let response = try decoder.decode(FetchResponse.self, from: data)
                    let experience = response.data.experience
                    let key = CacheKey(experienceIdentifier: identifier)
                    let value = CacheValue(experience: experience)
                    self.cache.setObject(value, forKey: key)
                    result = FetchExperienceResult.success(experience: experience)
                } catch {
                    self.logger.error("Failed to decode experience from GraphQL response")
                    self.logger.error(error.localizedDescription)
                    result = FetchExperienceResult.error(error: error, isRetryable: false)
                }
            }
        }
        
        tasks[identifier] = task
        task.resume()
    }
    
    func invokeCompletionHandlers(for identifier: ExperienceIdentifier, with result: FetchExperienceResult) {
        let completionHandlers = self.completionHandlers[identifier, default: []]
        self.completionHandlers[identifier] = nil
        
        for completionHandler in completionHandlers {
            completionHandler(result)
        }
    }
}
