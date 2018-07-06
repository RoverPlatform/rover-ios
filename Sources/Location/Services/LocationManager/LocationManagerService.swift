//
//  LocationManagerService.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-05-04.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation

class LocationManagerService: NSObject, LocationManager, CLLocationManagerDelegate {
    let eventQueue: EventQueue
    let locationManager: CLLocationManager
    let regionStore: RegionStore
    
    var regionsObserveration: NSObjectProtocol?
    
    var isAutomaticLocationEventTrackingEnabled: Bool = false {
        didSet {
            if isAutomaticLocationEventTrackingEnabled {
                locationManager.delegate = self
            } else {
                locationManager.delegate = nil
            }
        }
    }
    
    var isAutomaticRegionManagementEnabled: Bool = false {
        didSet {
            if isAutomaticRegionManagementEnabled {
                regionsObserveration = regionStore.addObserver { [weak self] regions in
                    self?.locationManager.monitor(for: regions)
                }
            } else {
                regionsObserveration = nil
            }
        }
    }
    
    var isSignificantLocationMonitoringEnabled: Bool = false {
        didSet {
            if isSignificantLocationMonitoringEnabled {
                locationManager.startMonitoringSignificantLocationChanges()
            } else {
                locationManager.stopMonitoringSignificantLocationChanges()
            }
        }
    }
    
    init(eventQueue: EventQueue, locationManager: CLLocationManager, regionStore: RegionStore) {
        self.eventQueue = eventQueue
        self.locationManager = locationManager
        self.regionStore = regionStore
    }
    
    func trackEnterRegion(_ region: CLRegion) {
        switch region {
        case let region as CLCircularRegion:
            let attributes: Attributes = [
                "identifier": region.identifier,
                "latitude": region.center.latitude,
                "longitude": region.center.longitude,
                "radius": region.radius
            ]
            let event = EventInfo(name: "Geofence Region Entered", namespace: "rover", attributes: attributes)
            eventQueue.addEvent(event)
        case let region as CLBeaconRegion:
            var attributes: Attributes = [
                "identifier": region.identifier,
                "uuid": region.proximityUUID.uuidString
            ]
            
            if let major = region.major {
                attributes["major"] = major.intValue
            }
            
            if let minor = region.minor {
                attributes["minor"] = minor.intValue
            }
            
            let event = EventInfo(name: "Beacon Region Entered", namespace: "rover", attributes: attributes)
            eventQueue.addEvent(event)
        default:
            fatalError("CLRegion must of type CLCircularRegion or CLBeaconRegion")
        }
    }
    
    func trackExitRegion(_ region: CLRegion) {
        switch region {
        case let region as CLCircularRegion:
            let attributes: Attributes = [
                "identifier": region.identifier,
                "latitude": region.center.latitude,
                "longitude": region.center.longitude,
                "radius": region.radius
            ]
            
            let event = EventInfo(name: "Geofence Region Exited", namespace: "rover", attributes: attributes)
            eventQueue.addEvent(event)
        case let region as CLBeaconRegion:
            var attributes: Attributes = [
                "identifier": region.identifier,
                "uuid": region.proximityUUID.uuidString
            ]
            
            if let major = region.major {
                attributes["major"] = major.intValue
            }
            
            if let minor = region.minor {
                attributes["minor"] = minor.intValue
            }
            
            let event = EventInfo(name: "Beacon Region Exited", namespace: "rover", attributes: attributes)
            eventQueue.addEvent(event)
        default:
            fatalError("CLRegion must of type CLCircularRegion or CLBeaconRegion")
        }
    }
    
    func trackUpdateLocations(_ locations: [CLLocation]) {
        locations.forEach { location in
            var attributes: Attributes = [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "altitude": location.altitude,
                "horizontalAccuracy": location.horizontalAccuracy,
                "verticalAccuracy": location.verticalAccuracy
            ]
            
            if let floor = location.floor?.level {
                attributes["floor"] = floor
            }
            
            let event = EventInfo(name: "Location Updated", namespace: "rover", attributes: attributes, timestamp: location.timestamp)
            eventQueue.addEvent(event)
        }
    }
    
    func trackVisit(_ visit: CLVisit) {
        let attributes: Attributes = [
            "latitude": visit.coordinate.latitude,
            "longiutde": visit.coordinate.longitude,
            "accuracy": visit.horizontalAccuracy,
            "arrival": visit.arrivalDate,
            "departure": visit.departureDate
        ]
        
        let event = EventInfo(name: "Location Visited", namespace: "rover", attributes: attributes, timestamp: visit.arrivalDate)
        eventQueue.addEvent(event)
    }
    
    // MARK: CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        trackVisit(visit)
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        trackEnterRegion(region)
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        trackExitRegion(region)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        trackUpdateLocations(locations)
    }
}
