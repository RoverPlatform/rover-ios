//
//  LocationAssembler.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2017-10-24.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import CoreData
import CoreLocation
import os

public class LocationAssembler: Assembler {
    let maxGeofenceRegionsToMonitor: Int
    let maxBeaconRegionsToMonitor: Int
    
    public init(
        maxGeofenceRegionsToMonitor: Int = 20,
        maxBeaconRegionsToMonitor: Int = 5
    ) {
        self.maxGeofenceRegionsToMonitor = maxGeofenceRegionsToMonitor
        self.maxBeaconRegionsToMonitor = maxBeaconRegionsToMonitor
    }
    
public func assemble(container: Container) {
        // MARK: Services
        
        container.register(LocationInfoProvider.self) { resolver in
            return resolver.resolve(LocationManager.self)!
        }
        
        container.register(LocationManager.self) { resolver in
            return LocationManager(
                context: resolver.resolve(NSManagedObjectContext.self, name: "location.viewContext")!,
                eventPipeline: resolver.resolve(EventPipeline.self)!,
                maxGeofenceRegionsToMonitor: self.maxGeofenceRegionsToMonitor,
                maxBeaconRegionsToMonitor: self.maxBeaconRegionsToMonitor
            )
        }
        
        container.register(RegionManager.self) { resolver in
            return resolver.resolve(LocationManager.self)!
        }
    }
}
