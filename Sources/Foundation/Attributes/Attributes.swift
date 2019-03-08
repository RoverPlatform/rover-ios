//
//  Attributes.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2018-07-24.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public struct Attributes: Equatable, RawRepresentable {
    public var rawValue = [AttributeKey: AttributeValue]()
    
    public init(rawValue: [AttributeKey: AttributeValue]) {
        self.rawValue = rawValue
    }
}

// MARK: Codable

extension Attributes: Codable {
    struct CodingKeys: CodingKey {
        var intValue: Int? {
            return nil
        }
        
        var stringValue: String
        
        init?(intValue: Int) {
            return nil
        }
        
        init(stringValue: String) {
            self.stringValue = stringValue
        }
    }
    
    public init(from decoder: Decoder) throws {
        rawValue = [AttributeKey: AttributeValue]()

        let container = try decoder.container(keyedBy: CodingKeys.self)
        try container.allKeys.forEach {
            guard let key = AttributeKey(rawValue: $0.stringValue) else {
                throw DecodingError.dataCorruptedError(forKey: $0, in: container, debugDescription: "Invalid AttributeKey \($0.stringValue)")
            }
            
            rawValue[key] = try container.decode(AttributeValue.self, forKey: $0)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try rawValue.forEach { element in
            let key = CodingKeys(stringValue: element.key.rawValue)
            try container.encode(element.value, forKey: key)
        }
    }
}

// MARK: Collection

extension Attributes: Collection {
    public typealias Index = Dictionary<AttributeKey, AttributeValue>.Index
    public typealias Element = Dictionary<AttributeKey, AttributeValue>.Element
    
    public var startIndex: Index {
        return rawValue.startIndex
    }
    
    public var endIndex: Index {
        return rawValue.endIndex
    }
    
    public subscript(index: Index) -> Element {
        return rawValue[index]
    }
    
    public subscript(key: AttributeKey) -> AttributeRepresentable? {
        get {
            return rawValue[key]
        }
        
        set {
            rawValue[key] = newValue?.attributeValue
        }
    }
    
    public subscript(string: String) -> AttributeRepresentable? {
        get {
            guard let key = AttributeKey(rawValue: string) else {
                fatalError("Invalid attribute key: \(string)")
            }
            
            return rawValue[key]
        }
        
        set {
            guard let key = AttributeKey(rawValue: string) else {
                fatalError("Invalid attribute key: \(string)")
            }
            
            rawValue[key] = newValue?.attributeValue
        }
    }
    
    public func index(after i: Index) -> Index {
        return rawValue.index(after: i)
    }
}

// MARK: ExpressibleByDictionaryLiteral

extension Attributes: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (AttributeKey, AttributeRepresentable)...) {
        self.rawValue = elements.reduce(into: [:]) { $0[$1.0] = $1.1.attributeValue }
    }
}
