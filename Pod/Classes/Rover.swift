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
    
    //private let locationManager = CLLocationManager()
    private let locationManager = LocatioManager()
    private var regions: [CLRegion] = []
    
    private let operationQueue = NSOperationQueue()
    private let eventOperationQueue = NSOperationQueue()
    
    private override init () {
        super.init()
        
        eventOperationQueue.maxConcurrentOperationCount = 1
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidOpen", name: UIApplicationDidFinishLaunchingNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidOpen", name: UIApplicationWillEnterForegroundNotification, object: nil)
        
        locationManager.delegate = self
        
        // TEMP BEGIN
        
        let userNotificationSettings = UIUserNotificationSettings(forTypes: [.Alert, .Sound, .Badge], categories: nil)
        UIApplication.sharedApplication().registerUserNotificationSettings(userNotificationSettings)
        
        // TEMP END
    }
    
    // MARK: Class Methods
    
    public static let customer = User.sharedUser
    
    public static var isMonitoring: Bool {
        return sharedInstance?.locationManager.isMonitoring ?? false
    }
    
    public class func setup(applicationToken applicationToken: String) {
        _sharedInstance.applicationToken = applicationToken
        
    }
    
    public class func startMonitoring() {
        let locationAuthorizationOperation = LocationAuthorizationOperation()
        locationAuthorizationOperation.completionBlock = {
            if CLLocationManager.authorizationStatus() == .AuthorizedAlways {
                sharedInstance?.startRegionMonitoring()
                sharedInstance?.locationManager.startMonitoringSignificantLocationChanges()
            } else {
                rvLog("Location permissions not granted")
            }
        }
        sharedInstance?.operationQueue.addOperation(locationAuthorizationOperation)
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
    
//    public class func simulateBeaconEnter(UUID UUID: NSUUID, major: CLBeaconMajorValue, minor: CLBeaconMinorValue) {
//        let region = CLBeaconRegion(proximityUUID: UUID, major: major, minor: minor, identifier: "SIMULATE")
//        sharedInstance?.didEnterBeaconRegion(region)
//    }
//    
//    public class func simulateBeaconExit(UUID UUID: NSUUID, major: CLBeaconMajorValue, minor: CLBeaconMinorValue) {
//        let region = CLBeaconRegion(proximityUUID: UUID, major: major, minor: minor, identifier: "SIMULATE")
//        sharedInstance?.didExitBeaconRegion(region)
//    }
    
    public class func simulateEvent(event: Event) {
        sharedInstance?.sendEvent(event)
    }
    
    public class func reloadInbox(completion: ([Message] -> Void)?) {
        let mappingOperation = MappingOperation { (messages: [Message]) in
            dispatch_async(dispatch_get_main_queue()) {
                completion?(messages)
            }
        }
        let networkOperation = NetworkOperation(mutableUrlRequest: Router.Inbox.urlRequest) { JSON, error in
            mappingOperation.json = JSON
        }
        
        mappingOperation.addDependency(networkOperation)
        
        sharedInstance?.operationQueue.addOperation(networkOperation)
        sharedInstance?.operationQueue.addOperation(mappingOperation)
    }
    
    public class func deleteMessage(message: Message) {
        let networkOperation = NetworkOperation(urlRequest: Router.DeleteMessage(message).urlRequest, completion: nil)
        sharedInstance?.operationQueue.addOperation(networkOperation)
    }
    
    public class func patchMessage(message: Message) {
        let networkOperation = NetworkOperation(urlRequest: Router.PatchMessage(message).urlRequest, completion: nil)
        let serializingOperation = SerializingOperation(model: message) { JSON in
            networkOperation.payload = JSON
        }
        
        networkOperation.addDependency(serializingOperation)
        
        sharedInstance?.operationQueue.addOperation(serializingOperation)
        sharedInstance?.operationQueue.addOperation(networkOperation)
    }
    
    public class func updateLocation(location: CLLocation) {
        sharedInstance?.sendEvent(.DidUpdateLocation(location, date: NSDate()))
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
    
    func deliverMessages(messages: [Message]) {
        messages.forEach { message in
            
            for observer in observers {
                observer.willDeliverMessage?(message)
            }
            
            let notification = UILocalNotification()
            notification.alertBody = message.text
            UIApplication.sharedApplication().presentLocalNotificationNow(notification)
        
            for observer in observers {
                observer.didDeliverMessage?(message)
            }
        }
    }
    
    // MARK: UIApplicationNotifications
    
    func applicationDidOpen() {
        sendEvent(.ApplicationOpen(date: NSDate()))
    }
    
    func sendEvent(event: Event) {
        let eventOperation = EventOperation(event: event)
        eventOperation.delegate = self
        
        eventOperationQueue.addOperation(eventOperation)
    }
}

extension Rover : LocationManagerDelegate {
    
    func locationManager(manager: LocatioManager, didEnterRegion region: CLRegion) {
        if region is CLBeaconRegion {
            sendEvent(.DidEnterBeaconRegion(region as! CLBeaconRegion, config: nil, date: NSDate()))
        } else {
            sendEvent(.DidEnterCircularRegion(region as! CLCircularRegion, location: nil, date: NSDate()))
        }
    }
    
    func locationManager(manager: LocatioManager, didExitRegion region: CLRegion) {
        if region is CLBeaconRegion {
            sendEvent(.DidExitBeaconRegion(region as! CLBeaconRegion, config: nil, date: NSDate()))
        } else {
            sendEvent(.DidExitCircularRegion(region as! CLCircularRegion, location: nil, date: NSDate()))
        }
    }
    
    func locationManager(manager: LocatioManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations[0]
        let date = NSDate()
        sendEvent(.DidUpdateLocation(location, date: date))
    }
}

extension Rover: EventOperationDelegate {
    
    func eventOperation(operation: EventOperation, didPostEvent event: Event) {
        self.notifyObservers(event: event)
    }
    
    func eventOperation(operation: EventOperation, didReceiveRegions regions: [CLRegion]) {
        self.regions = regions
        //if locationManager.monitoredRegions.count > 0 { // isMonitoring
        self.stopRegionMonitoring()
        self.startRegionMonitoring()
    }
    
    func eventOperation(operation: EventOperation, didReceiveMessages messages: [Message]) {
        self.deliverMessages(messages)
    }
}

enum Router {
    case Events
    case Inbox
    case DeleteMessage(Message)
    case PatchMessage(Message)
    
    var method: String {
        switch self {
        case .Events:
            return "POST"
        case .DeleteMessage(_):
            return "DELETE"
        case .PatchMessage(_):
            return "PATCH"
        default:
            return "GET"
        }
    }
    
    var baseURLString: String {
        return "https://api.staging.rover.io/v1"
    }
    
    var url: NSURL {
        switch self {
        case .Events:
            return NSURL(string: "\(baseURLString)/events")!
        case .Inbox:
            return NSURL(string: "\(baseURLString)/inbox")!
        case .DeleteMessage(let message):
            return NSURL(string: "\(baseURLString)/inbox/messages/\(message.identifier)")!
        case .PatchMessage(let message):
            return NSURL(string: "\(baseURLString)/inbox/messages/\(message.identifier)")!
        }
    }
    
    var urlRequest: NSMutableURLRequest {
        let urlRequest = NSMutableURLRequest(URL: self.url)
        urlRequest.HTTPMethod = self.method
        urlRequest.setValue(Rover.sharedInstance?.applicationToken, forHTTPHeaderField: "X-Rover-Api-Key")
        urlRequest.setValue(UIDevice.currentDevice().identifierForVendor?.UUIDString ?? "[UNKNOWN]", forHTTPHeaderField: "X-Rover-Device-Id")
        return urlRequest
    }
}
