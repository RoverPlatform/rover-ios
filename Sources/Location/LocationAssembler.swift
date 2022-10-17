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
#if !COCOAPODS
import RoverFoundation
import RoverData
#endif

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
        // MARK: Core Data
        
        container.register(NSManagedObjectContext.self, name: "location.backgroundContext") { resolver in
            let container = resolver.resolve(NSPersistentContainer.self, name: "location")!
            let context = container.newBackgroundContext()
            context.mergePolicy = NSOverwriteMergePolicy
            return context
        }
        
        container.register(NSManagedObjectContext.self, name: "location.viewContext") { resolver in
            let container = resolver.resolve(NSPersistentContainer.self, name: "location")!
            return container.viewContext
        }
        
        container.register(NSPersistentContainer.self, name: "location") { _ in
            #if !COCOAPODS
            // for SwiftPM use Bundle.module:
            guard let modelURL = Bundle.module.url(forResource: "RoverLocation", withExtension: "momd") else {
                fatalError("Core Data model not found for Rover Location module.")
            }
            guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
                fatalError("Core Data model not found for Rover Location module.")
            }
            // unfortunately the entity names seem to get set to "RoverCampaigns_RoverLocation.ClassName" rather than "RoverLocation.ClassName" causing a runtime failure.  Manually patch it up here.
            model.entities.forEach { entity in
                switch entity.name {
                case "Beacon":
                    entity.managedObjectClassName = "RoverLocation.Beacon"
                case "Geofence":
                    entity.managedObjectClassName = "RoverLocation.Geofence"
                default:
                    break
                }
            }
            #else
            let bundles = [Bundle(for: LocationAssembler.self)]
            guard let model = NSManagedObjectModel.mergedModel(from: bundles) else {
                fatalError("Core Data model not found for Rover Location module.")
            }
            #endif
            
            let container = NSPersistentContainer(name: "RoverLocation", managedObjectModel: model)
            container.loadPersistentStores { _, error in
                if let error = error {
                    os_log("Core Data store for Rover Location module failed to load, reason: %s", error.logDescription)
                    assertionFailure("Core Data store for Rover Location module failed to load, reason: \(error.logDescription)")
                }
            }
            
            return container
        }
        
        // MARK: Services
        
        container.register(LocationContextProvider.self) { resolver in
            resolver.resolve(LocationManager.self)!
        }
        
        container.register(LocationManager.self) { resolver in
            LocationManager(
                context: resolver.resolve(NSManagedObjectContext.self, name: "location.viewContext")!,
                eventQueue: resolver.resolve(EventQueue.self)!,
                maxGeofenceRegionsToMonitor: self.maxGeofenceRegionsToMonitor,
                maxBeaconRegionsToMonitor: self.maxBeaconRegionsToMonitor
            )
        }
        
        container.register(RegionManager.self) { resolver in
            resolver.resolve(LocationManager.self)!
        }
        
        container.register(SyncParticipant.self, name: "location.beacons") { resolver in
            BeaconsSyncParticipant(
                context: resolver.resolve(NSManagedObjectContext.self, name: "location.backgroundContext")!,
                userDefaults: UserDefaults.standard
            )
        }
        
        container.register(SyncParticipant.self, name: "location.geofences") { resolver in
            GeofencesSyncParticipant(
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
