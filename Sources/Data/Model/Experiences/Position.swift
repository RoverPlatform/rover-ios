//
//  Position.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-04-24.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public struct Position: Codable {
    public enum HorizontalAlignment {
        case center(offset: Double, width: Double)
        case left(offset: Double, width: Double)
        case right(offset: Double, width: Double)
        case fill(leftOffset: Double, rightOffset: Double)
    }
    
    public enum VerticalAlignment {
        case bottom(offset: Double, height: Height)
        case middle(offset: Double, height: Height)
        case fill(topOffset: Double, bottomOffset: Double)
        case stacked(topOffset: Double, bottomOffset: Double, height: Height)
        case top(offset: Double, height: Height)
    }
    
    public var horizontalAlignment: HorizontalAlignment
    public var verticalAlignment: VerticalAlignment
}

// MARK: Position.HorizontalAlignment

extension Position.HorizontalAlignment: Codable {
    private enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
        case offset
        case width
        case leftOffset
        case rightOffset
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .typeName)
        switch typeName {
        case "HorizontalAlignmentCenter":
            let offset = try container.decode(Double.self, forKey: .offset)
            let width = try container.decode(Double.self, forKey: .width)
            self = .center(offset: offset, width: width)
        case "HorizontalAlignmentLeft":
            let offset = try container.decode(Double.self, forKey: .offset)
            let width = try container.decode(Double.self, forKey: .width)
            self = .left(offset: offset, width: width)
        case "HorizontalAlignmentRight":
            let offset = try container.decode(Double.self, forKey: .offset)
            let width = try container.decode(Double.self, forKey: .width)
            self = .right(offset: offset, width: width)
        case "HorizontalAlignmentFill":
            let leftOffset = try container.decode(Double.self, forKey: .leftOffset)
            let rightOffset = try container.decode(Double.self, forKey: .rightOffset)
            self = .fill(leftOffset: leftOffset, rightOffset: rightOffset)
        default:
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected on of HorizontalAlignmentCenter, HorizontalAlignmentLeft, HorizontalAlignmentRight or HorizontalAlignmentFill - found \(typeName)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let typeName: String
        switch self {
        case let .center(offset, width):
            typeName = "HorizontalAlignmentCenter"
            try container.encode(width, forKey: .width)
            try container.encode(offset, forKey: .offset)
        case let .left(offset, width):
            typeName = "HorizontalAlignmentLeft"
            try container.encode(offset, forKey: .offset)
            try container.encode(width, forKey: .width)
        case let .right(offset, width):
            typeName = "HorizontalAlignmentRight"
            try container.encode(offset, forKey: .offset)
            try container.encode(width, forKey: .width)
        case let .fill(leftOffset, rightOffset):
            typeName = "HorizontalAlignmentFill"
            try container.encode(leftOffset, forKey: .leftOffset)
            try container.encode(rightOffset, forKey: .rightOffset)
        }
        try container.encode(typeName, forKey: .typeName)
    }
}

// MARK: Position.VerticalAlignment

extension Position.VerticalAlignment: Codable {
    private enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
        case offset
        case height
        case topOffset
        case bottomOffset
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .typeName)
        switch typeName {
        case "VerticalAlignmentBottom":
            let offset = try container.decode(Double.self, forKey: .offset)
            let height = try container.decode(Height.self, forKey: .height)
            self = .bottom(offset: offset, height: height)
        case "VerticalAlignmentMiddle":
            let offset = try container.decode(Double.self, forKey: .offset)
            let height = try container.decode(Height.self, forKey: .height)
            self = .middle(offset: offset, height: height)
        case "VerticalAlignmentFill":
            let topOffset = try container.decode(Double.self, forKey: .topOffset)
            let bottomOffset = try container.decode(Double.self, forKey: .bottomOffset)
            self = .fill(topOffset: topOffset, bottomOffset: bottomOffset)
        case "VerticalAlignmentStacked":
            let topOffset = try container.decode(Double.self, forKey: .topOffset)
            let bottomOffset = try container.decode(Double.self, forKey: .bottomOffset)
            let height = try container.decode(Height.self, forKey: .height)
            self = .stacked(topOffset: topOffset, bottomOffset: bottomOffset, height: height)
        case "VerticalAlignmentTop":
            let offset = try container.decode(Double.self, forKey: .offset)
            let height = try container.decode(Height.self, forKey: .height)
            self = .top(offset: offset, height: height)
        default:
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected on of VerticalAlignmentBottom, VerticalAlignmentMiddle, VerticalAlignmentFill, VerticalAlignmentStacked or VerticalAlignmentTop - found \(typeName)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let typeName: String
        switch self {
        case let .bottom(offset, height):
            typeName = "VerticalAlignmentBottom"
            try container.encode(offset, forKey: .offset)
            try container.encode(height, forKey: .height)
        case let .middle(offset, height):
            typeName = "VerticalAlignmentMiddle"
            try container.encode(offset, forKey: .offset)
            try container.encode(height, forKey: .height)
        case let .fill(topOffset, bottomOffset):
            typeName = "VerticalAlignmentFill"
            try container.encode(topOffset, forKey: .topOffset)
            try container.encode(bottomOffset, forKey: .bottomOffset)
        case let .stacked(topOffset, bottomOffset, height):
            typeName = "VerticalAlignmentStacked"
            try container.encode(topOffset, forKey: .topOffset)
            try container.encode(bottomOffset, forKey: .bottomOffset)
            try container.encode(height, forKey: .height)
        case let .top(offset, height):
            typeName = "VerticalAlignmentTop"
            try container.encode(offset, forKey: .offset)
            try container.encode(height, forKey: .height)
        }
        
        try container.encode(typeName, forKey: .typeName)
    }
}
