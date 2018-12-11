//
//  Attributes.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-07-24.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import os

fileprivate let roverKeyRegex = try! NSRegularExpression(pattern: "^[a-zA-Z_][a-zA-Z_0-9]*$")

/// Wraps a [String: Any], but enables use of both NSCoding and Codable.  Enforces the Rover limitations on allowed types and nesting thereof (not readily capturable in the Swift type system) at runtime.
class Attributes: NSObject, NSCoding, Codable, RawRepresentable {
    var rawValue: [String: Any]
    
    public required init?(rawValue: [String:Any]) {
        do {
            try Attributes.validateDictionary(rawValue)
        } catch {
            os_log("Invalid Rover Attributes raw value, because: %s", log: .persistence, type: .error, error.localizedDescription)
            return nil
        }
        self.rawValue = rawValue
    }

    //
    // MARK: NSCoding
    //
    
    public func encode(with aCoder: NSCoder) {
        var boolToBoolean: ((Any) -> Any)!
        boolToBoolean = { anyValue in
            switch anyValue {
            case let value as Bool:
                return BooleanValue(value)
            case let value as [Bool]:
                return value.map { BooleanValue($0) }
            case let value as [String: Any]:
                return value.mapValues(boolToBoolean)
            default:
                return anyValue
            }
        }
        
        let nsDictionary = self.rawValue.mapValues(boolToBoolean) as Dictionary
        aCoder.encode(nsDictionary)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        guard let nsDictionary = aDecoder.decodeObject() as? NSDictionary else {
            return nil
        }
        
        let dictionary = nsDictionary.dictionaryWithValues(forKeys: nsDictionary.allKeys as! [String])
        
        func transformDictionary(dictionary: [String: Any]) -> [String: Any] {
            return dictionary.reduce(into: [String:Any]()) { (result, element) in
                switch(element.value) {
                // handle our custom boxed Boolean value type:
                case let value as BooleanValue:
                    result[element.key] = value.value
                case let array as [BooleanValue]:
                    result[element.key] = array.map { $0.value }
                case let dictionary as Dictionary<String, Any>:
                    // nesting!
                    result[element.key] = transformDictionary(dictionary: dictionary)
                
                default:
                    result[element.key] = element.value
                }
            }
        }
        
        self.rawValue = transformDictionary(dictionary: dictionary)
        
        do {
            try Attributes.validateDictionary(self.rawValue)
        } catch {
            os_log("Encountered invalid Rover Attributes while decoding from NSCoder, because: %s", log: .persistence, type: .error, error.localizedDescription)
            return nil
        }
        super.init()
    }
    
    fileprivate static func validateDictionary(_ dictionary: [String: Any]) throws {
        try dictionary.forEach { (key, value) in
            let swiftRange = Range(uncheckedBounds: (key.startIndex, key.endIndex))
            let nsRange = NSRange(swiftRange, in: key)
            if roverKeyRegex.matches(in: key, range: nsRange).count == 0 {
                throw AttributesError.invalidKey(key: key)
            }
            
            if let nestedDictionary = value as? [String: Any] {
                try validateDictionary(nestedDictionary)
                return
            }
            
            if !(
                value is Double ||
                value is Int ||
                value is String ||
                value is Bool ||
                value is [Double] ||
                value is [Int] ||
                value is [String] ||
                value is [Bool]
            )  {
                throw AttributesError.invalidValue(key: key, type: type(of: value))
            }
        }
    }
    
    enum AttributesError: Error, LocalizedError {
        case invalidKey(key: String)
        case invalidValue(key: String, type: Any.Type)
        
        var errorDescription: String? {
            switch self {
            case .invalidKey(let key):
                return "Invalid key: \(key)"
            case .invalidValue(let key, let type):
                return "Invalid value for key \(key) with unsupported type: \(String.init(describing: type))"
            }
        }
    }
    
    //
    // MARK: Codable
    //
    
    /// This implementation of CodingKey allows for handling data without strongly and statically typed keys with Codable.
    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        
        init(stringValue: String) {
            self.stringValue = stringValue
        }
        
        var intValue: Int? {
            return nil
        }
        
        init?(intValue: Int) {
            return nil
        }
    }
    
    required public init(from decoder: Decoder) throws {
        func fromKeyedDecoder(_ container: KeyedDecodingContainer<Attributes.DynamicCodingKeys>) throws -> [String:Any] {
            var assembledHash = [String: Any]()

            try container.allKeys.forEach { key in
                let keyString = key.stringValue
                if let value = try? container.decode(Bool.self, forKey: key) {
                    assembledHash[keyString] = value
                    return
                }
                
                if let value = try? container.decode(Int.self, forKey: key) {
                    assembledHash[keyString] = value
                    return
                }
                
                if let value = try? container.decode(String.self, forKey: key) {
                    assembledHash[keyString] = value
                    return
                }
                
                // now try probing for an embedded dict.
                if let dictionary = try? container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: key) {
                    assembledHash[keyString] = try fromKeyedDecoder(dictionary)
                    return
                }
                
                // we also support arrays of primitive values:
                
                if let array = try? container.decode([String].self, forKey: key) {
                    assembledHash[keyString] = array
                    return
                }
                
                if let array = try? container.decode([Bool].self, forKey: key) {
                    assembledHash[keyString] = array
                    return
                }
                
                if let array = try? container.decode([Int].self, forKey: key) {
                    assembledHash[keyString] = array
                    return
                }
                
                if let array = try? container.decode([Double].self, forKey: key) {
                    assembledHash[keyString] = array
                    return
                }
                
                throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Expected one of Int, String, Double, Bool, or an Array thereof.")
            }
            
            return assembledHash
        }
        
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        self.rawValue = try fromKeyedDecoder(container)
    }
    
    public func encode(to encoder: Encoder) throws {
        /// nested function for recursing through the dictionary and populating the Encoder with it, doing the necessary type coercions on the way.
        func encodeToContainer(dictionary: [String: Any], container: inout KeyedEncodingContainer<Attributes.DynamicCodingKeys>) throws {
            try dictionary.forEach { (codingKey, value) in
                let key = DynamicCodingKeys(stringValue: codingKey)
                switch value {
                case let value as Int:
                    try container.encode(value, forKey: key)
                case let value as Bool:
                    try container.encode(value, forKey: key)
                case let value as String:
                    try container.encode(value, forKey: key)
                case let value as Double:
                    try container.encode(value, forKey: key)
                case let value as [Int]:
                    try container.encode(value, forKey: key)
                case let value as [Bool]:
                    try container.encode(value, forKey: key)
                case let value as [Double]:
                    try container.encode(value, forKey: key)
                case let value as [String]:
                    try container.encode(value, forKey: key)
                case let value as Dictionary<String, Any>:
                    var nestedContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: key)
                    try encodeToContainer(dictionary: value, container: &nestedContainer)
                default:
                    let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unexpected attribute value type. Expected one of Int, String, Double, Boolean, or an array thereof, or a dictionary of all of the above including arrays.")
                    throw EncodingError.invalidValue(value, context)
                }
            }
        }
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)

        try encodeToContainer(dictionary: self.rawValue, container: &container)
    }
    
    override init() {
        rawValue = [:]
        super.init()
    }
}

class BooleanValue: NSObject, NSCoding {
    public var value: Bool
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(value, forKey: "value")
    }
    
    required init?(coder aDecoder: NSCoder) {
        value = aDecoder.decodeBool(forKey: "value")
    }
    
    init(_ value: Bool) {
        self.value = value
    }
}
