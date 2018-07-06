//
//  CLLocationManager.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-05-04.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation

extension CLLocationManager {
    public func monitor(for regions: Set<Region>) {
        let regionsToMonitor = Set<CLRegion>(regions.map { $0.clRegion })
        let regionsToRemove = monitoredRegions.subtracting(regionsToMonitor)
        regionsToRemove.forEach(stopMonitoring)
        let regionsToAdd = regionsToMonitor.subtracting(monitoredRegions)
        regionsToAdd.forEach(startMonitoring)
    }
}
