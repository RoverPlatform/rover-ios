//
//  BarcodeBlock.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-04-24.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public struct BarcodeBlock: Block, Codable {
    public var background: Background
    public var barcode: Barcode
    public var border: Border
    public var id: String
    public var name: String
    public var insets: Insets
    public var opacity: Double
    public var position: Position
    public var tapBehavior: BlockTapBehavior
    public var keys: [String: String]
    public var tags: [String]
    
    public init(background: Background, barcode: Barcode, border: Border, id: String, name: String, insets: Insets, opacity: Double, position: Position, tapBehavior: BlockTapBehavior, keys: [String: String], tags: [String]) {
        self.background = background
        self.barcode = barcode
        self.border = border
        self.id = id
        self.name = name
        self.insets = insets
        self.opacity = opacity
        self.position = position
        self.tapBehavior = tapBehavior
        self.keys = keys
        self.tags = tags
    }
    
    private enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
        case background = "background"
        case border = "border"
        case id = "id"
        case name = "name"
        case insets = "insets"
        case opacity = "opacity"
        case position = "position"
        case tapBehavior = "tapBehavior"
        case keys = "keys"
        case tags = "tags"
        case barcode = "barcode"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("BarcodeBlock", forKey: .typeName)
        try container.encode(background, forKey: .background)
        try container.encode(border, forKey: .border)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(insets, forKey: .insets)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(position, forKey: .position)
        try container.encode(tapBehavior, forKey: .tapBehavior)
        try container.encode(keys, forKey: .keys)
        try container.encode(tags, forKey: .tags)
        try container.encode(barcode, forKey: .barcode)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.background = try container.decode(Background.self, forKey: .background)
        self.border = try container.decode(Border.self, forKey: .border)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.insets = try container.decode(Insets.self, forKey: .insets)
        self.opacity = try container.decode(Double.self, forKey: .opacity)
        self.position = try container.decode(Position.self, forKey: .position)
        self.tapBehavior = try container.decode(BlockTapBehavior.self, forKey: .tapBehavior)
        self.keys = try container.decode([String: String].self, forKey: .keys)
        self.tags = try container.decode([String].self, forKey: .tags)
        self.barcode = try container.decode(Barcode.self, forKey: .barcode)
    }
}
