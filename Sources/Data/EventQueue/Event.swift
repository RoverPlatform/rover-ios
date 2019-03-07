//
//  Event.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public struct Event: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case namespace
        case attributes
        case context = "device"
        case timestamp
    }
    
    public let id = UUID()
    
    public var name: String
    public var namespace: String?
    public var attributes: Attributes?
    public var context: Context
    public var timestamp: Date
    
    public init(name: String, context: Context, namespace: String? = nil, attributes: Attributes? = nil, timestamp: Date = Date()) {
        self.name = name
        self.namespace = namespace
        self.attributes = attributes
        self.context = context
        self.timestamp = timestamp
    }
}

// MARK: Hashable

extension Event: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id.hashValue)
    }
}
