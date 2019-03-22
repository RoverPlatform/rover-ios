//
//  ExperienceStoreService.swift
//  Rover
//
//  Created by Sean Rucker on 2018-05-03.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import os.log

public class ExperienceStoreService: ExperienceStore {
    let client: FetchExperienceClient
    
    init(client: FetchExperienceClient) {
        self.client = client
    }
    
    /// Return the experience for the given identifier from the cache, provided that it has already been retrieved once in this session.
    /// Returns nil if experience is not present in the cache.
    public func experience(for identifier: ExperienceIdentifier) -> Experience? {
        let key = ExperienceCache.Key(experienceIdentifier: identifier)
        return ExperienceCache.shared.object(forKey: key)?.experience
    }
    
    // MARK: Fetching Experiences
    
    var tasks = [ExperienceIdentifier: URLSessionTask]()
    var completionHandlers = [ExperienceIdentifier: [(FetchExperienceResult) -> Void]]()
    
    /// Asynchronously retrieve the given experience from the network.
    public func fetchExperience(for identifier: ExperienceIdentifier, completionHandler: ((FetchExperienceResult) -> Void)?) {
        if !Thread.isMainThread {
            os_log("ExperienceStore is not thread-safe – fetchExperience should only be called from main thread.", log: .rover, type: .default)
        }
        
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
        
        let task = client.task(with: identifier) { result in
            self.tasks[identifier] = nil
            
            defer {
                self.invokeCompletionHandlers(for: identifier, with: result)
            }
            
            guard case .success(let experience) = result else {
                return
            }
            
            let key = ExperienceCache.Key(experienceIdentifier: identifier)
            let value = ExperienceCache.Value(experience: experience)
            ExperienceCache.shared.setObject(value, forKey: key)
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
