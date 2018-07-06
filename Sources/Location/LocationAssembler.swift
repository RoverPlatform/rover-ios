//
//  LocationAssembler.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2017-10-24.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import CoreLocation

public struct LocationAssembler: Assembler {
    let isAutomaticLocationEventTrackingEnabled: Bool
    let isAutomaticRegionManagementEnabled: Bool
    let isSignificantLocationMonitoringEnabled: Bool
    
    public init(isAutomaticLocationEventTrackingEnabled: Bool = true, isAutomaticRegionManagementEnabled: Bool = true, isSignificantLocationMonitoringEnabled: Bool = true) {
        self.isAutomaticLocationEventTrackingEnabled = isAutomaticLocationEventTrackingEnabled
        self.isAutomaticRegionManagementEnabled = isAutomaticRegionManagementEnabled
        self.isSignificantLocationMonitoringEnabled = isSignificantLocationMonitoringEnabled
    }
    
    public func assemble(container: Container) {
        container.register(CLLocationManager.self) { _ in CLLocationManager() }
        
        container.register(ContextProvider.self, name: "location") { _ in LocationContextProvider() }
        
        container.register(LocationManager.self) { resolver in
            let eventQueue = resolver.resolve(EventQueue.self)!
            let locationManager = resolver.resolve(CLLocationManager.self)!
            let regionStore = resolver.resolve(RegionStore.self)!
            return LocationManagerService(eventQueue: eventQueue, locationManager: locationManager, regionStore: regionStore)
        }
        
        container.register(RegionStore.self) { resolver in
            let client = resolver.resolve(GraphQLClient.self)!
            let logger = resolver.resolve(Logger.self)!
            let stateFetcher = resolver.resolve(StateFetcher.self)!
            return RegionStoreService(client: client, logger: logger, stateFetcher: stateFetcher)
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        var locationManager = resolver.resolve(LocationManager.self)!
        locationManager.isAutomaticLocationEventTrackingEnabled = isAutomaticLocationEventTrackingEnabled
        locationManager.isAutomaticRegionManagementEnabled = isAutomaticRegionManagementEnabled
        locationManager.isSignificantLocationMonitoringEnabled = isSignificantLocationMonitoringEnabled
    }
}

