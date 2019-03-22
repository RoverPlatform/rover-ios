//
//  ExperienceCache.swift
//  Rover
//
//  Created by Sean Rucker on 2019-03-22.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

enum ExperienceCache {
    class Key: NSObject {
        let experienceIdentifier: ExperienceIdentifier
        
        init(experienceIdentifier: ExperienceIdentifier) {
            self.experienceIdentifier = experienceIdentifier
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let rhs = object as? Key else {
                return false
            }
            
            let lhs = self
            return lhs.experienceIdentifier == rhs.experienceIdentifier
        }
        
        override var hash: Int {
            return experienceIdentifier.hashValue
        }
    }
    
    class Value: NSObject {
        let experience: Experience
        
        init(experience: Experience) {
            self.experience = experience
        }
    }
    
    static var shared = NSCache<Key, Value>()
}
