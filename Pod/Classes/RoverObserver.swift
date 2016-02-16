//
//  RoverObserver.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-25.
//
//

import Foundation
import CoreLocation

@objc
public protocol RoverObserver {
    optional func didEnterBeaconRegion(config config: BeaconConfiguration)//, location: Location?)
    optional func didExitBeaconRegion(config config: BeaconConfiguration)
    optional func didEnterGeofence(location location: Location)
    optional func didExitGeofence(location location: Location)
}