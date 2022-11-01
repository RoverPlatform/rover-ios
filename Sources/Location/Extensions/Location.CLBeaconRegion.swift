//
//  CLBeaconRegion.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-08-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation
#if !COCOAPODS
import RoverFoundation
#endif

extension CLBeaconRegion {
    public var attributes: Attributes {
        var attributes: [String: Any] = [
            "uuid": proximityUUID.uuidString
        ]
        
        if let major = major {
            attributes["major"] = major.intValue
        }
        
        if let minor = minor {
            attributes["minor"] = minor.intValue
        }
        
        return Attributes(rawValue: attributes)
    }
}
