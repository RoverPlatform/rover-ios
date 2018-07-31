//
//  AttributeKey.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2018-07-24.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public struct AttributeKey: Codable, Equatable, Hashable, RawRepresentable {
    public var rawValue: String
    
    public init?(rawValue: String) {
        guard rawValue.range(of: "^[a-zA-Z_][a-zA-Z_0-9]*$", options: .regularExpression, range: nil, locale: nil) != nil else {
            return nil
        }

        self.rawValue = rawValue
    }
}

// MARK: ExpressibleByStringLiteral

extension AttributeKey: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(rawValue: value)!
    }
}
