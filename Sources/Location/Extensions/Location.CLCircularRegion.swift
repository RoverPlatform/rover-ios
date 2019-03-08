//
//  CLCircularRegion.swift
//  RoverCampaignsLocation
//
//  Created by Sean Rucker on 2018-08-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation

extension CLCircularRegion: AttributeRepresentable {
    public var attributeValue: AttributeValue {
        return [
            "center": [
                center.latitude,
                center.longitude
            ],
            "radius": radius
        ]
    }
}
