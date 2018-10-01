//
//  CLBeacon.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-09-17.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation

extension CLBeacon {
    var regionIdentifier: String {
        return "\(self.proximityUUID.uuidString):\(self.major):\(self.minor)"
    }
}
