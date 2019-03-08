//
//  LocationHandler.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-09-14.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import CoreLocation
import os.log

class LocationManager {
    let maxGeofenceRegionsToMonitor: Int
    let maxBeaconRegionsToMonitor: Int
    
    let context: NSManagedObjectContext
    let eventQueue: EventQueue
    let geocoder = CLGeocoder()
    
    var location: Context.Location?
    
    typealias RegionIdentifier = String
    
    var currentGeofences = Set<Geofence>()
    var geofenceObservers = ObserverSet<Set<Geofence>>()
    
    var beaconMap = [CLBeaconRegion: Set<Beacon>]()
    var currentBeacons: Set<Beacon> {
        return self.beaconMap.reduce(Set<Beacon>()) { result, element in
            result.union(element.value)
        }
    }
    
    var beaconObservers = ObserverSet<Set<Beacon>>()
    
    init(
        context: NSManagedObjectContext,
        eventQueue: EventQueue,
        maxGeofenceRegionsToMonitor: Int,
        maxBeaconRegionsToMonitor: Int
    ) {
        self.maxGeofenceRegionsToMonitor = maxGeofenceRegionsToMonitor
        self.maxBeaconRegionsToMonitor = maxBeaconRegionsToMonitor
        let theoreticalMaximumGeofences = 20
        if maxGeofenceRegionsToMonitor > theoreticalMaximumGeofences {
            fatalError("You may only specify that Rover can monitor up to \(theoreticalMaximumGeofences) geofences at a time.")
        }
        if maxBeaconRegionsToMonitor >= maxGeofenceRegionsToMonitor {
            fatalError("Rover uses the same region slots for monitoring beacons as it does for monitoring geofences, so therefore you may only specify that Rover can monitor up to the same max number of beacons as geofence regions, currently \(maxGeofenceRegionsToMonitor).")
        }
        self.context = context
        self.eventQueue = eventQueue
    }
}

// MARK: LocationContextProvider

extension LocationManager: LocationContextProvider {
    var locationAuthorization: String {
        let authorizationStatus: String
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways:
            authorizationStatus = "authorizedAlways"
        case .authorizedWhenInUse:
            authorizationStatus = "authorizedWhenInUse"
        case .denied:
            authorizationStatus = "denied"
        case .notDetermined:
            authorizationStatus = "notDetermined"
        case .restricted:
            authorizationStatus = "restricted"
        }
        
        return authorizationStatus
    }
    
    var isLocationServicesEnabled: Bool {
        return CLLocationManager.locationServicesEnabled()
    }
}

// MARK: RegionManager

extension LocationManager: RegionManager {
    func updateLocation(manager: CLLocationManager) {
        if let location = manager.location {
            self.trackLocationUpdate(location: location)
        } else {
            os_log("Current location is unknown", log: .location, type: .debug)
        }
        
        self.updateMonitoredRegions(manager: manager)
    }
    
    func trackLocationUpdate(location: CLLocation) {
        if self.geocoder.isGeocoding {
            os_log("Cancelling in-progress geocode", log: .location, type: .debug)
            self.geocoder.cancelGeocode()
        }
        
        os_log("Geocoding location...", log: .location, type: .debug)
        self.geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let _self = self else {
                return
            }
            
            guard error == nil else {
                os_log("Error geocoding location: %@", log: .location, type: .error, error!.localizedDescription)
                return
            }
            
            if let placemark = placemarks?.first {
                if let name = placemark.name {
                    os_log("Successfully geocoded location: %@", log: .location, type: .debug, name)
                } else {
                    os_log("Successfully geocoded location", log: .location, type: .debug)
                }
                
                _self.location = placemark.context
            } else {
                os_log("No placemark found for location %@", log: .location, type: .default, location)
                _self.location = location.context(placemark: nil)
            }
            
            _self.eventQueue.addEvent(EventInfo.locationUpdate)
        }
    }
    
    func updateMonitoredRegions(manager: CLLocationManager) {
        let beaconRegions: Set<CLRegion> = Beacon.fetchAll(in: self.context).wildCardRegions(maxLength: self.maxBeaconRegionsToMonitor)
        os_log("Monitoring for %d wildcard (UUID-only) beacon regions", log: .location, type: .debug, beaconRegions.count)
        
        let circularRegions: Set<CLRegion> = Geofence.fetchAll(in: self.context).regions(closestTo: manager.location?.coordinate, maxLength: self.maxGeofenceRegionsToMonitor - beaconRegions.count)
        os_log("Monitoring for %d circular (geofence) regions", log: .location, type: .debug, circularRegions.count)
        
        let combinedRegions = beaconRegions.union(circularRegions)
        manager.monitor(for: combinedRegions)
    }
    
    func enterGeofence(region: CLCircularRegion) {
        guard let geofence = Geofence.fetch(regionIdentifier: region.identifier, in: self.context) else {
            return
        }
        
        self.currentGeofences.insert(geofence)
        self.geofenceObservers.notify(parameters: self.currentGeofences)
        
        os_log("Entered geofence: %@", log: .location, type: .debug, geofence)
        eventQueue.addEvent(geofence.enterEvent)
    }
    
    func exitGeofence(region: CLCircularRegion) {
        guard let geofence = Geofence.fetch(regionIdentifier: region.identifier, in: self.context) else {
            return
        }
        
        self.currentGeofences.remove(geofence)
        self.geofenceObservers.notify(parameters: self.currentGeofences)
        
        os_log("Exited geofence: %@", log: .location, type: .debug, geofence)
        eventQueue.addEvent(geofence.exitEvent)
    }
    
    func startRangingBeacons(in region: CLBeaconRegion, manager: CLLocationManager) {
        os_log("Started ranging beacons in region: %@", log: .location, type: .debug, region)
        manager.startRangingBeacons(in: region)
    }
    
    func stopRangingBeacons(in region: CLBeaconRegion, manager: CLLocationManager) {
        os_log("Stopped ranging beacons in region: %@", log: .location, type: .debug, region)
        manager.stopRangingBeacons(in: region)
        
        // If there are any lingering beacons when we stop ranging, track exit
        // events and clear them from `beaconMap`.
        
        self.beaconMap[region]?.forEach {
            os_log("Exited beacon: %@", log: .location, type: .debug, $0)
            eventQueue.addEvent($0.exitEvent)
        }
        
        self.beaconMap[region] = nil
    }
    
    func updateNearbyBeacons(_ beacons: [CLBeacon], in region: CLBeaconRegion, manager: CLLocationManager) {
        os_log("Found %d nearby beacons in region: %@", log: .location, type: .debug, beacons.count, region)
        
        let previousBeacons = self.beaconMap[region] ?? Set<Beacon>()
        let identifiers = Set<RegionIdentifier>(beacons.map { $0.regionIdentifier })
        let nextBeacons = Beacon.fetchAll(matchingRegionIdentifiers: identifiers, in: self.context)
        
        guard previousBeacons != nextBeacons else {
            os_log("Nearby beacons already up to date", log: .location, type: .debug)
            return
        }
        
        self.beaconMap[region] = nextBeacons
        
        let enteredBeacons = nextBeacons.subtracting(previousBeacons)
        enteredBeacons.forEach {
            os_log("Entered beacon: %@", log: .location, type: .debug, $0)
            eventQueue.addEvent($0.enterEvent)
        }
        
        let exitedBeacons = previousBeacons.subtracting(nextBeacons)
        exitedBeacons.forEach {
            os_log("Exited beacon: %@", log: .location, type: .debug, $0)
            eventQueue.addEvent($0.exitEvent)
        }
        
        beaconObservers.notify(parameters: self.currentBeacons)
    }
}
