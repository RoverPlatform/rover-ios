//
//  CLLocationManager.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-05-04.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation

extension CLLocationManager {
    public func monitor(for regionsToMonitor: Set<CLRegion>) {
        // Remove regions that should no longer be monitored
        for regionToRemove in monitoredRegions.subtracting(regionsToMonitor) {
            self.stopMonitoring(for: regionToRemove)
            
            if let beaconRegion = regionToRemove as? CLBeaconRegion {
                self.stopRangingBeacons(in: beaconRegion)
            }
        }
        
        // Add regions that are not already being monitored
        for regionToAdd in regionsToMonitor.subtracting(monitoredRegions) {
            self.startMonitoring(for: regionToAdd)
            
            if let beaconRegion = regionToAdd as? CLBeaconRegion {
                self.startRangingBeacons(in: beaconRegion)
            }
        }
    }
}
