//
//  Block.swift
//  Rover
//
//  Created by Sean Rucker on 2017-10-19.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

public protocol Block: AttributeRepresentable, Decodable {
    var background: Background { get }
    var border: Border { get }
    var id: ID { get }
    var name: String { get }
    var insets: Insets { get }
    var opacity: Double { get }
    var position: Position { get }
    var tapBehavior: BlockTapBehavior { get }
    var keys: [String: String] { get }
    var tags: [String] { get }
}

extension Block {
    public var attributeValue: AttributeValue {
        let keys = self.keys.reduce(into: Attributes()) { $0[$1.0] = $1.1 }
        return [
            "id": id,
            "name": name,
            "tapBehavior": tapBehavior,
            "keys": AttributeValue.object(keys),
            "tags": tags
        ]
    }
}
