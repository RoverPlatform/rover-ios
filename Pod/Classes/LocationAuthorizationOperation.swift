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
        guard CLLocationManager.authorizationStatus() == .notDetermined && !isCancelled else {
            finish()
            return
        }
        
        rvLog("Requesting location permissions", level: .trace)
        
        // TODO: Do a check for NSLocationAlwaysUsageDescription in the application .plist
        
        // Delegate won't fire unless CLLocationManager setup is done on main thread
        
        DispatchQueue.main.async {
            self.locationManager = CLLocationManager()
            self.locationManager?.delegate = self
            self.locationManager?.requestAlwaysAuthorization()
        }
    }
    
    // MARK: CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status != .notDetermined {
            finish()
        }
    }
}
