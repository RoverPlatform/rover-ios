//
//  RoverObserver.swift
//  RoverSDK
//
//  Created by Ata Namvari on 2016-01-25.
//  Copyright © 2016 Roverlabs Inc. All rights reserved.
//

import Foundation

/*
 Classes that conform to this protocol can be added as an observer to Rover and receive
 proximity and messaging callbacks.
 */

@objc
public protocol RoverObserver {
    
    /*
     Called when user enters a beacon region.
     
     - parameters:
        - config: The configuration of the beacon as it was set in the Rover Proximity App.
        - location: The location of the beacon if had been assigned.
     */
    optional func didEnterBeaconRegion(config config: BeaconConfiguration, location: Location?)
    
    /*
     Called when user exits a beacon region.
     
     - parameters:
        - config: The configuration of the beacon as it was set in the Rover Proximity App.
        - location: The location of the beacon if had been assigned.
     */
    optional func didExitBeaconRegion(config config: BeaconConfiguration, location: Location?)
    
    
    /*
     Called when user enters a geofence.
     
     - paramters: 
        - location: The location that was entered.
    */
    optional func didEnterGeofence(location location: Location) // 3 rules of real estate!!! :)
    
    /*
     Called when user exits a geofence.
     
     - parameters:
        - location: The location that was exited.
     */
    optional func didExitGeofence(location location: Location)

    /*
     Called before a `Message` is about to be delivered.
     
     - returns:
     A Bool indicating whether the `Message` should be delivered. All observers must return `true`
     for a `Message` to get delivered.
     
     - paramters:
        - message: The `Message` that is to be delivered.
     */
    optional func willDeliverMessage(message: Message) -> Bool
    
    /*
     Called after a `Message` has been delivered.
     
     - parameters:
        - message: The `Message` that was delivered.
     */
    optional func didDeliverMessage(message: Message)
}