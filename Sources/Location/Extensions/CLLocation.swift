//
//  CLLocation.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-08-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation

extension CLLocation: AttributeRepresentable {
    public var attributeValue: AttributeValue {
        var attributes: Attributes = [
            "coordinate": [coordinate.latitude, coordinate.longitude],
            "altitude": altitude,
            "horizontalAccuracy": horizontalAccuracy,
            "verticalAccuracy": verticalAccuracy
        ]
        
        if let floor = floor?.level {
            attributes["floor"] = floor
        }
        
        return .object(attributes)
    }
}
