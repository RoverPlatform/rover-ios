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
open class Rover : NSObject {
    
    fileprivate static let _sharedInstance = Rover()
    static var sharedInstance: Rover? {
        guard _sharedInstance.applicationToken != nil else {
            rvLog("Rover accessed before setup", level: .error)
            return nil
        }
        return _sharedInstance
    }
    
    var applicationToken: String?
    var gimbalMode = false
    
    fileprivate var locationManager: LocatioManager?
    fileprivate var gimbalPlaceManager: RVRGimbalPlaceManager?
    
    fileprivate let operationQueue = OperationQueue()
    fileprivate let eventOperationQueue = OperationQueue()
    
    fileprivate var window: UIWindow?
    
    fileprivate override init () {
        super.init()
        
        eventOperationQueue.maxConcurrentOperationCount = 1
        
        NotificationCenter.default.addObserver(self, selector: #selector(Rover.applicationDidOpen(_:)), name: NSNotification.Name.UIApplicationDidFinishLaunching, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(Rover.applicationDidOpen(_:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(Rover.applicationDidBecomeActive(_:)), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(Rover.applicationDidEnterBackground(_:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        
        ExperienceViewController.superDelegate = self
    }
    
    // MARK: Class Methods
    
    open static let customer = Customer.sharedCustomer
    
    open static func identify(traits: Traits) {
        if let identifier = traits.identifier {
            customer.identifier = identifier as? String
        }
        
        if let firstName = traits.firstName {
            customer.firstName = firstName as? String
        }
        
        if let lastName = traits.lastName {
            customer.lastName = lastName as? String
        }
        
        if let email = traits.email {
            customer.email = email as? String
        }
        
        if let phoneNumber = traits.phoneNumber {
            customer.phone = phoneNumber as? String
        }
        
        if let tags = traits.tags {
            customer.tags = tags
        } else {
            if let tagsToAdd = traits.tagsToAdd {
                customer.tags?.append(contentsOf: tagsToAdd)
            }
            
            if let tagsToRemove = traits.tagsToRemove {
                customer.tags = customer.tags?.filter { !tagsToRemove.contains($0) }
            }
        }
        
        if let gender = traits.gender {
            customer.gender = gender as? String
        }
        
        if let age = traits.age {
            customer.age = age as? Int
        }
        
        if let customValues = traits.customValues {
            customer.traits = [String: Any]()
            for (key, value) in customValues.filter({ !($0.1 is NSNull) }) {
                customer.traits[key] = value
            }
        }
        
        customer.save()
        sharedInstance?.sendEvent(.deviceUpdate(date: Date()))
    }
    
    open static func clearCustomer() {
        customer.identifier = nil
        customer.firstName = nil
        customer.lastName = nil
        customer.email = nil
        customer.phone = nil
        customer.tags = nil
        customer.gender = nil
        customer.age = nil
        customer.traits = [String: Any]()

        customer.save()
        sharedInstance?.sendEvent(.deviceUpdate(date: Date()))
    }
    
    open static var isMonitoring: Bool {
        return sharedInstance?.locationManager?.isMonitoring ?? false
    }
    
    open static var isDevelopment = false
    
    open class func setup(applicationToken: String) {
        let gimbalClass = NSClassFromString("GMBLPlaceManager")
        setup(applicationToken: applicationToken, gimbalMode: gimbalClass != nil)
    }
    
    fileprivate class func setup(applicationToken: String, gimbalMode: Bool) {
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
    
    open class func startMonitoring() {
        guard !_sharedInstance.gimbalMode else {
            rvLog("Use GMBLPlaceManager.startMonitoring() when in Gimbal mode.", data: nil, level: .error)
            return
        }
        
        let locationAuthorizationOperation = LocationAuthorizationOperation()
        locationAuthorizationOperation.completionBlock = {
            if CLLocationManager.authorizationStatus() == .authorizedAlways {
                sharedInstance?.locationManager?.startMonitoring()
            } else {
                rvLog("Location permissions not granted", level: .warn)
            }
        }
        sharedInstance?.operationQueue.addOperation(locationAuthorizationOperation)
    }
    
    open class func stopMonitoring() {
        guard !_sharedInstance.gimbalMode else {
            rvLog("Use GMBLPlaceManager.stopMonitoring() when in Gimbal mode", data: nil, level: .error)
            return
        }
        
        sharedInstance?.locationManager?.stopMonitoring()
    }
    
    open class func registerForNotifications() {
        UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil))
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    fileprivate(set) var observers = [RoverObserver]()
    
    open class func addObserver(_ observer: RoverObserver) {
        sharedInstance?.observers.append(observer)
    }
    
    open class func removeObserver(_ observer: RoverObserver) {
        sharedInstance?.observers.remove(at: (sharedInstance!.observers.index(where: {$0 === observer})!))
    }
    
    open class func simulateEvent(_ event: Event) {
        sharedInstance?.sendEvent(event)
    }
    
    open class func reloadInbox(_ completion: (([Message], Int) -> Void)?) {
        var unreadMessagesCount: Int = 0
        
        let mappingOperation = MappingOperation { (messages: [Message]) in
            DispatchQueue.main.async {
                completion?(messages, unreadMessagesCount)
            }
        }
        let networkOperation = NetworkOperation(urlRequest: Router.inbox.urlRequest) { JSON, error in
            if let meta = JSON?["meta"] as? [String: AnyObject] {
                unreadMessagesCount = meta["unread-messages-count"] as? Int ?? 0
            }
            mappingOperation.json = JSON
        }
        
        mappingOperation.addDependency(networkOperation)
        
        sharedInstance?.operationQueue.addOperation(networkOperation)
        sharedInstance?.operationQueue.addOperation(mappingOperation)
    }
    
    open class func deleteMessage(_ message: Message) {
        let networkOperation = NetworkOperation(urlRequest: Router.deleteMessage(message).urlRequest as URLRequest, completion: nil)
        sharedInstance?.operationQueue.addOperation(networkOperation)
    }
    
    open class func patchMessage(_ message: Message) {
        let networkOperation = NetworkOperation(urlRequest: Router.patchMessage(message).urlRequest as URLRequest, completion: nil)
        let serializingOperation = SerializingOperation(model: message) { JSON in
            networkOperation.payload = JSON
        }
        
        networkOperation.addDependency(serializingOperation)
        
        sharedInstance?.operationQueue.addOperation(serializingOperation)
        sharedInstance?.operationQueue.addOperation(networkOperation)
    }
    
    open class func trackMessageOpenEvent(_ message: Message) {
        sharedInstance?.sendEvent(.didOpenMessage(message, source: "inbox", date: Date()))
    }
    
    open class func updateLocation(_ location: CLLocation) {
        sharedInstance?.sendEvent(.didUpdateLocation(location, date: Date()))
    }
    
    open class func followAction(message: Message) {
        switch message.action {
        case .website:
            fallthrough
        case .deepLink:
            if let url = message.url {
                UIApplication.shared.openURL(url as URL)
            }
        case .landingPage:
            if let viewController = viewController(message: message) {
                presentViewController(viewController)
            }
        case .experience:
            if let viewController = viewController(message: message) as? ExperienceViewController {
                viewController.modalDelegate = sharedInstance
                presentViewController(viewController, includeNavigation: false)
            }
        default:
            break
        }
    }
    
    open class func continueUserActivity(_ userActivity: NSUserActivity) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb, let webpageURL = userActivity.webpageURL else {
            return false
        }
        
        return open(url: webpageURL)
    }
    
    open class func open(url: URL) -> Bool {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false), let host = urlComponents.host else {
            return false
        }
        
        let hostComponents = host.components(separatedBy: ".")
        
        guard hostComponents.count == 3, hostComponents[1].lowercased() == "rvr", hostComponents[2].lowercased() == "co" else {
            return false
        }
        
        let pathComponents = urlComponents.path.components(separatedBy: "/")
        
        guard pathComponents.count > 1 else {
            return false
        }
        
        let experienceId = pathComponents[1]
        
        guard !experienceId.isEmpty else {
            return false
        }
        
        let viewController = ExperienceViewController(identifier: experienceId)
        viewController.modalDelegate = sharedInstance
        presentViewController(viewController, includeNavigation: false)
        
        return true
    }
    
    // MARK: Application Hooks
    
    open class func didRegisterForRemoteNotification(deviceToken: Data) {
        let deviceTokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        guard Device.pushToken != deviceTokenString else {
            return
        }
        
        Device.pushToken = deviceTokenString
        
        sharedInstance?.sendEvent(Event.deviceUpdate(date: Date()))
    }
    
    open class func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?) -> Bool {
        return didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler, fromLaunch: false)
    }
    
    fileprivate class func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?, fromLaunch: Bool) -> Bool {
        guard let data = userInfo["data"] as? [String: AnyObject], let isRover = userInfo["_rover"] as? Bool , isRover else { return false }
        
        let mappingOperation = MappingOperation { (message: Message) in
            
            DispatchQueue.main.async {
                
                if (!fromLaunch) {
                    sharedInstance?.notifyObservers(event: .didReceiveMessage(message))
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
                    sharedInstance.sendEvent(.didOpenMessage(message, source: "notification", date: Date()))
                }
            }
        }
        
        mappingOperation.json = ["data": data as AnyObject]
        mappingOperation.completionBlock = {
            completionHandler?(.noData)
        }
        
        sharedInstance?.operationQueue.addOperation(mappingOperation)
        
        return true
    }
    
    // MARK: Instance Methods
    
    func notifyObservers(event: Event) {
        for observer in observers {
            event.call(observer)
        }
    }
    
    open class func presentViewController(_ viewController: UIViewController) {
        presentViewController(viewController, includeNavigation: true)
    }
    
    fileprivate class func presentViewController(_ viewController: UIViewController, includeNavigation includeNav: Bool) {
        var frame = UIScreen.main.bounds
        if UIDeviceOrientationIsLandscape(UIDevice.current.orientation) {
            frame = CGRect(x: 0, y: 0, width: frame.height, height: frame.width)
        }
        
        sharedInstance?.window = UIWindow(frame: frame)
        sharedInstance?.window?.isHidden = false
        sharedInstance?.window?.rootViewController = UIViewController()
        
        if includeNav {
            let navController = ModalViewController(rootViewController: viewController)
            navController.modalDelegate = sharedInstance
            sharedInstance?.window?.rootViewController?.present(navController, animated: true, completion: nil)
        } else {
            sharedInstance?.window?.rootViewController?.present(viewController, animated: true, completion: nil)
        }
    }
    
    open class func viewController(message: Message) -> UIViewController? {
        switch message.action {
        case .landingPage:
            let viewController = ScreenViewController()
            
            if let screen = message.landingPage {
                viewController.screen = screen
            } else {
                //viewController.showActivityIndicator()
                
                let mappingOperation = MappingOperation() { (screen: Screen) in
                    message.landingPage = screen
                    
                    DispatchQueue.main.async {
                        viewController.screen = screen
                    }
                }
                
                mappingOperation.completionBlock = {
                    //viewController.hideActivityIndicator()
                }
                
                let networkOperation = NetworkOperation(urlRequest: Router.getLandingPage(message).urlRequest as URLRequest) {
                    [unowned mappingOperation]
                    (JSON, error) in
                    
                    if let JSON = JSON { mappingOperation.json = ["data": JSON] }
                }
                
                mappingOperation.addDependency(networkOperation)
                
                sharedInstance?.operationQueue.addOperation(networkOperation)
                sharedInstance?.operationQueue.addOperation(mappingOperation)
            }
            
            return viewController
        case .experience:
            guard let experienceId = message.experienceId else { return nil }
            return ExperienceViewController(identifier: experienceId)
        default:
            return nil
        }
    }
    
    // MARK: UIApplicationNotifications
    
    func applicationDidOpen(_ note: Notification) {
        if let userInfo = (note as NSNotification).userInfo?[UIApplicationLaunchOptionsKey.remoteNotification] as? [AnyHashable: Any] {
            Rover.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: nil, fromLaunch: true)
        }
        self.sendEvent(.applicationOpen(date: Date()))
    }
    
    var applicationIsActive = false
    
    func applicationDidEnterBackground(_ note: Notification) {
        applicationIsActive = false
    }
    
    func applicationDidBecomeActive(_ note: Notification) {
        applicationIsActive = true
    }
    
    func sendEvent(_ event: Event) {
        let eventOperation = EventOperation(event: event)
        eventOperation.delegate = self
        
        eventOperationQueue.addOperation(eventOperation)
    }
}

extension Rover : ModalViewControllerDelegate {
    func didDismissModalViewController(_ viewController: ModalViewController) {
        window?.rootViewController = nil
        window = nil
    }
}

extension Rover : LocationManagerDelegate {
    
    func locationManager(_ manager: LocatioManager, didEnterRegion region: CLRegion) {
        if region is CLBeaconRegion {
            sendEvent(.didEnterBeaconRegion(region as! CLBeaconRegion, config: nil, place: nil, date: Date()))
        } else {
            sendEvent(.didEnterCircularRegion(region as! CLCircularRegion, place: nil, date: Date()))
        }
    }
    
    func locationManager(_ manager: LocatioManager, didExitRegion region: CLRegion) {
        if region is CLBeaconRegion {
            sendEvent(.didExitBeaconRegion(region as! CLBeaconRegion, config: nil, place: nil, date: Date()))
        } else {
            sendEvent(.didExitCircularRegion(region as! CLCircularRegion, place: nil, date: Date()))
        }
    }
    
    func locationManager(_ manager: LocatioManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations[0]
        let date = Date()
        sendEvent(.didUpdateLocation(location, date: date))
    }
}

extension Rover : EventOperationDelegate {
    
    func eventOperation(_ operation: EventOperation, didPostEvent event: Event) {
        self.notifyObservers(event: event)
    }
    
    func eventOperation(_ operation: EventOperation, didReceiveRegions regions: [CLRegion]) {
        self.locationManager?.monitoredRegions = Set(regions)
    }
}

extension Rover /*: RVRGimbalPlaceManagerDelegate*/ {
    
    public func placeManager(_ manager: RVRGimbalPlaceManager!, didUpdateLocation location: CLLocation!) {
        sendEvent(.didUpdateLocation(location, date: Date()))
    }
    
    public func placeManager(_ manager: RVRGimbalPlaceManager!, didEnterGimbalPlaceWithIdentifier identifier: String!) {
        sendEvent(.didEnterGimbalPlace(id: identifier, date: Date()))
    }
    
    public func placeManager(_ manager: RVRGimbalPlaceManager!, didExitGimbalPlaceWithIdentifier identifier: String!) {
        sendEvent(.didExitGimbalPlace(id: identifier, date: Date()))
    }
}

extension Rover: ExperienceViewControllerDelegate {
    func experienceViewControllerDidLaunch(_ viewController: ExperienceViewController) {
        guard let experience = viewController.experience else { return }
        sendEvent(.didLaunchExperience(experience, session: viewController.sessionID, date: Date()))
        
        for observer in observers {
            observer.experienceViewControllerDidLaunch?(viewController)
        }
    }
    
    func experienceViewControllerDidDismiss(_ viewController: ExperienceViewController) {
        guard let experience = viewController.experience else { return }
        sendEvent(.didDismissExperience(experience, session: viewController.sessionID, date: Date()))
        
        for observer in observers {
            observer.experienceViewControllerDidDismiss?(viewController)
        }
    }
    
    func experienceViewController(_ viewController: ExperienceViewController, didViewScreen screen: Screen, referrerScreen: Screen?, referrerBlock: Block?) {
        guard let experience = viewController.experience else { return }
        sendEvent(.didViewScreen(screen, experience: experience, fromScreen: referrerScreen, fromBlock: referrerBlock, session: viewController.sessionID, date: Date()))
        
        for observer in observers {
            observer.experienceViewController?(viewController, didViewScreen: screen, referrerScreen: referrerScreen, referrerBlock: referrerBlock)
        }
    }
    
    func experienceViewController(_ viewController: ExperienceViewController, didPressBlock block: Block, screen: Screen) {
        guard let experience = viewController.experience else { return }
        sendEvent(.didPressBlock(block, screen: screen, experience: experience, session: viewController.sessionID, date: Date()))
        
        for observer in observers {
            observer.experienceViewController?(viewController, didPressBlock: block, screen: screen)
        }
    }
    
    func experienceViewController(_ viewController: ExperienceViewController, willLoadExperience experience: Experience) {
        for observer in observers {
            observer.experienceViewController?(viewController, willLoadExperience: experience)
        }
    }
}
