//
//  ExperienceStoreService.swift
//  Rover
//
//  Created by Sean Rucker on 2019-05-10.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import os.log
import RoverFoundation
import RoverData

class ExperienceStoreService: ExperienceStore {
    let client: FetchExperienceClient
    
    init(client: FetchExperienceClient) {
        self.client = client
    }
    
    private class CacheKey: NSObject {
        let identifier: ExperienceIdentifier
        
        init(identifier: ExperienceIdentifier) {
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
    func experience(for identifier: ExperienceIdentifier) -> Experience? {
        let key = CacheKey(identifier: identifier)
        return cache.object(forKey: key)?.experience
    }
    
    private var tasks = [ExperienceIdentifier: URLSessionTask]()
    private var completionHandlers = [ExperienceIdentifier: [(Result<Experience, Failure>) -> Void]]()
    
    /// Fetch an experience for the given identifier from Rover's servers.
    ///
    /// Before making a network request the experience store will first attempt to retreive the experience from
    /// its cache and will return the cache result if found.
    func fetchExperience(for identifier: ExperienceIdentifier, completionHandler newHandler: @escaping (Result<Experience, Failure>) -> Void) {
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
        
        let task = client.task(with: identifier) { result in
            self.tasks[identifier] = nil
            
            defer {
                self.invokeCompletionHandlers(for: identifier, with: result)
            }
            
            switch result {
            case let .failure(error):
                os_log("Failed to fetch experience: %@", log: .rover, type: .error, error.debugDescription)
            case let .success(experience):
                let key = CacheKey(identifier: identifier)
                let value = CacheValue(experience: experience)
                self.cache.setObject(value, forKey: key)
            }
        }
        
        tasks[identifier] = task
        task.resume()
    }
    
    private func invokeCompletionHandlers(for identifier: ExperienceIdentifier, with result: Result<Experience, Failure>) {
        let completionHandlers = self.completionHandlers[identifier, default: []]
        self.completionHandlers[identifier] = nil
        
        for completionHandler in completionHandlers {
            completionHandler(result)
        }
    }
}
