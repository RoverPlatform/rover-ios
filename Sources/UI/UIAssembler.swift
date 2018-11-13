//
//  UIAssembler.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-05-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import SafariServices

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
        
        // MARK: Action (openURL)
        
        container.register(Action.self, name: "openURL", scope: .transient) { (resolver, url: URL) in
            return OpenURLAction(url: url)
        }
        
        
        // MARK: Action (presentWebsite)
        
        container.register(Action.self, name: "presentWebsite", scope: .transient) { (resolver, url: URL) in
            let viewControllerToPresent = resolver.resolve(UIViewController.self, name: "website", arguments: url)!
            return resolver.resolve(Action.self, name: "presentView", arguments: viewControllerToPresent)!
        }
        
        // MARK: ImageStore
        
        container.register(ImageStore.self) { resolver in
            let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
            return ImageStoreService(session: session)
        }
        
        // MARK: LifeCycleTracker
        
        container.register(LifeCycleTracker.self) { resolver in
            let eventQueue = resolver.resolve(EventQueue.self)!
            let sessionController = resolver.resolve(SessionController.self)!
            return LifeCycleTrackerService(eventQueue: eventQueue, sessionController: sessionController)
        }
        
        // MARK: Router
        
        container.register(Router.self) { resolver in
            let dispatcher = resolver.resolve(Dispatcher.self)!
            return RouterService(associatedDomains: self.associatedDomains, urlSchemes: self.urlSchemes, dispatcher: dispatcher)
        }
        
        // MARK: SessionController
        
        container.register(SessionController.self) { [sessionKeepAliveTime] resolver in
            let eventQueue = resolver.resolve(EventQueue.self)!
            return SessionControllerService(eventQueue: eventQueue, keepAliveTime: sessionKeepAliveTime)
        }
        
        // MARK: UIViewController (website)
        
        container.register(UIViewController.self, name: "website", scope: .transient) { (resolver, url: URL) in
            return SFSafariViewController(url: url)
        }
        
        // MARK: VersionTracker
        
        container.register(VersionTracker.self) { resolver in
            return VersionTrackerService(
                bundle: Bundle.main,
                eventQueue: resolver.resolve(EventQueue.self)!,
                userDefaults: UserDefaults.standard
            )
        }
        
        // MARK: Action (presentExperience)
        
        container.register(Action.self, name: "presentExperience", scope: .transient) { (resolver, campaignID: ID) in
            let identifier = ExperienceIdentifier.campaignID(id: campaignID)
            return resolver.resolve(Action.self, name: "presentExperience", arguments: identifier)!
        }
        
        container.register(Action.self, name: "presentExperience", scope: .transient) { (resolver, identifier: ExperienceIdentifier) in
            let viewControllerToPresent = resolver.resolve(UIViewController.self, name: "experience", arguments: identifier)!
            return resolver.resolve(Action.self, name: "presentView", arguments: viewControllerToPresent)!
        }
        
        // MARK: ExperienceStore
        
        container.register(ExperienceStore.self) { resolver in
            let client = resolver.resolve(FetchExperienceClient.self)!
            return ExperienceStoreService(client: client)
        }
        
        // MARK: FetchExperienceClient
        
        container.register(FetchExperienceClient.self) { resolver in
            return resolver.resolve(HTTPClient.self)!
        }
        
        // MARK: RouteHandler (experience)
        
        container.register(RouteHandler.self, name: "experience") { resolver in
            let actionProvider: ExperienceRouteHandler.ActionProvider = { [weak resolver] identifier in
                return resolver?.resolve(Action.self, name: "presentExperience", arguments: identifier)
            }
            
            return ExperienceRouteHandler(actionProvider: actionProvider)
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
                eventQueue: resolver.resolve(EventQueue.self)!,
                sessionController: resolver.resolve(SessionController.self)!
            )
        }
        
        // MARK: UIViewController (screen)
        
        container.register(UIViewController.self, name: "screen", scope: .transient) { (resolver, experience: Experience, screen: Screen) in
            let viewControllerProvider: ScreenViewController.ViewControllerProvider = { [weak resolver] (experience, screen) in
                return resolver?.resolve(UIViewController.self, name: "screen", arguments: experience, screen)
            }
            
            let presentWebsiteActionProvider: ScreenViewController.ActionProvider = { [weak resolver] url in
                return resolver?.resolve(Action.self, name: "presentWebsite", arguments: url)
            }
            
            return ScreenViewController(
                collectionViewLayout: resolver.resolve(UICollectionViewLayout.self, name: "screen", arguments: screen)!,
                experience: experience,
                screen: screen,
                dispatcher: resolver.resolve(Dispatcher.self)!,
                eventQueue: resolver.resolve(EventQueue.self)!,
                imageStore: resolver.resolve(ImageStore.self)!,
                sessionController: resolver.resolve(SessionController.self)!,
                viewControllerProvider: viewControllerProvider,
                presentWebsiteActionProvider: presentWebsiteActionProvider
            )
        }
        
        // MARK: Action (openNotification)
        
        container.register(Action.self, name: "openNotification", scope: .transient) { (resolver, notification: Notification) in
            let presentWebsiteActionProvider: OpenNotificationAction.ActionProvider = { [weak resolver] url in
                return resolver?.resolve(Action.self, name: "presentWebsite", arguments: url)!
            }
            
            return OpenNotificationAction(
                eventQueue: resolver.resolve(EventQueue.self)!,
                notification: notification,
                notificationStore: resolver.resolve(NotificationStore.self)!,
                presentWebsiteActionProvider: presentWebsiteActionProvider
            )
        }
        
        // MARK: Action (presentNotificationCenter)
        
        container.register(Action.self, name: "presentNotificationCenter", scope: .transient) { resolver in
            let viewControllerToPresent = resolver.resolve(UIViewController.self, name: "notificationCenter")!
            return resolver.resolve(Action.self, name: "presentView", arguments: viewControllerToPresent)!
        }
        
        // MARK: InfluenceTracker
        
        container.register(InfluenceTracker.self) { resolver in
            return InfluenceTrackerService(
                influenceTime: self.influenceTime,
                eventQueue: resolver.resolve(EventQueue.self),
                notificationCenter: NotificationCenter.default,
                userDefaults: UserDefaults(suiteName: self.appGroup)!
            )
        }
        
        // MARK: NotificationAuthorizationManager
        
        container.register(NotificationAuthorizationManager.self) { resolver in
            return NotificationAuthorizationManager()
        }
        
        // MARK: NotificationContextProvider
        
        container.register(NotificationsContextProvider.self) { resolver in
            return resolver.resolve(NotificationAuthorizationManager.self)!
        }
        
        // MARK: NotificationHandler
        
        container.register(NotificationHandler.self) { resolver in
            let actionProvider: NotificationHandlerService.ActionProvider = { [weak resolver] notification in
                return resolver?.resolve(Action.self, name: "openNotification", arguments: notification)
            }
            
            return NotificationHandlerService(
                dispatcher: resolver.resolve(Dispatcher.self)!,
                influenceTracker: resolver.resolve(InfluenceTracker.self)!,
                actionProvider: actionProvider
            )
        }
        
        // MARK: NotificationStore
        
        container.register(NotificationStore.self) { [maxNotifications] resolver in
            return NotificationStoreService(
                maxSize: maxNotifications,
                eventQueue: resolver.resolve(EventQueue.self)
            )
        }
        
        // MARK: RouteHandler (notificationCenter)
        
        container.register(RouteHandler.self, name: "notificationCenter") { resolver in
            let actionProvider: NotificationCenterRouteHandler.ActionProvider = { [weak resolver] in
                return resolver?.resolve(Action.self, name: "presentNotificationCenter")
            }
            
            return NotificationCenterRouteHandler(actionProvider: actionProvider)
        }
        
        // MARK: SyncParticipant (notifications)
        
        container.register(SyncParticipant.self, name: "notifications") { resolver in
            return NotificationsSyncParticipant(
                store: resolver.resolve(NotificationStore.self)!
            )
        }
        
        // MARK: UIViewController (notificationCenter)
        
        container.register(UIViewController.self, name: "notificationCenter") { resolver in
            let presentWebsiteActionProvider: NotificationCenterViewController.ActionProvider = { [weak resolver] url in
                return resolver?.resolve(Action.self, name: "presentWebsite", arguments: url)
            }
            
            return NotificationCenterViewController(
                dispatcher: resolver.resolve(Dispatcher.self)!,
                eventQueue: resolver.resolve(EventQueue.self)!,
                imageStore: resolver.resolve(ImageStore.self)!,
                notificationStore: resolver.resolve(NotificationStore.self)!,
                router: resolver.resolve(Router.self)!,
                sessionController: resolver.resolve(SessionController.self)!,
                syncCoordinator: resolver.resolve(SyncCoordinator.self)!,
                presentWebsiteActionProvider: presentWebsiteActionProvider
            )
        }
        
        // MARK: DebugContextProvider
        
        container.register(DebugContextProvider.self) { resolver in
            return DebugContextManager()
        }
        
        // MARK: RouteHandler (settings)
        
        container.register(RouteHandler.self, name: "settings") { resolver in
            let actionProvider: SettingsRouteHandler.ActionProvider = { [weak resolver] in
                return resolver?.resolve(Action.self, name: "settings")
            }
            
            return SettingsRouteHandler(actionProvider: actionProvider)
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
        
        if let router = resolver.resolve(Router.self) {
            let handler = resolver.resolve(RouteHandler.self, name: "experience")!
            router.addHandler(handler)
        }
        
        if isInfluenceTrackingEnabled {
            let influenceTracker = resolver.resolve(InfluenceTracker.self)!
            influenceTracker.startMonitoring()
        }
        
        if let router = resolver.resolve(Router.self) {
            let handler = resolver.resolve(RouteHandler.self, name: "notificationCenter")!
            router.addHandler(handler)
        }
        
        let store = resolver.resolve(NotificationStore.self)!
        store.restore()
        
        let syncParticipant = resolver.resolve(SyncParticipant.self, name: "notifications")!
        resolver.resolve(SyncCoordinator.self)!.participants.append(syncParticipant)
        
        let handler = resolver.resolve(RouteHandler.self, name: "settings")!
        resolver.resolve(Router.self)!.addHandler(handler)
    }
}
