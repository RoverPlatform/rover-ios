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
    init(forRoverEvent eventName: RoverEventName, withAttributes attributes: [String: Any]) {
        let mergedAttributes = attributes.merging(["name": eventName]) { (a, _) in a }
        self.init(name: Notification.Name("RoverEmitterDidEmitEvent"), object: nil, userInfo: mergedAttributes)
    }
}
