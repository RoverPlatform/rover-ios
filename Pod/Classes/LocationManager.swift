//
//  LocationManager.swift
//  Pods
//
//  Created by Ata Namvari on 2016-02-11.
//
//

import UIKit
import CoreLocation

class LocationManager: NSObject {

    // MARK: Public Properties
    
    weak var delegate: LocationManagerDelegate?
    private(set) var monitoring = false
    var lastUpdatedLocation: CLLocation? {
        get {
            if _lastUpdatedLocation != nil {
                return _lastUpdatedLocation
            }
            
            if let data = NSUserDefaults.standardUserDefaults().objectForKey("ROVER_LAST_UPDATED_LOCATION") as? NSData, let loc = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? CLLocation {
                rvLog("Pulling last updated location from disk")
                return loc
            }
            return nil
        }
        set {
            _lastUpdatedLocation = newValue
            
            guard let newLoc = newValue else { return }
            
            let data = NSKeyedArchiver.archivedDataWithRootObject(newLoc)
            NSUserDefaults.standardUserDefaults().setObject(data, forKey: "ROVER_LAST_UPDATED_LOCATION")
        }
    }
    
    // MARK: Private Properties
    
    private var _lastUpdatedLocation: CLLocation?
    private let locationManager = CLLocationManager()
    
    // MARK: Initialization
    
    override init() {
        super.init()
        
        locationManager.delegate = self
    }
    
    // MARK: Public Instance Methods
    
    func startMonitoringLocationUpdates() {
        if CLLocationManager.authorizationStatus() != .AuthorizedAlways {
            locationManager.requestAlwaysAuthorization()
        }
        
        locationManager.startMonitoringSignificantLocationChanges()
        monitoring = true
        
        rvLog("Location updates monitoring started")
    }
    
    func stopMonitoringLocationUpdates() {
        locationManager.stopMonitoringSignificantLocationChanges()
        monitoring = false
        
        rvLog("Location updates monitoring stopped")
    }
    
}

protocol LocationManagerDelegate: class {
    func locationManager(manager manager: LocationManager, didChangeLocation location: CLLocation)
}

// MARK: CLLocationManagerDelegate

extension LocationManager : CLLocationManagerDelegate {
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if manager === locationManager && status == .AuthorizedAlways && monitoring {
            startMonitoringLocationUpdates()
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateToLocation newLocation: CLLocation, fromLocation oldLocation: CLLocation) {
        
        rvLog("Location update received: \(newLocation)", level: .Trace)

//        if (self.lastUpdatedLocation) {
//            CLLocationDistance distance = [location distanceFromLocation:self.lastUpdatedLocation];
//            if (distance < _threshold * 1000) {
//                return;
//            }
//        }
        
        lastUpdatedLocation = newLocation
        
        rvLog("Location manager did change location: \(newLocation)")
        
        delegate?.locationManager(manager: self, didChangeLocation: newLocation)
        
    }
}