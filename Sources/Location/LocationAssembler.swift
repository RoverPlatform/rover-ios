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
    public init() {
        
    }
    
public func assemble(container: Container) {
        // MARK: Services
        
        container.register(LocationInfoProvider.self) { resolver in
            return resolver.resolve(LocationManager.self)!
        }
        
        container.register(LocationManager.self) { resolver in
            return LocationManager(
                context: resolver.resolve(NSManagedObjectContext.self, name: "location.viewContext")!,
                eventQueue: resolver.resolve(EventQueue.self)!
            )
        }
        
        container.register(RegionManager.self) { resolver in
            return resolver.resolve(LocationManager.self)!
        }
        
        container.register(SyncParticipant.self, name: "location.beacons") { resolver in
            return BeaconsSyncParticipant(
                context: resolver.resolve(NSManagedObjectContext.self, name: "location.backgroundContext")!,
                userDefaults: UserDefaults.standard
            )
        }
        
        container.register(SyncParticipant.self, name: "location.geofences") { resolver in
            return GeofencesSyncParticipant(
                context: resolver.resolve(NSManagedObjectContext.self, name: "location.backgroundContext")!,
                userDefaults: UserDefaults.standard
            )
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        resolver.resolve(SyncCoordinator.self)!.participants.append(contentsOf: [
            resolver.resolve(SyncParticipant.self, name: "location.beacons")!,
            resolver.resolve(SyncParticipant.self, name: "location.geofences")!
        ])
    }
}
