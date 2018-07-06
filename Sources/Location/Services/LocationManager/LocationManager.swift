//
//  LocationManager.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-02-15.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation

public protocol LocationManager {
    var isAutomaticLocationEventTrackingEnabled: Bool { get set }
    var isAutomaticRegionManagementEnabled: Bool { get set }
    var isSignificantLocationMonitoringEnabled: Bool { get set }
    
    func trackEnterRegion(_ region: CLRegion)
    func trackExitRegion(_ region: CLRegion)
    func trackUpdateLocations(_ locations: [CLLocation])
    func trackVisit(_ visit: CLVisit)
}
