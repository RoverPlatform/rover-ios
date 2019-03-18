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
    public let attributes: [String: Any]?
    public let timestamp: Date?
    
    public init(name: String, namespace: String? = nil, attributes: [String: Any]? = nil, timestamp: Date? = nil) {
        self.name = name
        self.namespace = namespace
        self.attributes = attributes
        self.timestamp = timestamp
    }
}


public protocol EventQueue {
    func addEvent(_ info: EventInfo)
}

public class NotificationCenterEventQueue: EventQueue {
    public func addEvent(_ info: EventInfo) {
        let notification = Notification.init(from: info, withName: "RoverEmitterDidEmitEvent")
        NotificationCenter.default.post(notification)
    }
}

