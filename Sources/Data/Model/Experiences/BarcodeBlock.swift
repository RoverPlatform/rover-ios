//
//  BarcodeBlock.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-04-24.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public struct BarcodeBlock: Block {
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
}
