//
//  Scalar.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2018-07-25.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public enum Scalar: Equatable {
    case string(String)
    case number(Double)
    case boolean(Bool)
}

// MARK: Decodable

extension Scalar: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode(String.self) {
            self = .string(value)
        }
        
        if let value = try? container.decode(Double.self) {
            self = .number(value)
        }
        
        if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        }
        
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Scalar must be a string, number or boolean")
    }
}

// MARK: Encodable

extension Scalar: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        }
    }
}

// MARK: ExpressibleByStringLiteral

extension Scalar: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

// MARK: ExpressibleByIntegerLiteral

extension Scalar: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        let doubleValue = Double(value)
        self = .number(doubleValue)
    }
}

// MARK: ExpressibleByFloatLiteral

extension Scalar: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(value)
    }
}

// MARK: ExpressibleByBooleanLiteral

extension Scalar: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .boolean(value)
    }
}
