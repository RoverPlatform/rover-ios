//
//  UIAssembler.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-05-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import SafariServices
import CoreData

public struct UIAssembler {
    public var associatedDomains: [String]
    public var urlSchemes: [String]
    
    public var sessionKeepAliveTime: Int
    
    public var isLifeCycleTrackingEnabled: Bool
    public var isVersionTrackingEnabled: Bool
    
    public var appGroup: String?
    public var influenceTime: Int
    public var isInfluenceTrackingEnabled: Bool
    public var maxNotifications: Int
    
    public init(associatedDomains: [String] = [], urlSchemes: [String] = [], sessionKeepAliveTime: Int = 30, isLifeCycleTrackingEnabled: Bool = true, isVersionTrackingEnabled: Bool = true, appGroup: String? = nil, isInfluenceTrackingEnabled: Bool = true, influenceTime: Int = 120, maxNotifications: Int = 200) {
        self.associatedDomains = associatedDomains
        self.urlSchemes = urlSchemes
        self.sessionKeepAliveTime = sessionKeepAliveTime
        self.isLifeCycleTrackingEnabled = isLifeCycleTrackingEnabled
        self.isVersionTrackingEnabled = isVersionTrackingEnabled
        self.appGroup = appGroup
        self.influenceTime = influenceTime
        self.isInfluenceTrackingEnabled = isInfluenceTrackingEnabled
        self.maxNotifications = maxNotifications
    }
}

// MARK: Assembler

extension UIAssembler: Assembler {
    public func assemble(container: Container) {
        // MARK: TEMPORARY FAKE THINGS
        
        container.register(SyncCoordinator.self) { resolver in
            return FakeSyncCoordinator()
        }
        
        // MARK: ImageStore
        
        container.register(ImageStore.self) { resolver in
            let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
            return ImageStoreService(session: session)
        }
        
        // MARK: LifeCycleTracker
        
        container.register(LifeCycleTracker.self) { resolver in
            let eventPipeline = resolver.resolve(EventPipeline.self)!
            let sessionController = resolver.resolve(SessionController.self)!
            return LifeCycleTrackerService(eventPipeline: eventPipeline, sessionController: sessionController)
        }
        
        // MARK: Router
        
        container.register(Router.self) { resolver in
            let experienceViewControllerProvider: (ExperienceIdentifier) -> UIViewController = { experienceIdentifier in
                resolver.resolve(UIViewController.self, name: "experience", arguments: experienceIdentifier)!
            }
            
            let settingsViewControllerProvider: () -> UIViewController = {
                resolver.resolve(UIViewController.self, name: "settings")!
            }
            
            let notificationCenterViewControllerProvider: () -> UIViewController = {
                resolver.resolve(UIViewController.self, name: "notificationCenter")!
            }
            
            return Router(associatedDomains: self.associatedDomains, urlSchemes: self.urlSchemes, experienceViewControllerProvider: experienceViewControllerProvider, settingsViewControllerProvider: settingsViewControllerProvider, notificationCenterViewControllerProvider: notificationCenterViewControllerProvider)
        }
        
        // MARK: SessionController
        
        container.register(SessionController.self) { [sessionKeepAliveTime] resolver in
            let eventPipeline = resolver.resolve(EventPipeline.self)!
            return SessionControllerService(eventPipeline: eventPipeline, keepAliveTime: sessionKeepAliveTime)
        }
        
        // MARK: UIViewController (website)
        
        container.register(UIViewController.self, name: "website", scope: .transient) { (resolver, url: URL) in
            return SFSafariViewController(url: url)
        }
        

        
        // MARK: VersionTracker
        
        container.register(VersionTracker.self) { resolver in
            return VersionTrackerService(
                bundle: Bundle.main,
                eventPipeline: resolver.resolve(EventPipeline.self)!,
                userDefaults: UserDefaults.standard
            )
        }
        
        // MARK: ExperienceStore
        
        container.register(ExperienceStore.self) { resolver in
            let client = resolver.resolve(FetchExperienceClient.self)!
            return ExperienceStoreService(client: client)
        }
        
        // MARK: UICollectionViewLayout (screen)
        
        container.register(UICollectionViewLayout.self, name: "screen", scope: .transient) { (resolver, screen: Screen) in
            return ScreenViewLayout(screen: screen)
        }
        
        // MARK: UIViewController (experience)
        
        container.register(UIViewController.self, name: "experience", scope: .transient) { (resolver, identifier: ExperienceIdentifier) in
            let viewControllerProvider: ExperienceContainer.ViewControllerProvider = { [weak resolver] experience in
                return resolver?.resolve(UIViewController.self, name: "experience", arguments: experience)
            }
            
            return ExperienceContainer(
                identifier: identifier,
                store: resolver.resolve(ExperienceStore.self)!,
                viewControllerProvider: viewControllerProvider
            )
        }
        
        container.register(UIViewController.self, name: "experience", scope: .transient) { (resolver, experience: Experience) in
            return ExperienceViewController(
                rootViewController: resolver.resolve(UIViewController.self, name: "screen", arguments: experience, experience.homeScreen)!,
                experience: experience,
                eventPipeline: resolver.resolve(EventPipeline.self)!,
                sessionController: resolver.resolve(SessionController.self)!
            )
        }
        
        // MARK: UIViewController (screen)
        
        container.register(UIViewController.self, name: "screen", scope: .transient) { (resolver, experience: Experience, screen: Screen) in
            let viewControllerProvider: ScreenViewController.ViewControllerProvider = { [weak resolver] (experience, screen) in
                return resolver?.resolve(UIViewController.self, name: "screen", arguments: experience, screen)
            }
            
            let websiteViewControllerProvider: ScreenViewController.WebsiteViewControllerProvider = { [weak resolver] url in
                resolver?.resolve(UIViewController.self, name: "website", arguments: url)!
            }
            
            return ScreenViewController(
                collectionViewLayout: resolver.resolve(UICollectionViewLayout.self, name: "screen", arguments: screen)!,
                experience: experience,
                screen: screen,
                eventPipeline: resolver.resolve(EventPipeline.self)!,
                imageStore: resolver.resolve(ImageStore.self)!,
                sessionController: resolver.resolve(SessionController.self)!,
                viewControllerProvider: viewControllerProvider,
                websiteViewControllerProvider: websiteViewControllerProvider
            )
        }
        
        // MARK: InfluenceTracker
        
        container.register(InfluenceTracker.self) { resolver in
            return InfluenceTrackerService(
                influenceTime: self.influenceTime,
                eventPipeline: resolver.resolve(EventPipeline.self),
                notificationCenter: NotificationCenter.default,
                userDefaults: UserDefaults(suiteName: self.appGroup)!
            )
        }
        
        // MARK: NotificationHandler
        
        container.register(NotificationHandler.self) { resolver in            
            let websiteViewControllerProvider: NotificationCenterViewController.WebsiteViewControllerProvider = { [weak resolver] url in
                return resolver?.resolve(UIViewController.self, name: "website", arguments: url)!
            }
            
            return NotificationHandlerService(
                influenceTracker: resolver.resolve(InfluenceTracker.self)!,
                notificationStore: resolver.resolve(NotificationStore.self)!,
                eventPipeline: resolver.resolve(EventPipeline.self)!,
                websiteViewControllerProvider: websiteViewControllerProvider
            )
        }
        
        // MARK: NotificationStore
        
        container.register(NotificationStore.self) { [maxNotifications] resolver in
            return NotificationStoreService(
                maxSize: maxNotifications,
                eventPipeline: resolver.resolve(EventPipeline.self)
            )
        }
        
        // MARK: UIViewController (notificationCenter)
        
        container.register(UIViewController.self, name: "notificationCenter") { resolver in
            let websiteViewControllerProvider: NotificationCenterViewController.WebsiteViewControllerProvider = { [weak resolver] url in
                return resolver?.resolve(UIViewController.self, name: "website", arguments: url)!
            }
            
            return NotificationCenterViewController(
                eventPipeline: resolver.resolve(EventPipeline.self)!,
                imageStore: resolver.resolve(ImageStore.self)!,
                notificationStore: resolver.resolve(NotificationStore.self)!,
                router: resolver.resolve(Router.self)!,
                sessionController: resolver.resolve(SessionController.self)!,
                syncCoordinator: resolver.resolve(SyncCoordinator.self)!,
                websiteViewControllerProvider: websiteViewControllerProvider
            )
        }
        
        // MARK: Device
        
        container.register(Device.self) { resolver in
            return Device(
                // these Info Providers are furnished by the other Rover modules, if they are installed.
                adSupportInfoProvider: resolver.resolve(AdSupportInfoProvider.self),
                bluetoothInfoProvider: resolver.resolve(BluetoothInfoProvider.self),
                telephonyInfoProvider: resolver.resolve(TelephonyInfoProvider.self),
                locationInfoProvider: resolver.resolve(LocationInfoProvider.self)
            )
        }
        
        container.register(DeviceInfoProvider.self) { resolver in
            return resolver.resolve(Device.self)!
        }
        
        // MARK: UIViewController (settings)
        
        container.register(UIViewController.self, name: "settings", scope: .transient) { resolver in
            return SettingsViewController()
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        if isVersionTrackingEnabled {
            resolver.resolve(VersionTracker.self)!.checkAppVersion()
        }
        
        if isLifeCycleTrackingEnabled {
            resolver.resolve(LifeCycleTracker.self)!.enable()
        }
        
        if isInfluenceTrackingEnabled {
            let influenceTracker = resolver.resolve(InfluenceTracker.self)!
            influenceTracker.startMonitoring()
        }
        
        let store = resolver.resolve(NotificationStore.self)!
        store.restore()        
    }
}
