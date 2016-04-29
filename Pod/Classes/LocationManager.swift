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
    
    var monitoredRegions: Set<CLRegion> {
        get {
            return locationManager.monitoredRegions
        }
        set {
            if isMonitoring {
                let newRegions = newValue.subtract(monitoredRegions)
                let oldRegions = monitoredRegions.subtract(newValue)
                
                stopMonitoringAndRangingForRegions(oldRegions)
                startMonitoringAndRangingForRegions(newRegions)
            }
        }
    }
    
    var isMonitoring: Bool {
        if let monitoring = _isMonitoring {
            return monitoring
        }
        
        _isMonitoring = NSUserDefaults.standardUserDefaults().boolForKey(RoverMonitoringStartedKey)
        return _isMonitoring ?? false
    }
    
    private let locationManager = CLLocationManager()
    private var currentBeaconRegions = [String:Set<CLBeaconRegion>]()
    private var _isMonitoring: Bool? {
        didSet {
            NSUserDefaults.standardUserDefaults().setBool(_isMonitoring!, forKey: RoverMonitoringStartedKey)
        }
    }
    
    override init() {
        super.init()
        
        locationManager.delegate = self
        
        if isMonitoring {
            locationManager.startMonitoringSignificantLocationChanges()
            
            let beaconRegions = monitoredRegions.filter { $0 is CLBeaconRegion } as! [CLBeaconRegion]
            beaconRegions.forEach { region in
                locationManager.startRangingBeaconsInRegion(region)
            }
        }
    }
    
    func startMonitoring() {
        locationManager.startMonitoringSignificantLocationChanges()
        
        _isMonitoring = true
        
        rvLog("Monitoring started.", level: .Trace)
    }
    
    func stopMonitoring() {
        locationManager.stopMonitoringSignificantLocationChanges()
    
        stopMonitoringAndRangingForRegions(monitoredRegions)
        
        _isMonitoring = false
        
        rvLog("Monitoring stopped.", level: .Trace)
    }
    
    private func stopMonitoringAndRangingForRegions(regions: Set<CLRegion>) {
        regions.forEach { region in
            locationManager.stopMonitoringForRegion(region)
            
            if let beaconRegion = region as? CLBeaconRegion {
                locationManager.stopRangingBeaconsInRegion(beaconRegion)
            }
        }
    }
    
    private func startMonitoringAndRangingForRegions(regions: Set<CLRegion>) {
        regions.forEach { region in
            locationManager.startMonitoringForRegion(region)
            
            if let beaconRegion = region as? CLBeaconRegion {
                locationManager.startRangingBeaconsInRegion(beaconRegion)
            }
        }
    }
    
}

extension LocatioManager : CLLocationManagerDelegate {
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        rvLog("Received location update.", data: locations[0], level: .Trace)
        delegate?.locationManager(self, didUpdateLocations: locations)
    }
    
    func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region is CLCircularRegion else { return }
        rvLog("Received geofence enter.", data: region, level: .Trace)
        delegate?.locationManager(self, didEnterRegion: region)
    }
    
    func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region is CLCircularRegion else { return }
        rvLog("Received geofence exit", data: region, level: .Trace)
        delegate?.locationManager(self, didExitRegion: region)
    }
    
    func locationManager(manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], inRegion region: CLBeaconRegion) {
        
        guard manager == locationManager else { return }
        
        let regions = Set(beacons.map { (beacon) -> CLBeaconRegion in
            CLBeaconRegion(proximityUUID: beacon.proximityUUID, major: CLBeaconMajorValue(beacon.major.integerValue), minor: CLBeaconMinorValue(beacon.minor.integerValue), identifier: identifierForBeacon(beacon))
        })
        
        let currentRegions = currentBeaconRegions[region.identifier] ?? Set<CLBeaconRegion>()
        
        guard regions != currentRegions else { return }
        
        let enteredRegions = regions.subtract(currentRegions)
        let exitedRegions = currentRegions.subtract(regions)
        
        currentBeaconRegions[region.identifier] = regions
        
        exitedRegions.forEach { region in
            rvLog("Received beacon exit", data: region, level: .Trace)
            delegate?.locationManager(self, didExitRegion: region)
        }
        
        enteredRegions.forEach { region in
            rvLog("Received beacon enter", data: region, level: .Trace)
            delegate?.locationManager(self, didEnterRegion: region)
        }
    }
    
    // MARK: Helpers
    
    func identifierForBeacon(beacon: CLBeacon) -> String {
        return "\(beacon.proximityUUID.UUIDString)-\(beacon.major)-\(beacon.minor)"
    }
    
}