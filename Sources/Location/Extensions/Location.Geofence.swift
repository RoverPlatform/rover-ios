//
//  Location.Geofence.swift
//  RoverLocation
//
//  Created by Andrew Clunis on 2018-11-22.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import CoreLocation
import os

// MARK: CoreLocation

extension Geofence {
    public var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public var location: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }

    public var region: CLCircularRegion {
        return CLCircularRegion(
            center: location.coordinate,
            radius: radius,
            identifier: self.regionIdentifier
        )
    }
}

// MARK: Collection

extension Collection where Element == Geofence {
    public func sortedByDistance(from coordinate: CLLocationCoordinate2D) -> [Geofence] {
        os_log("Sorting geofences...", log: .general, type: .debug)

        #if swift(>=4.2)
        if #available(iOS 12.0, *) {
            os_signpost(.begin, log: .general, name: "sortGeofences")
        }
        #endif

        let sorted = self.sorted(by: {
            return coordinate.distanceTo($0.coordinate) < coordinate.distanceTo($1.coordinate)
        })

        #if swift(>=4.2)
        if #available(iOS 12.0, *) {
            os_signpost(.end, log: .general, name: "sortGeofences")
        }
        #endif

        os_log("Sorted %d geofences", log: .general, type: .debug, self.count)
        return sorted
    }

    public func regions(closestTo coordinate: CLLocationCoordinate2D?, maxLength: Int) -> Set<CLCircularRegion> {
        let regions: [CLCircularRegion]
        if let coordinate = coordinate {
            regions = self.sortedByDistance(from: coordinate).prefix(maxLength).map { $0.region }
        } else {
            #if swift(>=4.2)
            regions = self.shuffled().prefix(maxLength).compactMap { $0.region }
            #else
            regions = self.prefix(maxLength).compactMap { $0.region }
            #endif
        }

        return Set<CLCircularRegion>(regions)
    }
}
