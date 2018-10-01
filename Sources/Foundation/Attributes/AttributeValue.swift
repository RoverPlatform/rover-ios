//
//  AttributeValue.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2018-07-24.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public enum AttributeValue: Equatable {
    case scalar(Scalar)
    case array([Scalar])
    case object(Attributes)
    case null
}

// MARK: Decodable

extension AttributeValue: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Scalar.self) {
            self = .scalar(value)
            return
        }

        if let value = try? container.decode([Scalar].self) {
            self = .array(value)
            return
        }

        if let value = try? container.decode(Attributes.self) {
            self = .object(value)
            return
        }

        self = .null
    }
}

// MARK: Encodable

extension AttributeValue: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .scalar(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            let null: Bool? = nil
            try container.encode(null)
        }
    }
}

// MARK: ExpressibleByStringLiteral

extension AttributeValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        let scalar = Scalar(stringLiteral: value)
        self = .scalar(scalar)
    }
}

// MARK: ExpressibleByIntegerLiteral

extension AttributeValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        let scalar = Scalar(integerLiteral: value)
        self = .scalar(scalar)
    }
}

// MARK: ExpressibleByFloatLiteral

extension AttributeValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        let scalar = Scalar(floatLiteral: value)
        self = .scalar(scalar)
    }
}

// MARK: ExpressibleByBooleanLiteral

extension AttributeValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        let scalar = Scalar(booleanLiteral: value)
        self = .scalar(scalar)
    }
}

// MARK: ExpressibleByArrayLiteral

extension AttributeValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: ScalarRepresentable...) {
        let value = elements.map { $0.scalarValue }
        self = .array(value)
    }
}

// MARK: ExpressibleByDictionaryLiteral

extension AttributeValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (AttributeKey, AttributeRepresentable)...) {
        let rawValue: [AttributeKey: AttributeValue] = elements.reduce(into: [:]) { $0[$1.0] = $1.1.attributeValue }
        let attributes = Attributes(rawValue: rawValue)
        self = .object(attributes)
    }
}

// MARK: ExpressibleByNilLiteral

extension AttributeValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}
