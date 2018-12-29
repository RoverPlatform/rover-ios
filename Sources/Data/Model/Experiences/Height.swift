//
//  Height.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-04-16.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public enum Height {
    case intrinsic
    case `static`(value: Double)
}

// MARK: Decodable

extension Height: Decodable {
    private enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
        case value
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .typeName)
        switch typeName {
        case "HeightIntrinsic":
            self = .intrinsic
        case "HeightStatic":
            let value = try container.decode(Double.self, forKey: .value)
            self = .static(value: value)
        default:
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected on of HeightIntrinsic or HeightStatic - found \(typeName)")
        }
    }
}
