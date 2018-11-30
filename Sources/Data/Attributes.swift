//
//  Attributes.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-07-24.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import os

public class Attributes: NSObject, NSCoding, Codable {
    
    var rawValue: [String: Any]

    // MARK: NSCoding
    
    public func encode(with aCoder: NSCoder) {
        let nsDictionary = rawValue.attributes
        aCoder.encode(nsDictionary)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        guard let nsDictionary = aDecoder.decodeObject() as? NSDictionary else {
            return nil
        }
        rawValue = nsDictionary.attributes
        super.init()
    }
    
    // MARK: Codable
    
    public required init(from decoder: Decoder) throws {
        let type: Decodable.Type = Dictionary<String, Decodable>.self
        decoder.singleValueContainer().decode()
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        //
    }
    
    override init() {
        rawValue = [:]
        super.init()
    }
}

/// A dictionary of
///
/// Note that there are several constraints here not expressed in the Swift type.
///
/// The value type, Any, may only be one of:
///
/// String
/// Int
/// Double
/// Bool
/// [String]
/// [Int]
/// [Double]
/// [Bool]
/// [String: Any]
typealias AttributeValue = [String: Any]

protocol AttributeRepresentable {
    var attributeValue: AttributeValue { get }
}

extension Dictionary where Key == String, Value: Any {
    fileprivate var asAttributesForNsDictionary: [String: Any] {
        func transformAsNeeded(value: Any) -> Any? {
            switch(value) {
            case let bool as Bool:
                // The Nextstep standard library objects do not model Bool separately from Number, so converting our attributes dictionaries to NSDictionary otherwise unmodified would lose the distinction between the two types.  We work around this by creating our own `BooleanValue` type.
                return BooleanValue(bool)
            case is Int, is String, is Double:
                return value
            default:
                let errorMessage = "Unsupported type used in a Rover attributes dictionary: \(type(of: value))"
                assertionFailure(errorMessage)
                os_log("%s", type: .error, errorMessage)
                return nil
            }
        }
        
        return self.reduce(into: [String:Any]()) { (result, element) in
            // TODO verify element.key against "^[a-zA-Z_][a-zA-Z_0-9]*$"
            switch(element.value) {
            case let dictionary as Dictionary:
                // nesting!
                result[element.key] = dictionary.asAttributesForNsDictionary
            case let array as Array<Any>:
                // can only contain scalars
                result[element.key] = array.map { transformAsNeeded(value: $0) }
            default:
                guard let transformed = transformAsNeeded(value: element.value) else {
                    return
                }
                result[element.key] = transformed
            }
        }
    }
    
    var attributes: NSDictionary {
        let dictionary = NSDictionary()
        // setValuesForKeys coerces Swifty primitives to their NS* equivalents, however, in asAttributesForNsDictionary() we do a few extra transforms.
        // setValuesForKeys' equivalent in the opposite direction is NSDictionary.dictionaryWithValues
        dictionary.setValuesForKeys(self.asAttributesForNsDictionary)
        return dictionary
    }
    
    /// Undo the effects of [asAttributesForNsDictionary].
    fileprivate var fromAttributesAsNsDictionary: [String: Any] {
        
        func transformAsNeeded(value: Any) -> Any? {
            if let wrappedBoolean = value as? BooleanValue {
                // Unwrap our custom BooleanValue type back to the standard swift Bool.
                return wrappedBoolean.value
            } else {
                return value
            }
        }
        
        return self.reduce(into: [String:Any]()) { (result, element) in
            switch(element.value) {
            case let dictionary as Dictionary:
                // nesting!
                result[element.key] = dictionary.fromAttributesAsNsDictionary
            case let array as Array<Any>:
                result[element.key] = array.map { transformAsNeeded(value: $0) }
            default:
                guard let transformed = transformAsNeeded(value: element.value) else {
                    return
                }
                result[element.key] = transformed
            }
        }
    }
}

extension NSDictionary {
    var attributes: [String: Any] {
        guard let keys = self.allKeys as? [String] else {
            let seenKeyTypes = self.allKeys.map { (key) -> String in
                return String(describing: type(of: key))
            }.joined(separator: ", ")
            let errorMessage = "Unsupported key type appeared in attributes NSDictionary, one of: \(seenKeyTypes)"
            assertionFailure(errorMessage)
            os_log("%s", type: .error, errorMessage)
            return [:]
        }
        let dictionary = self.dictionaryWithValues(forKeys: keys)
        return dictionary.fromAttributesAsNsDictionary
    }
}

class BooleanValue: NSCoding, Codable {
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
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(Bool.self)
    }
    
    
    
    public func encode(to encoder: Encoder) throws {
        // TODO:
    }
}

// Possible valid VALUE types

// String
// Int
// Double
// Bool
// [String]
// [Int]
// [Double]
// [Bool]
// [String: Any]


//func updateUserInfo(block: (inout [String: Any] -> Void))
