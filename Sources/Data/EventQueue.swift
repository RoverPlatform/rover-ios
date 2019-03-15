//
//  EventQueue.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-03-13.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import os

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


public protocol EventQueue {
    func addEvent(_ info: EventInfo)
}

public class FakeEventQueue: EventQueue {
    public func addEvent(_ info: EventInfo) {
        // TODO: REPLACE WITH DISPATCHING EVENTS TO NOTIOFIACTIONCENTER
        os_log("Event tracked: %s", String(describing: info))
    }
}
