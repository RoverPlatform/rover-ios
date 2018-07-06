//
//  Attributes.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2018-05-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public typealias AttributeKey = String

public protocol AttributeValue { }

extension String: AttributeValue { }
extension Int: AttributeValue { }
extension UInt: AttributeValue { }
extension Double: AttributeValue { }
extension Float: AttributeValue { }
extension Bool: AttributeValue { }
extension Date: AttributeValue { }
extension URL: AttributeValue { }
extension Array: AttributeValue where Element == String { }

public struct Attributes {
    var contents = [AttributeKey: AttributeValue]()
    
    public var count: Int {
        return contents.count
    }
    
    public init() { }
}

// MARK: Subscript

extension Attributes {
    public subscript(key: AttributeKey) -> AttributeValue? {
        get {
            return contents[key]
        }
        
        set {
            switch newValue {
            case is String, is Int, is UInt, is Double, is Float, is Bool, is Date, is URL, is [String]:
                contents[key] = newValue
            default:
                print("Attribute values must of type String, Int, UInt, Double, Float, Bool, Date, URL or [String] – got \(type(of: newValue))")
                break
            }
        }
    }
}

// MARK: ExpressibleByDictionaryLiteral

extension Attributes: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (AttributeKey, AttributeValue)...) {
        self.init()
        for (key, value) in elements {
            self[key] = value
        }
    }
}

// MARK: Equatable

extension Attributes: Equatable {
    public static func == (lhs: Attributes, rhs: Attributes) -> Bool {
        if lhs.contents.count != rhs.contents.count {
            return false
        }
        
        return lhs.contents.reduce(true, { (isEqual, element) in
            if !isEqual {
                return false
            }
            
            switch (element.value, rhs.contents[element.key]) {
            case let (lhs as String, rhs as String):
                return lhs == rhs
            case let (lhs as Int, rhs as Int):
                return lhs == rhs
            case let (lhs as UInt, rhs as UInt):
                return lhs == rhs
            case let (lhs as Double, rhs as Double):
                return lhs == rhs
            case let (lhs as Float, rhs as Float):
                return lhs == rhs
            case let (lhs as Bool, rhs as Bool):
                return lhs == rhs
            case let (lhs as Date, rhs as Date):
                return lhs == rhs
            case let (lhs as URL, rhs as URL):
                return lhs == rhs
            case let (lhs as [String], rhs as [String]):
                return lhs == rhs
            default:
                return false
            }
        })
    }
}

// MARK: Codable

fileprivate struct CodingKeys: CodingKey {
    var stringValue: String
    
    init(stringValue: String) {
        self.stringValue = stringValue
    }
    
    var intValue: Int?
    
    init?(intValue: Int) {
        return nil
    }
}

extension Attributes: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try container.allKeys.forEach { key in
            if let value = try? container.decode(String.self, forKey: key) {
                contents[key.stringValue] = value
                return
            }
            
            if let value = try? container.decode(Int.self, forKey: key) {
                contents[key.stringValue] = value
                return
            }
            
            if let value = try? container.decode(UInt.self, forKey: key) {
                contents[key.stringValue] = value
                return
            }
            
            if let value = try? container.decode(Double.self, forKey: key) {
                contents[key.stringValue] = value
                return
            }
            
            if let value = try? container.decode(Float.self, forKey: key) {
                contents[key.stringValue] = value
                return
            }
            
            if let value = try? container.decode(Bool.self, forKey: key) {
                contents[key.stringValue] = value
                return
            }
            
            if let value = try? container.decode(Date.self, forKey: key) {
                contents[key.stringValue] = value
                return
            }
            
            if let value = try? container.decode(URL.self, forKey: key) {
                contents[key.stringValue] = value
                return
            }
            
            if let value = try? container.decode([String].self, forKey: key) {
                contents[key.stringValue] = value
                return
            }
            
            let description = "Attribute values must of type String, Int, UInt, Double, Float, Bool, Date, URL or [String]"
            let context = DecodingError.Context(codingPath: [key], debugDescription: description)
            let error = DecodingError.typeMismatch(AttributeValue.self, context)
            throw error
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try contents.forEach { element in
            let key = CodingKeys(stringValue: element.key)
            switch element.value {
            case let value as String:
                try container.encode(value, forKey: key)
            case let value as Int:
                try container.encode(value, forKey: key)
            case let value as UInt:
                try container.encode(value, forKey: key)
            case let value as Double:
                try container.encode(value, forKey: key)
            case let value as Float:
                try container.encode(value, forKey: key)
            case let value as Bool:
                try container.encode(value, forKey: key)
            case let value as Date:
                try container.encode(value, forKey: key)
            case let value as URL:
                try container.encode(value, forKey: key)
            case let value as [String]:
                try container.encode(value, forKey: key)
            default:
                let description = "Attribute values must of type String, Int, UInt, Double, Float, Bool, Date, URL or [String] – got \(type(of: element.value))"
                let context = EncodingError.Context(codingPath: [key], debugDescription: description)
                let error = EncodingError.invalidValue(element.value, context)
                throw error
            }
        }
    }
}

