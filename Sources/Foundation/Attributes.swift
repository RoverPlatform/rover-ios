//
//  Attributes.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2018-07-24.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import os

// We have a strong guarantee that this will complete. Very deterministic, done in static context at startup, so silence the force try warning.
// swiftlint:disable:next force_try
private let roverKeyRegex = try! NSRegularExpression(pattern: "^[a-zA-Z_][a-zA-Z_0-9]*$")

/// Wraps a [String: Any], a dictionary of values, but enables use of both NSCoding and Codable.  Enforces the Rover limitations on allowed types and nesting thereof (not readily capturable in the Swift type system) at runtime.
///
/// Note that there are several constraints here, enforced by the Rover cloud API itself, not expressed in the Swift type.  Namely, arrays may not be present within dictionaries or other arrays.  These are checked at runtime.
///
/// Thus:
///
/// * `String`
/// * `Int`
/// * `Double`
/// * `Bool`
/// * `[String]`
/// * `[Int]`
/// * `[Double]`
/// * `[Bool]`
/// * `[String: Any]` (where Any may be any of these given types)
public class Attributes: NSObject, NSCoding, Codable, RawRepresentable, ExpressibleByDictionaryLiteral {
    public var rawValue: [String: Any]
    
    public required init(rawValue: [String: Any]) {
        // transform nested dictionaries to Attributes, if needed.
        let nestedDictionariesTransformedToAttributes = rawValue.mapValues { value -> Any in
            if let dictionary = value as? [String: Any] {
                return Attributes(rawValue: dictionary) as Any? ?? Attributes()
            } else {
                return value
            }
        }
        
        self.rawValue = Attributes.validateDictionary(nestedDictionariesTransformedToAttributes)
    }
    
    public required init(dictionaryLiteral elements: (String, Any)...) {
        let dictionary = elements.reduce(into: [String: Any]()) { result, element in
            let (key, value) = element
            result[key] = value
        }
        // transform nested dictionaries to Attributes, if needed.
        let nestedDictionariesTransformedToAttributes = dictionary.mapValues { value -> Any in
            if let dictionary = value as? [String: Any] {
                return Attributes(rawValue: dictionary) as Any? ?? Attributes()
            } else {
                return value
            }
        }
        
        self.rawValue = Attributes.validateDictionary(nestedDictionariesTransformedToAttributes)
    }
    
    //
    // MARK: Subscript
    //
    
    public subscript(index: String) -> Any? {
        get {
            return rawValue[index]
        }
        
        set(newValue) {
            rawValue[index] = newValue
        }
    }
    
    //
    // MARK: NSCoding
    //
    
    public func encode(with aCoder: NSCoder) {
        var boolToBoolean: ((Any) -> Any)
        boolToBoolean = { anyValue in
            switch anyValue {
            case let value as Bool:
                return BooleanValue(value)
            case let value as [Bool]:
                return value.map { BooleanValue($0) }
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
            return dictionary.reduce(into: [String: Any]()) { result, element in
                switch element.value {
                // handle our custom boxed Boolean value type:
                case let value as BooleanValue:
                    result[element.key] = value.value
                case let array as [BooleanValue]:
                    result[element.key] = array.map { $0.value }
                case let attributesDictionary as Attributes:
                    // if a nested dictionary is already attributes, then pass it through.
                    result[element.key] = attributesDictionary
                default:
                    result[element.key] = element.value
                }
            }
        }
        
        self.rawValue = Attributes.validateDictionary(transformDictionary(dictionary: dictionary))
        
        super.init()
    }
    
    fileprivate static func validateDictionary(_ dictionary: [String: Any]) -> [String: Any] {
        var transformed: [String: Any] = [:]
        // This is a set of mappings of types, which makes for a long closure body, so silence the closure length warning.
        // swiftlint:disable:next closure_body_length
        dictionary.forEach { key, value in
            let swiftRange = Range(uncheckedBounds: (key.startIndex, key.endIndex))
            let nsRange = NSRange(swiftRange, in: key)
            if roverKeyRegex.matches(in: key, range: nsRange).isEmpty {
                assertionFailureEmitter("Invalid key: \(key)")
                return
            }
            
            if let nestedDictionary = value as? Attributes {
                transformed[key] = nestedDictionary
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
                ) {
                let valueType = type(of: value)
                assertionFailureEmitter("Invalid value for key \(key) with unsupported type: \(String(describing: valueType))")
                return
            }
            transformed[key] = value
        }
        return transformed
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
    
    public required init(from decoder: Decoder) throws {
        func fromKeyedDecoder(_ container: KeyedDecodingContainer<Attributes.DynamicCodingKeys>) throws -> Attributes {
            var assembledHash = [String: Any]()
            
            // This is a set of mappings of types, which makes for a long closure body, so silence the closure length warning.
            // swiftlint:disable:next closure_body_length
            try container.allKeys.forEach { key in
                let keyString = key.stringValue
                
                // primitive values:
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
            
            return Attributes(rawValue: assembledHash)
        }
        
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        self.rawValue = try fromKeyedDecoder(container).rawValue
    }
    
    public func encode(to encoder: Encoder) throws {
        /// nested function for recursing through the dictionary and populating the Encoder with it, doing the necessary type coercions on the way.
        func encodeToContainer(dictionary: [String: Any], container: inout KeyedEncodingContainer<Attributes.DynamicCodingKeys>) throws {
            // This is a set of mappings of types, which makes for a long closure body, so silence the function length warning.
            // swiftlint:disable:next closure_body_length
            try dictionary.forEach { codingKey, value in
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
                case let value as Attributes:
                    var nestedContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: key)
                    try encodeToContainer(dictionary: value.rawValue, container: &nestedContainer)
                default:
                    let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unexpected attribute value type. Expected one of Int, String, Double, Boolean, or an array thereof, or a dictionary of all of the above including arrays. Got \(type(of: value))")
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
    
    static func wasAssertionThrown(operation: () -> Void) -> Bool {
        let originalEmitter = assertionFailureEmitter
        var thrown = false
        assertionFailureEmitter = { message in
            os_log("Attributes assertion thrown: %s", message)
            thrown = true
        }
        
        operation()
        assertionFailureEmitter = originalEmitter
        return thrown
    }
    
    /// Needed so tests can override the method of emitting assertion failures.
    private static var assertionFailureEmitter: (String) -> Void = { message in
        assertionFailure(message)
    }
}

class BooleanValue: NSObject, NSCoding {
    var value: Bool
    
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
