//
//  NotificationsAssembler.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-03-07.
//  Copyright © 2018 Sean Rucker. All rights reserved.
//

import UIKit
import UserNotifications

public struct NotificationsAssembler: Assembler {
    public var appGroup: String?
    public var influenceTime: Int
    public var isInfluenceTrackingEnabled: Bool
    public var maxNotifications: Int
    
    public init(appGroup: String? = nil, isInfluenceTrackingEnabled: Bool = true, influenceTime: Int = 120, maxNotifications: Int = 200) {
        self.appGroup = appGroup
        self.influenceTime = influenceTime
        self.isInfluenceTrackingEnabled = isInfluenceTrackingEnabled
        self.maxNotifications = maxNotifications
    }
    
    public func assemble(container: Container) {
        
        // MARK: Action (openNotification)
        
        container.register(Action.self, name: "openNotification", scope: .transient) { (resolver, notification: Notification) in
            let eventQueue = resolver.resolve(EventQueue.self)!
            let notificationStore = resolver.resolve(NotificationStore.self)!
            return OpenNotificationAction(eventQueue: eventQueue, notification: notification, notificationStore: notificationStore, presentWebsiteActionProvider: { url in
                return resolver.resolve(Action.self, name: "presentWebsite", arguments: url)!
            })
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
            let dispatcher = resolver.resolve(Dispatcher.self)!
            return NotificationHandlerService(dispatcher: dispatcher, actionProvider: { notification in
                return resolver.resolve(Action.self, name: "openNotification", arguments: notification)!
            })
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
            return NotificationCenterRouteHandler(actionProvider: {
                return resolver.resolve(Action.self, name: "presentNotificationCenter")!
            })
        }
        
        // MARK: SyncParticipant (notifications)
        
        container.register(SyncParticipant.self, name: "notifications") { resolver in
            return NotificationsSyncParticipant(
                store: resolver.resolve(NotificationStore.self)!
            )
        }
        
        // MARK: UIViewController (notificationCenter)
        
        container.register(UIViewController.self, name: "notificationCenter") { resolver in
            return NotificationCenterViewController(
                dispatcher: resolver.resolve(Dispatcher.self)!,
                eventQueue: resolver.resolve(EventQueue.self)!,
                imageStore: resolver.resolve(ImageStore.self)!,
                notificationStore: resolver.resolve(NotificationStore.self)!,
                router: resolver.resolve(Router.self)!,
                sessionController: resolver.resolve(SessionController.self)!,
                syncCoordinator: resolver.resolve(SyncCoordinator.self)!,
                presentWebsiteActionProvider: { url in
                    return resolver.resolve(Action.self, name: "presentWebsite", arguments: url)!
                }
            )
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
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
    }
}
