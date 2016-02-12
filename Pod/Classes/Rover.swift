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
    
    private static let _sharedInstance = Rover()
    private static var sharedInstance: Rover? {
        guard _sharedInstance.applicationToken != nil else {
            rvLog("Rover accessed before setup", level: .Error)
            return nil
        }
        return _sharedInstance
    }
    
    private var applicationToken: String?
    
    private let regionManager = RegionManager()
    private let geofenceManager = GeofenceManager()
    private let locationManager = LocationManager()
    
    private let operationQueue = NSOperationQueue()
    
    override init () {
        super.init()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidOpen", name: UIApplicationDidFinishLaunchingNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidOpen", name: UIApplicationWillEnterForegroundNotification, object: nil)
        
        regionManager.delegate = self
        //regionManager.threshold = 40
        geofenceManager.delegate = self
        locationManager.delegate = self

    }
    
    // MARK: Class Methods
    
    public class func setup(applicationToken applicationToken: String) {
        _sharedInstance.applicationToken = applicationToken
        
        sharedInstance?.grabRegions()
    }
    
    public class func startMonitoring() {
        sharedInstance?.regionManager.startMonitoring()
        sharedInstance?.geofenceManager.startMonitoring()
    }
    
    public class func stopMonitoring() {
        sharedInstance?.regionManager.stopMonitoring()
        sharedInstance?.geofenceManager.stopMonitoring()
    }
    
    public class func registerForNotifications() {
        UIApplication.sharedApplication().registerUserNotificationSettings(UIUserNotificationSettings(forTypes: [.Alert, .Badge, .Sound], categories: nil))
        UIApplication.sharedApplication().registerForRemoteNotifications()
    }
    
    private(set) var observers = [RoverObserver]()
    
    public class func addObserver(observer: RoverObserver) {
        sharedInstance?.observers.append(observer)
    }
    
    public class func removeObserver(observer: RoverObserver) {
//        sharedInstance?.observers.removeAtIndex((sharedInstance.observers.indexOf({$0 === observer})!))
    }
    
    public class func identify(alias alias: String) {
        User.sharedUser.alias = alias
    }
   
    // MARK: Application Hooks
    
    public class func didRegisterForRemoteNotification(deviceToken deviceToken: NSData) {
        let deviceTokenString = String(deviceToken).stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "<>")).stringByReplacingOccurrencesOfString(" ", withString: "")
        guard Device.pushToken != deviceTokenString else {
            return
        }
        
        Device.pushToken = deviceTokenString
        
        // update device event
        
        let event = Event.DeviceUpdate(NSDate())
        
        let networkOperation = NetworkOperation(mutableUrlRequest: Router.Events.urlRequest, completion: nil)
        let serializingOperation = SerializingOperation(model: event) { (JSON) -> Void in
            networkOperation.payload = JSON
        }
        
        networkOperation.addDependency(serializingOperation)
        
        sharedInstance?.operationQueue.addOperation(serializingOperation)
        sharedInstance?.operationQueue.addOperation(networkOperation)
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
    
    // MARK: UIApplicationNotifications
    
    func applicationDidOpen() {
        
        // possible mapping operation for Message
        
        let event = Event.ApplicationOpen(NSDate())
        
        let mappingOperation = MappingOperation<Message> { (messages: [Message]) -> Void in
            
        }
        let networkOperation = NetworkOperation(mutableUrlRequest: Router.Events.urlRequest) { (JSON, error) -> Void in
            mappingOperation.json = JSON
        }
        let serializingOperation = SerializingOperation(model: event) { (JSON) -> Void in
            networkOperation.payload = JSON
        }
        let bluetoothStatusOperation = BluetoothStatusOperation { (isOn) -> Void in
            Device.bluetoothOn = isOn
        }

        
        serializingOperation.addDependency(bluetoothStatusOperation)
        networkOperation.addDependency(serializingOperation)
        
        operationQueue.addOperation(bluetoothStatusOperation)
        operationQueue.addOperation(serializingOperation)
        operationQueue.addOperation(networkOperation)
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

extension Rover : LocationManagerDelegate {
    func locationManager(manager manager: LocationManager, didChangeLocation location: CLLocation) {
        
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
            return NSURL(string: "https://rover-content-api-staging-pr-7.herokuapp.com/v1/events")!
        case .Regions:
            return NSURL(string: "https://rover-content-api-staging-pr-4.herokuapp.com/v1/regions")!
        }
    }
    
    var urlRequest: NSMutableURLRequest {
        let urlRequest = NSMutableURLRequest(URL: self.url)
        urlRequest.HTTPMethod = self.method
        urlRequest.setValue(Rover.sharedInstance?.applicationToken, forHTTPHeaderField: "X-Rover-Api-Key")
        return urlRequest
    }
}



