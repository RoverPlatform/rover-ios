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

extension Height: Codable {
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
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let typeName: String
        switch self {
        case .intrinsic:
            typeName = "HeightIntrinsic"
        case .static(let value):
            typeName = "HeightStatic"
            try container.encode(value, forKey: .value)
        }
        try container.encode(typeName, forKey: .typeName)
    }
}
