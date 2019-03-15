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

public class FakeEventQueue: EventQueue {
    public func addEvent(_ info: EventInfo) {
        let name = Notification.Name("RoverEmitterDidEmitEvent")
        
        let userInfoAllFields: [String: Any?] = [
            "name": info.name,
            "namespace": info.namespace,
            "attributes": info.attributes
        ]
        
        // Clear out the nil values.
        let userInfo = userInfoAllFields.reduce([String:Any]()) { (userInfo, keyValue) in
            let (key, value) = keyValue
            if(value != nil) {
                return userInfo.merging([key: value!], uniquingKeysWith: { (a, b) in
                    // no duplicates
                    return a
                })
            } else {
                return userInfo
            }
        }
        
        NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
    }
}
