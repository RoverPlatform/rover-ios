//
//  Row.swift
//  RoverData
//
//  Created by Sean Rucker on 2017-10-19.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

public struct Row {
    public var background: Background
    public var blocks: [Block]
    public var height: Height
    public var id: String
    public var name: String
    public var keys: [String: String]
    public var tags: [String]
    
    public init(background: Background, blocks: [Block], height: Height, id: String, name: String, keys: [String: String], tags: [String]) {
        self.background = background
        self.blocks = blocks
        self.height = height
        self.id = id
        self.name = name
        self.keys = keys
        self.tags = tags
    }
}

// MARK: Decodable

extension Row: Codable {
    enum CodingKeys: String, CodingKey {
        case background
        case blocks
        case height
        case id
        case name
        case keys
        case tags
    }
    
    enum BlockType: Codable {
        case barcodeBlock
        case buttonBlock
        case imageBlock
        case rectangleBlock
        case textBlock
        case webViewBlock
        
        enum CodingKeys: String, CodingKey {
            case typeName = "__typename"
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeName = try container.decode(String.self, forKey: .typeName)
            switch typeName {
            case "BarcodeBlock":
                self = .barcodeBlock
            case "ButtonBlock":
                self = .buttonBlock
            case "ImageBlock":
                self = .imageBlock
            case "RectangleBlock":
                self = .rectangleBlock
            case "TextBlock":
                self = .textBlock
            case "WebViewBlock":
                self = .webViewBlock
            default:
                throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected one of BarcodeBlock, ButtonBlock, ImageBlock, RectangleBlock, TextBlock, WebViewBlock – found \(typeName)")
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            let typeName: String
            switch self {
            case .barcodeBlock:
                typeName = "BarcodeBock"
            case .buttonBlock:
                typeName = "ButtonBlock"
            case .imageBlock:
                typeName = "ImageBlock"
            case .rectangleBlock:
                typeName = "RectangleBlock"
            case .textBlock:
                typeName = "TextBlock"
            case .webViewBlock:
                typeName = "WebViewBlock"
            }
            
            try container.encode(typeName, forKey: .typeName)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        background = try container.decode(Background.self, forKey: .background)
        height = try container.decode(Height.self, forKey: .height)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        keys = try container.decode([String: String].self, forKey: .keys)
        tags = try container.decode([String].self, forKey: .tags)
        
        blocks = [Block]()
        
        let blockTypes = try container.decode([BlockType].self, forKey: .blocks)
        var blocksContainer = try container.nestedUnkeyedContainer(forKey: .blocks)
        while !blocksContainer.isAtEnd {
            let block: Block
            switch blockTypes[blocksContainer.currentIndex] {
            case .barcodeBlock:
                block = try blocksContainer.decode(BarcodeBlock.self)
            case .buttonBlock:
                block = try blocksContainer.decode(ButtonBlock.self)
            case .imageBlock:
                block = try blocksContainer.decode(ImageBlock.self)
            case .rectangleBlock:
                block = try blocksContainer.decode(RectangleBlock.self)
            case .textBlock:
                block = try blocksContainer.decode(TextBlock.self)
            case .webViewBlock:
                block = try blocksContainer.decode(WebViewBlock.self)
            }
            blocks.append(block)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(background, forKey: .background)
        try container.encode(height, forKey: .height)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(keys, forKey: .keys)
        try container.encode(tags, forKey: .tags)
        
        var blocksContainer = container.nestedUnkeyedContainer(forKey: .blocks)
        blocksContainer.encode(blocks)
        blocks.forEach { block in
            // ANDREW START HERE and identify how to encode typeName considering that the synthesized codable impls for each block type won't encode it and I can't do the equivalent "overlayed decode" hack that sean is doing above for Decodable.
            switch block {
            case let button as ButtonBlock:
                blocksContainer.encode(button)
            }
            
        }
    }
}

// MARK: Attributes

extension Row  {
    public var attributes: Attributes {
        return [
            "id": id,
            "name": name,
            "keys": keys,
            "tags": tags
        ]
    }
}
