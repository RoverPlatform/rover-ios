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
    
    private let locationManager = CLLocationManager()
    private var regions: [CLRegion] = [CLBeaconRegion(proximityUUID: NSUUID(UUIDString: "7931D3AA-299B-4A12-9FCC-D66F2C5D2462")!, identifier: "7931D3AA-299B-4A12-9FCC-D66F2C5D2462")]
    
    private let operationQueue = NSOperationQueue()
    
    override init () {
        super.init()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidOpen", name: UIApplicationDidFinishLaunchingNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidOpen", name: UIApplicationWillEnterForegroundNotification, object: nil)
        
        locationManager.requestAlwaysAuthorization()
        locationManager.delegate = self
    }
    
    // MARK: Class Methods
    
    public static let sharedUser = User.sharedUser
    
    public class func setup(applicationToken applicationToken: String) {
        _sharedInstance.applicationToken = applicationToken
        
    }
    
    public class func startMonitoring() {
        sharedInstance?.startRegionMonitoring()
        sharedInstance?.locationManager.startMonitoringSignificantLocationChanges()
    }
    
    public class func stopMonitoring() {
        sharedInstance?.stopRegionMonitoring()
        sharedInstance?.locationManager.stopMonitoringSignificantLocationChanges()
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
    
    public class func simulateBeaconEnter(UUID UUID: NSUUID, major: CLBeaconMajorValue, minor: CLBeaconMinorValue) {
        let region = CLBeaconRegion(proximityUUID: UUID, major: major, minor: minor, identifier: "SIMULATE")
        sharedInstance?.didEnterBeaconRegion(region)
    }
    
    public class func simulateBeaconExit(UUID UUID: NSUUID, major: CLBeaconMajorValue, minor: CLBeaconMinorValue) {
        let region = CLBeaconRegion(proximityUUID: UUID, major: major, minor: minor, identifier: "SIMULATE")
        sharedInstance?.didExitBeaconRegion(region)
    }
    
    // MARK: Application Hooks
    
    public class func didRegisterForRemoteNotification(deviceToken deviceToken: NSData) {
        let deviceTokenString = String(deviceToken).stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "<>")).stringByReplacingOccurrencesOfString(" ", withString: "")
        guard Device.pushToken != deviceTokenString else {
            return
        }
        
        Device.pushToken = deviceTokenString
        
        sharedInstance?.sendEvent(Event.DeviceUpdate(date: NSDate()))
    }
    
    // MARK: Instance Methods
    
    func startRegionMonitoring() {
        regions.forEach { region in
            locationManager.startMonitoringForRegion(region)
        }
    }
    
    func stopRegionMonitoring() {
        locationManager.monitoredRegions.forEach { region in
            locationManager.stopMonitoringForRegion(region)
        }
    }
    
    func notifyObservers(event event: Event) {
        for observer in observers {
            event.call(observer)
        }
    }
    
    // MARK: UIApplicationNotifications
    
    func applicationDidOpen() {
        sendEvent(.ApplicationOpen(date: NSDate()))
    }
    
    func sendEvent(event: Event) {
        
        let regionMappingOperation = MappingOperation<CLRegion> { (regions: [CLRegion]) in
            guard regions.count > 0 else { return }
            
            self.regions = regions
            dispatch_async(dispatch_get_main_queue()) {
                //if locationManager.monitoredRegions.count > 0 { // isMonitoring
                self.stopRegionMonitoring()
                self.startRegionMonitoring()
            }
        }
        let mappingOperation = MappingOperation<Event> { (event: Event) in
            self.notifyObservers(event: event)
        }
        let networkOperation = NetworkOperation(mutableUrlRequest: Router.Events.urlRequest) { JSON, error in
            if let included = JSON?["included"] as? [[String: AnyObject]] { regionMappingOperation.json = ["data": included] }
            mappingOperation.json = JSON
        }
        let serializingOperation = SerializingOperation(model: event) { JSON in
            networkOperation.payload = JSON
        }
        let bluetoothStatusOperation = BluetoothStatusOperation { isOn in
            Device.bluetoothOn = isOn
        }
        
        mappingOperation.included = event.properties
        
        mappingOperation.addDependency(networkOperation)
        regionMappingOperation.addDependency(networkOperation)
        networkOperation.addDependency(serializingOperation)
        serializingOperation.addDependency(bluetoothStatusOperation)
        
        operationQueue.addOperation(bluetoothStatusOperation)
        operationQueue.addOperation(serializingOperation)
        operationQueue.addOperation(networkOperation)
        operationQueue.addOperation(mappingOperation)
        operationQueue.addOperation(regionMappingOperation)
    }
    
}

extension Rover : CLLocationManagerDelegate {
    public func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        rvLog("Location manager auth status changed = \(status)")
    }
    
    public func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region is CLBeaconRegion {
            didEnterBeaconRegion(region as! CLBeaconRegion)
        } else {
            didEnterCircularRegion(region as! CLCircularRegion)
        }
    }
    
    public func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region is CLBeaconRegion {
            didExitBeaconRegion(region as! CLBeaconRegion)
        } else {
            didExitCircularRegion(region as! CLCircularRegion)
        }
    }
    
    func didEnterBeaconRegion(region: CLBeaconRegion) {
        sendEvent(.DidEnterBeaconRegion(region, config: nil, date: NSDate()))
    }
    
    func didEnterCircularRegion(region: CLCircularRegion) {
        sendEvent(.DidEnterCircularRegion(region, location: nil, date: NSDate()))
    }
    
    func didExitBeaconRegion(region: CLBeaconRegion) {
        sendEvent(.DidExitBeaconRegion(region, config: nil, date: NSDate()))
    }
    
    func didExitCircularRegion(region: CLCircularRegion) {
        sendEvent(.DidExitCircularRegion(region, location: nil, date: NSDate()))
    }
    
    public func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations[0]
        let date = NSDate()
        sendEvent(.DidUpdateLocation(location, date: date))
    }
}

enum Router {
    case Events
    
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
        }
    }
    
    var urlRequest: NSMutableURLRequest {
        let urlRequest = NSMutableURLRequest(URL: self.url)
        urlRequest.HTTPMethod = self.method
        urlRequest.setValue(Rover.sharedInstance?.applicationToken, forHTTPHeaderField: "X-Rover-Api-Key")
        return urlRequest
    }
}



