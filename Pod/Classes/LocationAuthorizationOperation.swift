//
//  LocationAuthorizationOperation.swift
//  Pods
//
//  Created by Ata Namvari on 2016-02-26.
//
//

import Foundation
import CoreLocation

class LocationAuthorizationOperation: ConcurrentOperation, CLLocationManagerDelegate {
    
    var locationManager: CLLocationManager?
    
    override func execute() {
        guard CLLocationManager.authorizationStatus() == .NotDetermined && !cancelled else {
            finish()
            return
        }
        
        rvLog("Requesting location permissions", level: .Trace)
        
        // TODO: Do a check for NSLocationAlwaysUsageDescription in the application .plist
        
        // Delegate won't fire unless CLLocationManager setup is done on main thread
        
        dispatch_async(dispatch_get_main_queue()) {
            self.locationManager = CLLocationManager()
            self.locationManager?.delegate = self
            self.locationManager?.requestAlwaysAuthorization()
        }
    }
    
    // MARK: CLLocationManagerDelegate
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status != .NotDetermined {
            finish()
        }
    }
}
