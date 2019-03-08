//
//  ID.swift
//  RoverCampaignsFoundation
//
//  Created by Sean Rucker on 2018-05-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

// swiftlint:disable:next type_name // ID is an entirely reasonable name for this.
public struct ID: Codable, Equatable, Hashable, RawRepresentable {
    public var rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        self.rawValue = value
    }
    
    public init(unicodeScalarLiteral value: String) {
        self.rawValue = value
    }
}

// MARK: ExpressibleByStringLiteral

extension ID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

// MARK: ScalarRepresentable

extension ID: ScalarRepresentable {
    public var scalarValue: Scalar {
        return .string(rawValue)
    }
}
