//
//  PersistedValue.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2018-09-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import os.log

public class PersistedValue<T> where T: Codable {
    public let decoder: JSONDecoder
    public let encoder: JSONEncoder
    public let storageKey: String
    public let userDefaults: UserDefaults
    
    public var value: T? {
        get {
            switch T.self {
            case is Float.Type:
                return userDefaults.float(forKey: storageKey) as? T
            case is Double.Type:
                return userDefaults.double(forKey: storageKey) as? T
            case is Int.Type:
                return userDefaults.integer(forKey: storageKey) as? T
            case is Bool.Type:
                return userDefaults.bool(forKey: storageKey) as? T
            case is URL.Type:
                return userDefaults.url(forKey: storageKey) as? T
            default:
                guard let data = userDefaults.data(forKey: storageKey) else {
                    return nil
                }
                
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    os_log("Failed to decode persisted value: %@", log: .general, type: .error, error.logDescription)
                    return nil
                }
            }
        }
        set {
            guard let newValue = newValue else {
                userDefaults.removeObject(forKey: storageKey)
                return
            }
            
            switch newValue {
            case let newValue as Float:
                userDefaults.set(newValue, forKey: storageKey)
            case let newValue as Double:
                userDefaults.set(newValue, forKey: storageKey)
            case let newValue as Int:
                userDefaults.set(newValue, forKey: storageKey)
            case let newValue as Bool:
                userDefaults.set(newValue, forKey: storageKey)
            case let newValue as URL:
                userDefaults.set(newValue, forKey: storageKey)
            default:
                do {
                    let data = try encoder.encode(newValue)
                    userDefaults.set(data, forKey: storageKey)
                } catch {
                    os_log("Failed to encode persisted value: %@", log: .general, type: .error, error.logDescription)
                }
            }
        }
    }
    
    public init(
        storageKey: String,
        decoder: JSONDecoder = JSONDecoder.default,
        encoder: JSONEncoder = JSONEncoder.default,
        userDefaults: UserDefaults = UserDefaults.standard
    ) {
        self.decoder = decoder
        self.encoder = encoder
        self.storageKey = storageKey
        self.userDefaults = userDefaults
    }
}
