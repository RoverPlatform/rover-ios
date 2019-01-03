//
//  ExperienceStoreService.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-05-03.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import os

class ExperienceStoreService: ExperienceStore {
    func get(byID id: String) -> Experience? {
        
    }
    
    func insert(experience: Experience) {
        // ANDREW START HERE run experience through codable and store it on disk at experiencePath
    }
    
    private func experiencePath(id: String) -> String? {
        var experiencesDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        experiencesDirectory.appendPathComponent("io.rover")
        experiencesDirectory.appendPathComponent("experiences")

        if !FileManager.default.directoryExists(at: experiencesDirectory) {
            do {
                try FileManager.default.createDirectory(at: experiencesDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                os_log("Experiences storage directory did not exist, and unable to create it.  Unable to store experiences.  Reason: %s", log: .persistence, type: .error, error.localizedDescription)
                return nil
            }
        }
        
        experiencesDirectory.appendPathComponent(id)
        experiencesDirectory.appendPathExtension("json")
        return experiencesDirectory.path
    }
    
    
//    let client: FetchExperienceClient
//
//    init(client: FetchExperienceClient) {
//        self.client = client
//    }
//
//    func experience(for identifier: ExperienceIdentifier) -> Experience? {
//        let key = CacheKey(experienceIdentifier: identifier)
//        return cache.object(forKey: key)?.experience
//    }
//
//    // MARK: Cache
//
//    class CacheKey: NSObject {
//        let experienceIdentifier: ExperienceIdentifier
//
//        init(experienceIdentifier: ExperienceIdentifier) {
//            self.experienceIdentifier = experienceIdentifier
//        }
//
//        override func isEqual(_ object: Any?) -> Bool {
//            guard let rhs = object as? CacheKey else {
//                return false
//            }
//
//            let lhs = self
//            return lhs.experienceIdentifier == rhs.experienceIdentifier
//        }
//
//        override var hash: Int {
//            return experienceIdentifier.hashValue
//        }
//    }
//
//    class CacheValue: NSObject {
//        let experience: Experience
//
//        init(experience: Experience) {
//            self.experience = experience
//        }
//    }
//
//    var cache = NSCache<CacheKey, CacheValue>()
//
//    // MARK: Fetching Experiences
//
//    var tasks = [ExperienceIdentifier: URLSessionTask]()
//    var completionHandlers = [ExperienceIdentifier: [(FetchExperienceResult) -> Void]]()
//
//    func fetchExperience(for identifier: ExperienceIdentifier, completionHandler: ((FetchExperienceResult) -> Void)?) {
//        if !Thread.isMainThread {
//            os_log("ExperienceStore is not thread-safe – fetchExperience should only be called from main thread.", log: .general, type: .default)
//        }
//
//        if let newHandler = completionHandler {
//            let existingHandlers = self.completionHandlers[identifier, default: []]
//            self.completionHandlers[identifier] = existingHandlers + [newHandler]
//        }
//
//        if tasks[identifier] != nil {
//            return
//        }
//
//        if let experience = experience(for: identifier) {
//            let result = FetchExperienceResult.success(experience: experience)
//            invokeCompletionHandlers(for: identifier, with: result)
//        }
//
//        let task = client.task(with: identifier) { result in
//            self.tasks[identifier] = nil
//
//            defer {
//                self.invokeCompletionHandlers(for: identifier, with: result)
//            }
//
//            guard case .success(let experience) = result else {
//                return
//            }
//
//            let key = CacheKey(experienceIdentifier: identifier)
//            let value = CacheValue(experience: experience)
//            self.cache.setObject(value, forKey: key)
//        }
//
//        tasks[identifier] = task
//        task.resume()
//    }
//
//    func invokeCompletionHandlers(for identifier: ExperienceIdentifier, with result: FetchExperienceResult) {
//        let completionHandlers = self.completionHandlers[identifier, default: []]
//        self.completionHandlers[identifier] = nil
//
//        for completionHandler in completionHandlers {
//            completionHandler(result)
//        }
//    }
}

extension FileManager {
    func directoryExists(at: URL) -> Bool {
        var returnBool : ObjCBool
        if self.fileExists(atPath: at.path, isDirectory: &returnBool) {
            return returnBool.boolValue
        } else {
            return false
        }
    }
}
