// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

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
