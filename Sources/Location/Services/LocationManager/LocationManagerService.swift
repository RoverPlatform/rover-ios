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
        let event: EventInfo = {
            switch region {
            case let region as CLCircularRegion:
                return EventInfo(
                    name: "Geofence Region Entered",
                    namespace: "rover",
                    attributes: [
                        "region": region
                    ]
                )
            case let region as CLBeaconRegion:
                return EventInfo(
                    name: "Beacon Region Entered",
                    namespace: "rover",
                    attributes: [
                        "region": region
                    ]
                )
            default:
                fatalError("CLRegion must of type CLCircularRegion or CLBeaconRegion")
            }
        }()
        
        eventQueue.addEvent(event)
    }
    
    func trackExitRegion(_ region: CLRegion) {
        let event: EventInfo = {
            switch region {
            case let region as CLCircularRegion:
                return EventInfo(
                    name: "Geofence Region Exited",
                    namespace: "rover",
                    attributes: [
                        "region": region
                    ]
                )
            case let region as CLBeaconRegion:
                return EventInfo(
                    name: "Beacon Region Exited",
                    namespace: "rover",
                    attributes: [
                        "region": region
                    ]
                )
            default:
                fatalError("CLRegion must of type CLCircularRegion or CLBeaconRegion")
            }
        }()
        
        eventQueue.addEvent(event)
    }
    
    func trackUpdateLocations(_ locations: [CLLocation]) {
        locations.map({
            EventInfo(
                name: "Location Updated",
                namespace: "rover",
                attributes: [
                    "location": $0
                ],
                timestamp: $0.timestamp
            )
        }).forEach(eventQueue.addEvent)
    }
    
    func trackVisit(_ visit: CLVisit) {
        let event = EventInfo(
            name: "Location Visited",
            namespace: "rover",
            attributes: [
                "visit": visit
            ],
            timestamp: visit.arrivalDate
        )
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
