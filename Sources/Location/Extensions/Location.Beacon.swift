//
//  Location.Beacon.swift
//  RoverLocation
//
//  Created by Andrew Clunis on 2018-11-22.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import CoreLocation

extension Beacon {
    public var region: CLBeaconRegion {
        return CLBeaconRegion(
            proximityUUID: self.uuid,
            major: UInt16(self.major),
            minor: UInt16(self.minor),
            identifier: self.regionIdentifier
        )
    }
}

// MARK: Collection

extension Collection where Element == Beacon {
    public func wildCardRegions(maxLength: Int) -> Set<CLBeaconRegion> {
        let uuids = self.map({ $0.uuid })
        let unique = Set(uuids)
        
        #if swift(>=4.2)
        let regions = unique.shuffled().prefix(maxLength).map { $0.region }
        #else
        let regions = unique.prefix(maxLength).map { $0.region }
        #endif
        
        return Set<CLBeaconRegion>(regions)
    }
}
