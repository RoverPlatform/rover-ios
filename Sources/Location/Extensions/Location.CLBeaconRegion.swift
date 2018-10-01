//
//  CLBeaconRegion.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-08-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation

extension CLBeaconRegion: AttributeRepresentable {
    public var attributeValue: AttributeValue {
        var attributes: Attributes = [
            "uuid": proximityUUID.uuidString
        ]
        
        if let major = major {
            attributes["major"] = major.intValue
        }
        
        if let minor = minor {
            attributes["minor"] = minor.intValue
        }
        
        return .object(attributes)
    }
}
