//
//  EventInfo.swift
//  RoverData
//
//  Created by Sean Rucker on 2017-11-30.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import Foundation

public struct EventInfo {
    public let name: String
    public let namespace: String?
    public let attributes: Attributes?
    public let timestamp: Date?
    
    public init(name: String, namespace: String? = nil, attributes: Attributes? = nil, timestamp: Date? = nil) {
        self.name = name
        self.namespace = namespace
        self.attributes = attributes
        self.timestamp = timestamp
    }
}
