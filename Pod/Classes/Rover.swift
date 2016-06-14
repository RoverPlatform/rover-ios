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
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Rover.applicationDidOpen), name: UIApplicationDidFinishLaunchingNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Rover.applicationDidOpen), name: UIApplicationWillEnterForegroundNotification, object: nil)
        
        locationManager.delegate = self
    }
    
    // MARK: Class Methods
    
    public static let customer = Customer.sharedCustomer
    
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
        sharedInstance?.observers.removeAtIndex((sharedInstance!.observers.indexOf({$0 === observer})!))
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
        switch message.action {
        case .Link:
            if let url = message.url {
                sharedInstance?.presentSafariViewController(url: url)
            }
        case .LandingPage:
            if let screen = message.landingPage {
                let viewController = RVScreenViewController(screen: screen)
                Rover.presentViewController(viewController)
            }
        default:
            break
        }
        sharedInstance?.sendEvent(.DidOpenMessage(message, source: "inbox", date: NSDate()))
    }
    
    public class func followAction(action: Action, url: NSURL?) {

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
        guard let data = userInfo["data"] as? [String: AnyObject],
            let messageId = data["message-id"] as? String else { return }
        
        let mappingOperation = MappingOperation { (message: Message) in
            dispatch_async(dispatch_get_main_queue()) {
                sharedInstance?.notifyObservers(event: .DidReceiveMessage(message))
                
                if UIApplication.sharedApplication().applicationState != .Active {
                    // Swiped
                    followAction(message.action, url: message.url)
                    sharedInstance?.sendEvent(.DidOpenMessage(message, source: "notification", date: NSDate()))
                } else {
                    
                }
            }
        }
        
        mappingOperation.completionBlock = {
            completionHandler(.NoData)
        }
        
        let networkOperation = NetworkOperation(urlRequest: Router.GetMessage(messageId).urlRequest) {
            [unowned mappingOperation]
            (JSON, error) in
            
            if let JSON = JSON {
                mappingOperation.json = JSON
            }
        }
        
        mappingOperation.addDependency(networkOperation)
        
        sharedInstance?.operationQueue.addOperation(networkOperation)
        sharedInstance?.operationQueue.addOperation(mappingOperation)
    }
    
    // MARK: Instance Methods
    
    func notifyObservers(event event: Event) {
        for observer in observers {
            event.call(observer)
        }
    }
    
    func presentSafariViewController(url url: NSURL) {
        if #available(iOS 9.0, *) {
            let viewController = SFSafariViewController(URL: url)
        
            Rover.presentViewController(viewController)
        } else {
            // Fallback on earlier versions
            UIApplication.sharedApplication().openURL(url)
        }
    }
    
    public class func presentViewController(viewController: UIViewController) {
        var frame = UIScreen.mainScreen().bounds
        if UIDeviceOrientationIsLandscape(UIDevice.currentDevice().orientation) {
            frame = CGRect(x: 0, y: 0, width: frame.height, height: frame.width)
        }
        
        let navController = ModalViewController(rootViewController: viewController)
        navController.modalDelegate = sharedInstance
        
        sharedInstance?.window = UIWindow(frame: frame)
        sharedInstance?.window?.hidden = false
        sharedInstance?.window?.rootViewController = UIViewController()
        sharedInstance?.window?.rootViewController?.presentViewController(navController, animated: true, completion: nil)
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

extension Rover : ModalViewControllerDelegate {
    func didDismissModalViewController(viewController: ModalViewController) {
        window?.rootViewController = nil
        window = nil
    }
}

extension Rover : LocationManagerDelegate {
    
    func locationManager(manager: LocatioManager, didEnterRegion region: CLRegion) {
        if region is CLBeaconRegion {
            sendEvent(.DidEnterBeaconRegion(region as! CLBeaconRegion, config: nil, place: nil, date: NSDate()))
        } else {
            sendEvent(.DidEnterCircularRegion(region as! CLCircularRegion, place: nil, date: NSDate()))
        }
    }
    
    func locationManager(manager: LocatioManager, didExitRegion region: CLRegion) {
        if region is CLBeaconRegion {
            sendEvent(.DidExitBeaconRegion(region as! CLBeaconRegion, config: nil, place: nil, date: NSDate()))
        } else {
            sendEvent(.DidExitCircularRegion(region as! CLCircularRegion, place: nil, date: NSDate()))
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
}
