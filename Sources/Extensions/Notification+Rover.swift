//
//  Notification+Rover.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-03-18.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

typealias RoverEventName = String

extension Notification {
    /// Build a Notification to be dispatched on the iOS Notification Center for a Rover event.
    init(forRoverEvent eventName: RoverEventName, withAttributes attributes: [String: Any]) {
        let mergedAttributes = attributes.merging(["name": eventName]) { a, _ in a }
        self.init(name: Notification.Name("RoverEmitterDidEmitEvent"), object: nil, userInfo: mergedAttributes)
    }
}
