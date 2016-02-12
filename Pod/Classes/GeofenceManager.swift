//
//  GeofenceManager.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-29.
//
//

import Foundation
import CoreLocation

let GeofenceManagerCurrentRegionsKey = "RVGeofenceManagerCurrentRegionsKey"

class GeofenceManager : NSObject {
    
    // MARK: Public Properties
    
    weak var delegate: GeofenceManagerDelegate?
    var currentRegions: Set<CLCircularRegion>
    var geofenceRegions: [CLCircularRegion]? = [CLCircularRegion]() // TODO: investigate ordered sets in Swift
    var monitoredRegions: Set<CLCircularRegion>? {
        return Set(locationManager.monitoredRegions.filter { $0 is CLCircularRegion }) as? Set<CLCircularRegion>
    }
    private(set) var monitoring = false
    
    // MARK: Private Properties
    
    private let locationManager = CLLocationManager()
    
    // MARK: Initialization
    
    override init() {
        if let data = NSUserDefaults.standardUserDefaults().objectForKey(GeofenceManagerCurrentRegionsKey) as? NSData, regionsOnDisk = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? Set<CLCircularRegion> {
            currentRegions = regionsOnDisk
            // LOG TRACE "Pulling current geofence regions from disk: \(geofenceRegions)"
        } else {
            currentRegions = []
        }
        
        super.init()
    
        locationManager.requestAlwaysAuthorization()
        locationManager.delegate = self
    }
    
    // MARK: Private Instance Methods
    
    private func updateCurrentRegions(regions: Set<CLCircularRegion>) {
        currentRegions = regions
        let data = NSKeyedArchiver.archivedDataWithRootObject(regions)
        NSUserDefaults.standardUserDefaults().setObject(data, forKey: GeofenceManagerCurrentRegionsKey)
    }
    
    // MARK: Public Instance Methods
    
    func startMonitoring() {
        geofenceRegions?.forEach { region in
            locationManager.startMonitoringForRegion(region)
        }
        
        // NOTE: This is cause of an Apple Bug
        // https://www.cocoanetics.com/2014/05/radar-monitoring-clregion-immediately-after-removing-one-fails/
        
        // TODO: This has got to be more precise
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.3 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            self.geofenceRegions?.forEach { region in
                self.locationManager.requestStateForRegion(region)
            }
        }
        
        monitoring = true
        
        // LOG DEBUG "Geofence monitoring started for regions: \(geofenceRegions)"
    }
    
    func stopMonitoring() {
        monitoredRegions?.forEach({ (region) -> () in
            locationManager.stopMonitoringForRegion(region)
        })
        
        // LOG DEBUG "Geofence monitoring stopped"
        
        monitoring = false
    }
}

protocol GeofenceManagerDelegate: class {
    func geofenceManager(manager: GeofenceManager, didEnterRegion: CLCircularRegion)
    func geofenceManager(manager: GeofenceManager, didExitRegion: CLCircularRegion)
}

// MARK: CLLocationManagerDelegate

extension GeofenceManager : CLLocationManagerDelegate {
    func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let region = region as? CLCircularRegion else { return }
        handleEnter(region: region)
    }
    
    func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let region = region as? CLCircularRegion else { return }
        handleExit(region: region)
    }
    
    func locationManager(manager: CLLocationManager, didDetermineState state: CLRegionState, forRegion region: CLRegion) {
        guard let region = region as? CLCircularRegion else { return }
        switch state {
        case .Inside:
            handleEnter(region: region)
        case .Outside:
            handleExit(region: region)
        default:
            break
        }
        
        // LOG TRACE "State determined (\(state)) for geofence region: \(region)"
    }
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        guard manager === locationManager && status == .AuthorizedAlways && monitoring else {
            // LOG DEBUG "Location manager always authorization revoked"
            return
        }
        // LOG TRACE "Location manager always authorization granted"
        startMonitoring()
    }
    
    func handleEnter(region region: CLCircularRegion) {
        if !currentRegions.contains(region) {
            currentRegions.insert(region)
            updateCurrentRegions(currentRegions)
            
            delegate?.geofenceManager(self, didEnterRegion: region)
            // LOG TRACE "Entered geofence region: \(region)"
        }
    }
    
    func handleExit(region region: CLCircularRegion) {
        if currentRegions.contains(region) {
            currentRegions.remove(region)
            updateCurrentRegions(currentRegions)
            
            delegate?.geofenceManager(self, didExitRegion: region)
            // LOG TRACE "Exited geofence region: \(region)"
        }
    }
}
