//
//  CLLocationCoordinate2D.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-09-13.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation

extension CLLocationCoordinate2D {
    func distanceTo(_ other: CLLocationCoordinate2D) -> CLLocationDistance {
        let lat1 = degreesToRadians(self.latitude)
        let lon1 = degreesToRadians(self.longitude)
        let lat2 = degreesToRadians(other.latitude)
        let lon2 = degreesToRadians(other.longitude)
        return earthRadius * ahaversin(haversin(lat2 - lat1) + cos(lat1) * cos(lat2) * haversin(lon2 - lon1))
    }
}

// https://en.wikipedia.org/wiki/Figure_of_the_Earth
let earthRadius: Double = 6_371_000

private let haversin: (Double) -> Double = {
    (1 - cos($0)) / 2
}

private let ahaversin: (Double) -> Double = {
    2 * asin(sqrt($0))
}

private let degreesToRadians: (Double) -> Double = {
    ($0 / 360) * 2 * Double.pi
}
