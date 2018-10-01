//
//  CLPlacemark.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-09-20.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation

extension CLPlacemark {
    var context: Context.Location? {
        return self.location?.context(placemark: self)
    }
}
