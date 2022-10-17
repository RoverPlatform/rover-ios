//
//  EventInfo.swift
//  RoverData
//
//  Created by Sean Rucker on 2017-11-30.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import Foundation
#if !COCOAPODS
import RoverFoundation
#endif

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

public extension EventInfo {
    /// Create an EventInfo that tracks a Screen Viewed event for Analytics use.  Use it for tracking screens & content in your app belonging to components other than Rover.
    init(
        screenViewedWithName screenName: String,
        contentID: String? = nil,
        contentName: String? = nil
    ) {
        let eventAttributes: Attributes = [:]
        
        eventAttributes["screenName"] = screenName
        
        if let contentID = contentID {
            eventAttributes["contentID"] = contentID
        }
        
        if let contentName = contentName {
            eventAttributes["contentName"] = contentName
        }

        // using a nil namespace to represent events for screens owned by the app vendor.
        self.init(name: "Screen Viewed", attributes: eventAttributes)
    }
}
