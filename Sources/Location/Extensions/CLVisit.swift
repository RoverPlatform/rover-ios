//
//  CLVisit.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-08-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation

extension CLVisit: AttributeRepresentable {
    public var attributeValue: AttributeValue {
        return [
            "coordinate": [coordinate.latitude, coordinate.longitude],
            "horizontalAccuracy": horizontalAccuracy,
            "arrivalDate": arrivalDate,
            "departureDate": departureDate
        ]
    }
}
