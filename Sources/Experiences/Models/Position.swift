//
//  Position.swift
//  Rover
//
//  Created by Sean Rucker on 2018-04-24.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public struct Position: Decodable {
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

extension Position.HorizontalAlignment: Decodable {
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
}

// MARK: Position.VerticalAlignment

extension Position.VerticalAlignment: Decodable {
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
}
