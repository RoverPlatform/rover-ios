//
//  Rover.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-25.
//
//

import Foundation
import CoreLocation

public class Rover : NSObject {
    
    private static let sharedInstance = Rover()
    
    private var applicationToken: String?
    private let regionManager = RegionManager()
    private let geofenceManager = GeofenceManager()
    private let operationQueue = NSOperationQueue()
    
    override init () {
        super.init()
        
        regionManager.delegate = self
        //regionManager.threshold = 40
        geofenceManager.delegate = self
        
        grabRegions()
    }
    
    // MARK: Class Methods
    
    public class func setup(applicationToken applicationToken: String) {
        sharedInstance.applicationToken = applicationToken
    }
    
    public class func startMonitoring() {
        sharedInstance.regionManager.startMonitoring()
        sharedInstance.geofenceManager.startMonitoring()
    }
    
    public class func stopMonitoring() {
        sharedInstance.regionManager.stopMonitoring()
        sharedInstance.geofenceManager.stopMonitoring()
    }
    
    public class func registerForNotifications() {
        //UIApplication.sharedApplication().registerForRemoteNotifications()
    }
    
    private(set) var observers = [RoverObserver]()
    
    public class func addObserver(observer: RoverObserver) {
        sharedInstance.observers.append(observer)
    }
    
    public class func removeObserver(observer: RoverObserver) {
        sharedInstance.observers.removeAtIndex(sharedInstance.observers.indexOf({$0 === observer})!)
    }
    
    // MARK: Instance Methods
    
    func notifyObservers(event event: Event) {
        for observer in observers {
            event.call(observer)
        }
    }
    
    func grabRegions() {
        let mappingOperation = MappingOperation<CLRegion> { (regions: [CLRegion]) -> Void in
            let beaconRegions = regions.filter({ $0 is CLBeaconRegion }) as? [CLBeaconRegion]
            self.regionManager.beaconRegions = beaconRegions
            
            dispatch_async(dispatch_get_main_queue()) {
                if (self.regionManager.monitoring /* && self.regionManager.monitoredRegions != beaconRegions */) {
                    self.regionManager.stopMonitoring()
                    self.regionManager.startMonitoring()
                }
            }
            
            let geofenceRegions = regions.filter({ $0 is CLCircularRegion }) as? [CLCircularRegion]
            self.geofenceManager.geofenceRegions = geofenceRegions
        
            dispatch_async(dispatch_get_main_queue()) {
                if (self.geofenceManager.monitoring /* && self.geofenceManager.monitoredRegions != geofenceRegions */ ) {
                    self.geofenceManager.stopMonitoring()
                    self.geofenceManager.startMonitoring()
                }
            }
        }
        let networkOperation = NetworkOperation(urlRequest: Router.Regions.urlRequest) { (JSON, error) -> Void in
            mappingOperation.json = JSON
        }
        
        mappingOperation.addDependency(networkOperation)
        operationQueue.addOperation(networkOperation)
        operationQueue.addOperation(mappingOperation)
    }
    
}

extension Rover : RegionManagerDelegate {
    public func regionManager(manager: RegionManager, didEnterRegion region: CLBeaconRegion) {
        let event = Event.DidEnterBeaconRegion(region, nil)
        
        let mappingOperation = MappingOperation<Event> { (event: Event) -> Void in
            self.notifyObservers(event: event)
        }
        let includedMappingOperation = MappingOperation<BeaconConfiguration> { (beaconConfigs: [BeaconConfiguration]) -> Void in
            mappingOperation.included = beaconConfigs
            mappingOperation.included?.append(region)
        }
        let networkOperation = NetworkOperation(mutableUrlRequest: Router.Events.urlRequest) { (JSON, error) -> Void in
            if let included = JSON?["included"] as? [[String: AnyObject]] { includedMappingOperation.json = ["data": included] }
            mappingOperation.json = JSON
        }
        let serializingOperation = SerializingOperation(model: event) { (JSON) -> Void in
            networkOperation.payload = JSON
        }
        
        networkOperation.addDependency(serializingOperation)
        includedMappingOperation.addDependency(networkOperation)
        mappingOperation.addDependency(includedMappingOperation)
        
        operationQueue.addOperation(serializingOperation)
        operationQueue.addOperation(networkOperation)
        operationQueue.addOperation(includedMappingOperation)
        operationQueue.addOperation(mappingOperation)
    }
    
    public func regionManager(manager: RegionManager, didExitRegion region: CLBeaconRegion) {
        
    }
}

extension Rover : GeofenceManagerDelegate {
    func geofenceManager(manager: GeofenceManager, didEnterRegion: CLCircularRegion) {
        
    }
    
    func geofenceManager(manager: GeofenceManager, didExitRegion: CLCircularRegion) {
        
    }
}

enum Router {
    case Events
    case Regions
    
    var method: String {
        switch self {
        case .Events:
            return "POST"
        default:
            return "GET"
        }
    }
    
    var url: NSURL {
        switch self {
        case .Events:
            return NSURL(string: "https://api.rover.io/events")!
        case .Regions:
            return NSURL(string: "https://rover-content-api-staging-pr-4.herokuapp.com/v1/regions")!
        }
    }
    
    var urlRequest: NSMutableURLRequest {
        let urlRequest = NSMutableURLRequest(URL: self.url)
        urlRequest.HTTPMethod = self.method
        urlRequest.setValue(Rover.sharedInstance.applicationToken, forHTTPHeaderField: "X-Rover-Api-Key")
        return urlRequest
    }
}

