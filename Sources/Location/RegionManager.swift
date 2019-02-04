//
//  RegionManager.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-09-30.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation

public protocol RegionManager: AnyObject {
    var currentGeofences: Set<Geofence> { get }
    var geofenceObservers: ObserverSet<Set<Geofence>> { get set }
    
    var currentBeacons: Set<Beacon> { get }
    var beaconObservers: ObserverSet<Set<Beacon>> { get set }
    
    func updateLocation(manager: CLLocationManager)
    
    func enterGeofence(region: CLCircularRegion)
    func exitGeofence(region: CLCircularRegion)
    
    func startRangingBeacons(in region: CLBeaconRegion, manager: CLLocationManager)
    func stopRangingBeacons(in region: CLBeaconRegion, manager: CLLocationManager)
    func updateNearbyBeacons(_ beacons: [CLBeacon], in region: CLBeaconRegion, manager: CLLocationManager)
}
