//
//  LocationManager.swift
//  Pods
//
//  Created by Ata Namvari on 2016-02-11.
//
//

import UIKit
import CoreLocation

protocol LocationManagerDelegate: class {
    func locationManager(manager: LocatioManager, didEnterRegion region: CLRegion)
    func locationManager(manager: LocatioManager, didExitRegion region: CLRegion)
    func locationManager(manager: LocatioManager, didUpdateLocations locations: [CLLocation])
}

let RoverMonitoringStartedKey = "ROVER_MONITORING_STARTED"

class LocatioManager: NSObject {
    
    weak var delegate: LocationManagerDelegate?
    var monitoredRegions: Set<CLRegion> { return locationManager.monitoredRegions }
    var isMonitoring: Bool {
        if let monitoring = _isMonitoring {
            return monitoring
        }
        
        _isMonitoring = NSUserDefaults.standardUserDefaults().boolForKey(RoverMonitoringStartedKey)
        return _isMonitoring ?? false
    }
    
    private let locationManager = CLLocationManager()
    private var currentBeaconRegions = Set<CLBeaconRegion>()
    private var _isMonitoring: Bool? {
        didSet { //didChange
            NSUserDefaults.standardUserDefaults().setBool(_isMonitoring!, forKey: RoverMonitoringStartedKey)
        }
    }
    
    override init() {
        super.init()
        
        locationManager.delegate = self
    }
    
    // MARK: Significant Location Monitoring
    
    func startMonitoringSignificantLocationChanges() {
        locationManager.startMonitoringSignificantLocationChanges()
    }
    
    func stopMonitoringSignificantLocationChanges() {
        locationManager.stopMonitoringSignificantLocationChanges()
    }
    
    // MARK: Region Monitoring
    
    func startMonitoringForRegion(region: CLRegion) {
        locationManager.startMonitoringForRegion(region)
        
        if let beaconRegion = region as? CLBeaconRegion {
            locationManager.startRangingBeaconsInRegion(beaconRegion)
        }
        
        _isMonitoring = true
    }
    
    func stopMonitoringForRegion(region: CLRegion) {
        locationManager.stopMonitoringForRegion(region)
        
        if let beaconRegion = region as? CLBeaconRegion {
            locationManager.stopRangingBeaconsInRegion(beaconRegion)
        }
        
        _isMonitoring = false
    }
    
}

extension LocatioManager : CLLocationManagerDelegate {
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        delegate?.locationManager(self, didUpdateLocations: locations)
    }
    
    func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region is CLCircularRegion else { return }
        delegate?.locationManager(self, didEnterRegion: region)
    }
    
    func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region is CLCircularRegion else { return }
        delegate?.locationManager(self, didExitRegion: region)
    }
    
    func locationManager(manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], inRegion region: CLBeaconRegion) {
        let regions = Set(beacons.map { (beacon) -> CLBeaconRegion in
            CLBeaconRegion(proximityUUID: beacon.proximityUUID, major: CLBeaconMajorValue(beacon.major.integerValue), minor: CLBeaconMinorValue(beacon.minor.integerValue), identifier: identifierForBeacon(beacon))
        })
        
        guard regions != currentBeaconRegions else { return }
        
        let enteredRegions = regions.subtract(self.currentBeaconRegions)
        let exitedRegions = currentBeaconRegions.subtract(regions)
        
        currentBeaconRegions = regions
        
        exitedRegions.forEach { region in
            rvLog("Entered beacon region: \(region)", level: .Trace)
            delegate?.locationManager(self, didExitRegion: region)
        }
        
        enteredRegions.forEach { region in
            rvLog("Exited beacon region: \(region)", level: .Trace)
            delegate?.locationManager(self, didEnterRegion: region)
        }
    }
    
    // MARK: Helpers
    
    func identifierForBeacon(beacon: CLBeacon) -> String {
        return "\(beacon.proximityUUID.UUIDString)-\(beacon.major)-\(beacon.minor)"
    }
    
}