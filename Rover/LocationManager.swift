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
    func locationManager(_ manager: LocatioManager, didEnterRegion region: CLRegion)
    func locationManager(_ manager: LocatioManager, didExitRegion region: CLRegion)
    func locationManager(_ manager: LocatioManager, didUpdateLocations locations: [CLLocation])
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
                let newRegions = newValue.subtracting(monitoredRegions)
                let oldRegions = monitoredRegions.subtracting(newValue)
                
                stopMonitoringAndRangingForRegions(oldRegions)
                startMonitoringAndRangingForRegions(newRegions)
            }
        }
    }
    
    var isMonitoring: Bool {
        if let monitoring = _isMonitoring {
            return monitoring
        }
        
        _isMonitoring = UserDefaults.standard.bool(forKey: RoverMonitoringStartedKey)
        return _isMonitoring ?? false
    }
    
    fileprivate let locationManager = CLLocationManager()
    fileprivate var currentBeaconRegions = [String:Set<CLBeaconRegion>]()
    fileprivate var _isMonitoring: Bool? {
        didSet {
            UserDefaults.standard.set(_isMonitoring!, forKey: RoverMonitoringStartedKey)
        }
    }
    
    override init() {
        super.init()
        
        locationManager.delegate = self
        
        if isMonitoring {
            locationManager.startMonitoringSignificantLocationChanges()
            
            let beaconRegions = monitoredRegions.flatMap({ $0 as? CLBeaconRegion })
            beaconRegions.forEach { region in
                locationManager.startRangingBeacons(in: region)
            }
        }
    }
    
    func startMonitoring() {
        locationManager.startMonitoringSignificantLocationChanges()
        
        _isMonitoring = true
        
        rvLog("Monitoring started.", level: .trace)
    }
    
    func stopMonitoring() {
        locationManager.stopMonitoringSignificantLocationChanges()
    
        stopMonitoringAndRangingForRegions(monitoredRegions)
        
        _isMonitoring = false
        
        rvLog("Monitoring stopped.", level: .trace)
    }
    
    fileprivate func stopMonitoringAndRangingForRegions(_ regions: Set<CLRegion>) {
        regions.forEach { region in
            locationManager.stopMonitoring(for: region)
            
            if let beaconRegion = region as? CLBeaconRegion {
                locationManager.stopRangingBeacons(in: beaconRegion)
            }
        }
    }
    
    fileprivate func startMonitoringAndRangingForRegions(_ regions: Set<CLRegion>) {
        regions.forEach { region in
            locationManager.startMonitoring(for: region)
            
            if let beaconRegion = region as? CLBeaconRegion {
                locationManager.startRangingBeacons(in: beaconRegion)
            }
        }
    }
    
}

extension LocatioManager : CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        rvLog("Received location update.", data: locations[0], level: .trace)
        delegate?.locationManager(self, didUpdateLocations: locations)
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region is CLCircularRegion else { return }
        rvLog("Received geofence enter.", data: region, level: .trace)
        delegate?.locationManager(self, didEnterRegion: region)
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region is CLCircularRegion else { return }
        rvLog("Received geofence exit", data: region, level: .trace)
        delegate?.locationManager(self, didExitRegion: region)
    }
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        
        guard manager == locationManager else { return }
        
        let regions = Set(beacons.map { (beacon) -> CLBeaconRegion in
            CLBeaconRegion(proximityUUID: beacon.proximityUUID, major: CLBeaconMajorValue(beacon.major.intValue), minor: CLBeaconMinorValue(beacon.minor.intValue), identifier: identifierForBeacon(beacon))
        })
        
        let currentRegions = currentBeaconRegions[region.identifier] ?? Set<CLBeaconRegion>()
        
        guard regions != currentRegions else { return }
        
        let enteredRegions = regions.subtracting(currentRegions)
        let exitedRegions = currentRegions.subtracting(regions)
        
        currentBeaconRegions[region.identifier] = regions
        
        exitedRegions.forEach { region in
            rvLog("Received beacon exit", data: region, level: .trace)
            delegate?.locationManager(self, didExitRegion: region)
        }
        
        enteredRegions.forEach { region in
            rvLog("Received beacon enter", data: region, level: .trace)
            delegate?.locationManager(self, didEnterRegion: region)
        }
    }
    
    // MARK: Helpers
    
    func identifierForBeacon(_ beacon: CLBeacon) -> String {
        return "\(beacon.proximityUUID.uuidString)-\(beacon.major)-\(beacon.minor)"
    }
    
}
