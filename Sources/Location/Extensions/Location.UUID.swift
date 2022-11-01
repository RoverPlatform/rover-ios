//
//  UUID.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-09-10.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation

extension UUID {
    var region: CLBeaconRegion {
        return CLBeaconRegion(proximityUUID: self, identifier: self.uuidString)
    }
}
