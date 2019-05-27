//
//  Block.swift
//  Rover
//
//  Created by Sean Rucker on 2017-10-19.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

public protocol Block: Decodable {
    var background: Background { get }
    var border: Border { get }
    var id: String { get }
    var name: String { get }
    var insets: Insets { get }
    var opacity: Double { get }
    var position: Position { get }
    var tapBehavior: BlockTapBehavior { get }
    var keys: [String: String] { get }
    var tags: [String] { get }
}
