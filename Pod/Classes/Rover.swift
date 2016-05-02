//
//  Rover.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-25.
//
//

import Foundation
import CoreLocation
import SafariServices

public class Rover : NSObject {
    
    private static let _sharedInstance = Rover()
    static var sharedInstance: Rover? {
        guard _sharedInstance.applicationToken != nil else {
            rvLog("Rover accessed before setup", level: .Error)
            return nil
        }
        return _sharedInstance
    }
    
    var applicationToken: String?
    
    private let locationManager = LocatioManager()
    
    private let operationQueue = NSOperationQueue()
    private let eventOperationQueue = NSOperationQueue()
    
    private var window: UIWindow?
    
    private override init () {
        super.init()
        
        eventOperationQueue.maxConcurrentOperationCount = 1
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Rover.applicationDidfinishLaunching(_:)), name: UIApplicationDidFinishLaunchingNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Rover.applicationDidOpen), name: UIApplicationDidFinishLaunchingNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Rover.applicationDidOpen), name: UIApplicationWillEnterForegroundNotification, object: nil)
        
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
                sharedInstance?.locationManager.startMonitoring()
            } else {
                rvLog("Location permissions not granted", level: .Warn)
            }
        }
        sharedInstance?.operationQueue.addOperation(locationAuthorizationOperation)
    }
    
    public class func stopMonitoring() {
        sharedInstance?.locationManager.stopMonitoring()
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
    
    public class func followMessageAction(message: Message) {
        followAction(message.action, url: message.url)
        sharedInstance?.sendEvent(.DidOpenMessage(identifier: message.identifier, source: "inbox", date: NSDate()))
    }
    
    public class func followAction(action: Action, url: NSURL?) {
        switch action {
        case .Link:
            if let url = url {
                sharedInstance?.presentSafariViewController(url: url)
            }
        default:
            break
        }
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
    
    
    
    public class func didReceiveRemoteNotification(userInfo: [NSObject: AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        guard UIApplication.sharedApplication().applicationState != .Active,
            let data = userInfo["data"] as? [String: AnyObject] else { return }
        
        let mappingOperation = MappingOperation { (message: Message) in
            Rover.followAction(message.action, url: message.url)
            sharedInstance?.sendEvent(.DidOpenMessage(identifier: message.identifier, source: "notification", date: NSDate()))
        }
        mappingOperation.completionBlock = { completionHandler(.NoData) }
        mappingOperation.json = ["data" : data]
        mappingOperation.start()
    }
    
    public class func didReceiveLocalNotification(notification: UILocalNotification) {
        guard UIApplication.sharedApplication().applicationState != .Active,
            let messageId = notification.userInfo?["message-id"] as? String,
            let messageActionInt = notification.userInfo?["action"] as? Int,
            let messageAction = Action(rawValue: messageActionInt),
            let messageUrlString = notification.userInfo?["url"] as? String? else { return }
        
        if let urlString = messageUrlString {
            followAction(messageAction, url: NSURL(string: urlString))
        }
        
        sharedInstance?.sendEvent(.DidOpenMessage(identifier: messageId, source: "notification", date: NSDate()))
    }
    
    // MARK: Instance Methods
    
    func notifyObservers(event event: Event) {
        for observer in observers {
            event.call(observer)
        }
    }
    
    func deliverMessage(message: Message) {
        for observer in observers {
            observer.willDeliverMessage?(message)
        }
        
        if UIApplication.sharedApplication().applicationState == .Background {
            let notification = UILocalNotification()
            notification.alertBody = message.text
            notification.alertTitle = message.title
            notification.userInfo = [
                "message-id" : message.identifier,
                "action": message.action.rawValue
            ]
            if let url = message.url {
                notification.userInfo?["url"] = url.absoluteString
            }
            UIApplication.sharedApplication().presentLocalNotificationNow(notification)
        }
    
        for observer in observers {
            observer.didDeliverMessage?(message)
        }
    }
    
    func presentSafariViewController(url url: NSURL) {
        if #available(iOS 9.0, *) {
            let viewController = SFSafariViewController(URL: url)
            viewController.delegate = self
            
            var frame = UIScreen.mainScreen().bounds
            if UIDeviceOrientationIsLandscape(UIDevice.currentDevice().orientation) {
                frame = CGRect(x: 0, y: 0, width: frame.height, height: frame.width)
            }
            
            window = UIWindow(frame: frame)
            window?.hidden = false
            window?.rootViewController = UIViewController()
            window?.rootViewController?.presentViewController(viewController, animated: true, completion: nil)
        } else {
            // Fallback on earlier versions
            UIApplication.sharedApplication().openURL(url)
        }
    }
    
    // MARK: UIApplicationNotifications
    
    func applicationDidOpen() {
        sendEvent(.ApplicationOpen(date: NSDate()))
    }
    
    func applicationDidfinishLaunching(note: NSNotification) {
        if let localNotificaiton = note.userInfo?[UIApplicationLaunchOptionsLocalNotificationKey] as? UILocalNotification {
            Rover.didReceiveLocalNotification(localNotificaiton)
        }
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
            sendEvent(.DidEnterBeaconRegion(region as! CLBeaconRegion, config: nil, location: nil, date: NSDate()))
        } else {
            sendEvent(.DidEnterCircularRegion(region as! CLCircularRegion, location: nil, date: NSDate()))
        }
    }
    
    func locationManager(manager: LocatioManager, didExitRegion region: CLRegion) {
        if region is CLBeaconRegion {
            sendEvent(.DidExitBeaconRegion(region as! CLBeaconRegion, config: nil, location: nil, date: NSDate()))
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
        self.locationManager.monitoredRegions = Set(regions)
    }
    
    func eventOperation(operation: EventOperation, didReceiveMessages messages: [Message]) {
        for message in messages {
            deliverMessage(message)
        }
    }
}

extension Rover : SFSafariViewControllerDelegate {
    @available(iOS 9.0, *)
    public func safariViewControllerDidFinish(controller: SFSafariViewController) {
        window?.rootViewController = nil
        window = nil
    }
}
