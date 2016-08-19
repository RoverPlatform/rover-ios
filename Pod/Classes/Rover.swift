//
//  Rover.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-25.
//
//

import Foundation
import CoreLocation

@objc
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
    var gimbalMode = false
    
    private var locationManager: LocatioManager?
    private var gimbalPlaceManager: RVRGimbalPlaceManager?
    
    private let operationQueue = NSOperationQueue()
    private let eventOperationQueue = NSOperationQueue()
    
    private var window: UIWindow?
    
    private override init () {
        super.init()
        
        eventOperationQueue.maxConcurrentOperationCount = 1
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Rover.applicationDidOpen(_:)), name: UIApplicationDidFinishLaunchingNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Rover.applicationDidOpen(_:)), name: UIApplicationWillEnterForegroundNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Rover.applicationDidBecomeActive(_:)), name: UIApplicationDidBecomeActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Rover.applicationDidEnterBackground(_:)), name: UIApplicationDidEnterBackgroundNotification, object: nil)
        
        ExperienceViewController.superDelegate = self
    }
    
    // MARK: Class Methods
    
    public static let customer = Customer.sharedCustomer
    
    public static var isMonitoring: Bool {
        return sharedInstance?.locationManager?.isMonitoring ?? false
    }
    
    public class func setup(applicationToken applicationToken: String) {
        let gimbalClass = NSClassFromString("GMBLPlaceManager")
        setup(applicationToken: applicationToken, gimbalMode: gimbalClass != nil)
    }
    
    private class func setup(applicationToken applicationToken: String, gimbalMode: Bool) {
        _sharedInstance.applicationToken = applicationToken
        _sharedInstance.gimbalMode = gimbalMode
        
        if gimbalMode {
            _sharedInstance.gimbalPlaceManager = RVRGimbalPlaceManager()
            _sharedInstance.gimbalPlaceManager?.delegate = _sharedInstance
        } else {
            _sharedInstance.locationManager = LocatioManager()
            _sharedInstance.locationManager?.delegate = _sharedInstance
        }
    }
    
    public class func startMonitoring() {
        guard !_sharedInstance.gimbalMode else {
            rvLog("Use GMBLPlaceManager.startMonitoring() when in Gimbal mode.", data: nil, level: .Error)
            return
        }
        
        let locationAuthorizationOperation = LocationAuthorizationOperation()
        locationAuthorizationOperation.completionBlock = {
            if CLLocationManager.authorizationStatus() == .AuthorizedAlways {
                sharedInstance?.locationManager?.startMonitoring()
            } else {
                rvLog("Location permissions not granted", level: .Warn)
            }
        }
        sharedInstance?.operationQueue.addOperation(locationAuthorizationOperation)
    }
    
    public class func stopMonitoring() {
        guard !_sharedInstance.gimbalMode else {
            rvLog("Use GMBLPlaceManager.stopMonitoring() when in Gimbal mode", data: nil, level: .Error)
            return
        }
        
        sharedInstance?.locationManager?.stopMonitoring()
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
    
    public class func reloadInbox(completion: (([Message], Int) -> Void)?) {
        var unreadMessagesCount: Int = 0
        
        let mappingOperation = MappingOperation { (messages: [Message]) in
            dispatch_async(dispatch_get_main_queue()) {
                completion?(messages, unreadMessagesCount)
            }
        }
        let networkOperation = NetworkOperation(mutableUrlRequest: Router.Inbox.urlRequest) { JSON, error in
            if let meta = JSON?["meta"] as? [String: AnyObject] {
                unreadMessagesCount = meta["unread-messages-count"] as? Int ?? 0
            }
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
    
    public class func trackMessageOpenEvent(message: Message) {
        sharedInstance?.sendEvent(.DidOpenMessage(message, source: "inbox", date: NSDate()))
    }
    
    public class func updateLocation(location: CLLocation) {
        sharedInstance?.sendEvent(.DidUpdateLocation(location, date: NSDate()))
    }
    
    public class func followAction(message message: Message) {
        switch message.action {
        case .Website:
            fallthrough
        case .DeepLink:
            if let url = message.url {
                UIApplication.sharedApplication().openURL(url)
            }
        case .LandingPage:
            if let viewController = viewController(message: message) {
                presentViewController(viewController)
            }
        case .Experience:
            if let viewController = viewController(message: message) as? ExperienceViewController {
                viewController.modalDelegate = sharedInstance
                presentViewController(viewController, includeNavigation: false)
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
    
    public class func didReceiveRemoteNotification(userInfo: [NSObject: AnyObject], fetchCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?) -> Bool {
        return didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler, fromLaunch: false)
    }
    
    private class func didReceiveRemoteNotification(userInfo: [NSObject: AnyObject], fetchCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?, fromLaunch fromLaunch: Bool) -> Bool {
        guard let data = userInfo["data"] as? [String: AnyObject], isRover = userInfo["_rover"] as? Bool where isRover else { return false }
        
        let mappingOperation = MappingOperation { (message: Message) in
            
            dispatch_async(dispatch_get_main_queue()) {
                
                if (!fromLaunch) {
                    sharedInstance?.notifyObservers(event: .DidReceiveMessage(message))
                }
                
                guard let sharedInstance = sharedInstance else { return }
                
                var shouldMethodImplemented = false
                var shouldOpen: Bool = true
                
                for observer in sharedInstance.observers {
                    if let shouldMethod = observer.shouldOpenMessage {
                        shouldMethodImplemented = true
                        shouldOpen = shouldOpen && shouldMethod(message)
                    }
                }
                
                if ((!sharedInstance.applicationIsActive || fromLaunch) && shouldOpen) || (shouldMethodImplemented && shouldOpen) {
                    message.read = true
                    patchMessage(message)
                    followAction(message: message)
                    sharedInstance.sendEvent(.DidOpenMessage(message, source: "notification", date: NSDate()))
                }
            }
        }
        
        mappingOperation.json = ["data": data]
        mappingOperation.completionBlock = {
            completionHandler?(.NoData)
        }
        
        sharedInstance?.operationQueue.addOperation(mappingOperation)
        
        return true
    }
    
    // MARK: Instance Methods
    
    func notifyObservers(event event: Event) {
        for observer in observers {
            event.call(observer)
        }
    }
    
    public class func presentViewController(viewController: UIViewController) {
        presentViewController(viewController, includeNavigation: true)
    }
    
    private class func presentViewController(viewController: UIViewController, includeNavigation includeNav: Bool) {
        var frame = UIScreen.mainScreen().bounds
        if UIDeviceOrientationIsLandscape(UIDevice.currentDevice().orientation) {
            frame = CGRect(x: 0, y: 0, width: frame.height, height: frame.width)
        }
        
        sharedInstance?.window = UIWindow(frame: frame)
        sharedInstance?.window?.hidden = false
        sharedInstance?.window?.rootViewController = UIViewController()
        
        if includeNav {
            let navController = ModalViewController(rootViewController: viewController)
            navController.modalDelegate = sharedInstance
            sharedInstance?.window?.rootViewController?.presentViewController(navController, animated: true, completion: nil)
        } else {
            sharedInstance?.window?.rootViewController?.presentViewController(viewController, animated: true, completion: nil)
        }
    }
    
    public class func viewController(message message: Message) -> UIViewController? {
        switch message.action {
        case .LandingPage:
            let viewController = ScreenViewController()
            
            if let screen = message.landingPage {
                viewController.screen = screen
            } else {
                //viewController.showActivityIndicator()
                
                let mappingOperation = MappingOperation() { (screen: Screen) in
                    message.landingPage = screen
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        viewController.screen = screen
                    }
                }
                
                mappingOperation.completionBlock = {
                    //viewController.hideActivityIndicator()
                }
                
                let networkOperation = NetworkOperation(urlRequest: Router.GetLandingPage(message).urlRequest) {
                    [unowned mappingOperation]
                    (JSON, error) in
                    
                    if let JSON = JSON { mappingOperation.json = ["data": JSON] }
                }
                
                mappingOperation.addDependency(networkOperation)
                
                sharedInstance?.operationQueue.addOperation(networkOperation)
                sharedInstance?.operationQueue.addOperation(mappingOperation)
            }
            
            return viewController
        case .Experience:
            guard let experienceId = message.experienceId else { return nil }
            return ExperienceViewController(identifier: experienceId)
        default:
            return nil
        }
    }
    
    // MARK: UIApplicationNotifications
    
    func applicationDidOpen(note: NSNotification) {
        if let userInfo = note.userInfo?[UIApplicationLaunchOptionsRemoteNotificationKey] as? [NSObject: AnyObject] {
            Rover.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: nil, fromLaunch: true)
        }
        self.sendEvent(.ApplicationOpen(date: NSDate()))
    }
    
    var applicationIsActive = false
    
    func applicationDidEnterBackground(note: NSNotification) {
        applicationIsActive = false
    }
    
    func applicationDidBecomeActive(note: NSNotification) {
        applicationIsActive = true
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

extension Rover : EventOperationDelegate {
    
    func eventOperation(operation: EventOperation, didPostEvent event: Event) {
        self.notifyObservers(event: event)
    }
    
    func eventOperation(operation: EventOperation, didReceiveRegions regions: [CLRegion]) {
        self.locationManager?.monitoredRegions = Set(regions)
    }
}

extension Rover /*: RVRGimbalPlaceManagerDelegate*/ {
    
    public func placeManager(manager: RVRGimbalPlaceManager!, didUpdateLocation location: CLLocation!) {
        sendEvent(.DidUpdateLocation(location, date: NSDate()))
    }
    
    public func placeManager(manager: RVRGimbalPlaceManager!, didEnterGimbalPlaceWithIdentifier identifier: String!) {
        sendEvent(.DidEnterGimbalPlace(id: identifier, date: NSDate()))
    }
    
    public func placeManager(manager: RVRGimbalPlaceManager!, didExitGimbalPlaceWithIdentifier identifier: String!) {
        sendEvent(.DidExitGimbalPlace(id: identifier, date: NSDate()))
    }
}

extension Rover: ExperienceViewControllerDelegate {
    func experienceViewControllerDidLaunch(viewController: ExperienceViewController) {
        guard let experience = viewController.experience else { return }
        sendEvent(.DidLaunchExperience(experience, date: NSDate()))
    }
    
    func experienceViewControllerDidDismiss(viewController: ExperienceViewController) {
        guard let experience = viewController.experience else { return }
        sendEvent(.DidDismissExperience(experience, date: NSDate()))
    }
    
    func experienceViewController(viewController: ExperienceViewController, didViewScreen screen: Screen, referrerScreen: Screen?, referrerBlock: Block?) {
        guard let experience = viewController.experience else { return }
        sendEvent(.DidViewScreen(screen, experience: experience, fromScreen: referrerScreen, fromBlock: referrerBlock, date: NSDate()))
    }
    
    func experienceViewController(viewController: ExperienceViewController, didPressBlock block: Block, screen: Screen) {
        guard let experience = viewController.experience else { return }
        sendEvent(.DidPressBlock(block, screen: screen, experience: experience, date: NSDate()))
    }
}
