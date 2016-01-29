//
//  RoverObserver.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-25.
//
//

import Foundation
import CoreLocation

@objc public protocol RoverObserver {
    optional func roverDidEnterBeaconRegion(region: CLBeaconRegion, config: BeaconConfiguration)
    optional func roverDidExitBeaconRegion(region: CLBeaconRegion, config: BeaconConfiguration)
}