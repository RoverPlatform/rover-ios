//
//  RegionManager.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-20.
//
//

import Foundation
import CoreLocation

let RegionManagerCurrentRegionsKey = "RVRegionManagerCurrentRegionsKey"

public class RegionManager : NSObject {
    
    // MARK: Public Properties

    public weak var delegate: RegionManagerDelegate?
    public var currentRegions: Set<CLBeaconRegion>
    public var beaconRegions: [CLBeaconRegion]? = [CLBeaconRegion]()
    public var monitoredRegions: Set<CLBeaconRegion>? {
        return Set(locationManager.monitoredRegions.filter { $0 is CLBeaconRegion }) as? Set<CLBeaconRegion>
    }
    private(set) var monitoring = false
//    public var beaconUUIDs: [NSUUID]? {
//        didSet {
//            stopMonitoring()
//            setupBeaconRegionsForUUIDs(beaconUUIDs)
//        }
//    }
    
    // MARK: Private Properties
    
    private let locationManager = CLLocationManager()
    
    
    // MARK: Initialization
    
    override init () {
        if let data = NSUserDefaults.standardUserDefaults().objectForKey(RegionManagerCurrentRegionsKey) as? NSData,
            regionsOnDisk = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? Set<CLBeaconRegion> {
                currentRegions = regionsOnDisk
                // LOG TRACE "Pulling current beacon regions from disk: \(currentRegions)"
        } else {
            currentRegions = []
        }
        
        super.init()
        
        locationManager.requestAlwaysAuthorization()
        locationManager.delegate = self
    }
    
    // MARK: Private Instance Methods
    
    private func updateCurrentRegions(regions: Set<CLBeaconRegion>) {
        currentRegions = regions
        let data = NSKeyedArchiver.archivedDataWithRootObject(regions)
        NSUserDefaults.standardUserDefaults().setObject(data, forKey: RegionManagerCurrentRegionsKey)
    }
    
//    private func setupBeaconRegionsForUUIDs(UUIDS: Array<NSUUID>?) {
//        beaconRegions.removeAll()
//        
//        UUIDS?.forEach({ (UUID) -> () in
//            let beaconRegion = CLBeaconRegion(proximityUUID: UUID, identifier: UUID.UUIDString)
//            beaconRegion.notifyEntryStateOnDisplay = true
//            beaconRegions.append(beaconRegion)
//        })
//    }
    
    // MARK: Public Instance Methods
    
    public func startMonitoring() {
        beaconRegions?.forEach { (region) -> () in
            region.notifyEntryStateOnDisplay = true
            locationManager.startMonitoringForRegion(region)
            locationManager.startRangingBeaconsInRegion(region)
        }
        
        monitoring = true
        
        rvLog("Beacon monitoring/ranging started for regions: \(beaconRegions)")
    }
    
    public func stopMonitoring() {
        monitoredRegions?.forEach({ (region) -> () in
            locationManager.stopMonitoringForRegion(region)
            locationManager.stopRangingBeaconsInRegion(region)
        })
        
        monitoring = false
        
        rvLog("Beacon monitoring/ranging stopped")
    }
    
    public func startMonitoring(regions: Array<CLBeaconRegion>) {
        regions.forEach { (region) -> () in
            region.notifyEntryStateOnDisplay = true
            locationManager.startMonitoringForRegion(region)
        }
        
        rvLog("Beacon monitoring started for regions: \(regions)")
        // LOG DEBUG "Beacon monitoring started for regions: \(regions)"
    }

    public func stopMonitoringForAllSpecificRegions() {
        monitoredRegions?.forEach({ (region) -> () in
            if (region.major != nil) && (region.minor != nil) {
                locationManager.stopMonitoringForRegion(region)
                // LOG DEBUG "Beacon monitoring stopped for region: \(region)"
            }
        })
    }
    
    public func simulateRegionEnter(beaconUUID: NSUUID, major: CLBeaconMajorValue, minor: CLBeaconMinorValue) {
        
    }
    
    public func simulateRegionExit(beaconUUID: NSUUID, major: CLBeaconMajorValue, minor: CLBeaconMinorValue) {
        
    }
}

public protocol RegionManagerDelegate: class {
    func regionManager(manager: RegionManager, didEnterRegion region: CLBeaconRegion);
    func regionManager(manager: RegionManager, didExitRegion region: CLBeaconRegion);
}

// MARK: CLLocationManagerDelegate

extension RegionManager : CLLocationManagerDelegate {

    private func identifierForBeacon(UUID: NSUUID, majorNumber: NSNumber, minorNumber: NSNumber) -> String {
        return "\(UUID.UUIDString)-\(majorNumber)-\(minorNumber)"
    }
    
    public func locationManager(manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], inRegion region: CLBeaconRegion) {
        let regions = Set(beacons.map({ (beacon) -> CLBeaconRegion in
            CLBeaconRegion(proximityUUID: beacon.proximityUUID, major: CLBeaconMajorValue(beacon.major.integerValue), minor: CLBeaconMinorValue(beacon.minor.integerValue), identifier: identifierForBeacon(beacon.proximityUUID, majorNumber: beacon.major, minorNumber: beacon.minor))
        }))
        
        if regions == currentRegions {
            return
        } else {
            let enteredRegions = regions.subtract(currentRegions)
            let exitedRegions = currentRegions.subtract(regions)
            
            updateCurrentRegions(regions)
            
            exitedRegions.forEach({ (region) -> () in
                delegate?.regionManager(self, didExitRegion: region)
                // LOG TRACE "Exited beacon region: \(region)"
            })
            
            enteredRegions.forEach({ (region) -> () in
                delegate?.regionManager(self, didEnterRegion: region)
                // LOG TRACE "Entered beacon region: \(region)"
            })
        }
    }
    
    public func locationManager(manager: CLLocationManager, monitoringDidFailForRegion region: CLRegion?, withError error: NSError) {
#if TARGET_OS_SIMULATOR
        struct TokenHolder {
            static var token: dispatch_once_t = 0;
        }
        
        dispatch_once(&TokenHolder.token) {
            //RV_LWARN(@"The iOS Simulator does not support monitoring for beacons. To simulate a beacon use the [Rover simulateBeaconWithUUID:major:minor:] method. See http://dev.roverlabs.co/v1.0/docs/getting-started#simulate-a-beacon for more details.");
        }
#else
        //RV_LWARN(@"Monitoring failed for region: %@", region);
        //RV_LDEBUG(@"Currently monitored regions: %@", manager.monitoredRegions);
#endif
        
    }
}