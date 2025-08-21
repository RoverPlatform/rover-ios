// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import RoverFoundation
import RoverData
import RoverUI
import UIKit
import UserNotifications
import SwiftUI
import os.log

public struct NotificationsAssembler: Assembler {
    public var appGroup: String?
    public var influenceTime: Int
    public var isInfluenceTrackingEnabled: Bool
    public var maxNotifications: Int
    public var updateAppBadge: Bool

    public init(appGroup: String? = nil, isInfluenceTrackingEnabled: Bool = true, influenceTime: Int = 120, maxNotifications: Int = 200, updateAppBadge: Bool = true) {
        self.appGroup = appGroup
        self.influenceTime = influenceTime
        self.isInfluenceTrackingEnabled = isInfluenceTrackingEnabled
        self.maxNotifications = maxNotifications
        self.updateAppBadge = updateAppBadge
    }
    
    // swiftlint:disable:next function_body_length // Assemblers are fairly declarative.
    public func assemble(container: Container) {
        // MARK: Action (openNotification)
        
        container.register(Action.self, name: "openNotification", scope: .transient) { (resolver, notification: Notification) in
            let presentWebsiteActionProvider: OpenNotificationAction.ActionProvider = { [weak resolver] url in
                resolver?.resolve(Action.self, name: "presentWebsite", arguments: url)!
            }
            
            return OpenNotificationAction(
                eventQueue: resolver.resolve(EventQueue.self)!,
                notification: notification,
                notificationStore: resolver.resolve(NotificationStore.self)!,
                conversionsTracker: resolver.resolve(ConversionsTrackerService.self)!,
                presentWebsiteActionProvider: presentWebsiteActionProvider
            )
        }
        
        // MARK: Action (presentNotificationCenter)
        
        container.register(Action.self, name: "presentNotificationCenter", scope: .transient) { resolver in
            let viewControllerToPresent = resolver.resolve(UIViewController.self, name: "inbox")!
            return resolver.resolve(Action.self, name: "presentView", arguments: viewControllerToPresent)!
        }
        
        // MARK: Action (presentCommunicationHub)
        
        container.register(Action.self, name: "presentCommunicationHub", scope: .transient) { (resolver) in
            let viewControllerToPresent = CommunicationHubHostingController(
                title: "Inbox"
            )

            os_log("Presenting Communication Hub", log: .communicationHub, type: .debug)

            return resolver.resolve(Action.self, name: "presentView", arguments: viewControllerToPresent as UIViewController)!
        }
        
        // MARK: Action (presentPost)
        
        container.register(Action.self, name: "presentPost", scope: .transient) { (resolver, postID: String?) in

            let viewControllerToPresent = ShowPostHostingController(
                postID: postID,
            )

            os_log("Presenting Post Detail", log: .communicationHub, type: .debug)

            return resolver.resolve(Action.self, name: "presentView", arguments: viewControllerToPresent as UIViewController)!
        }
        
        // MARK: InfluenceTracker
        
        container.register(InfluenceTracker.self) { resolver in
            InfluenceTrackerService(
                influenceTime: self.influenceTime,
                eventQueue: resolver.resolve(EventQueue.self),
                notificationCenter: NotificationCenter.default,
                userDefaults: UserDefaults(suiteName: self.appGroup)!
            )
        }
        
        // MARK: NotificationAuthorizationManager
        
        container.register(NotificationAuthorizationManager.self) { _ in
            NotificationAuthorizationManager()
        }
        
        // MARK: NotificationContextProvider
        
        container.register(NotificationsContextProvider.self) { resolver in
            resolver.resolve(NotificationAuthorizationManager.self)!
        }
        
        // MARK: NotificationHandler
        
        container.register(NotificationHandler.self) { resolver in
            let actionProvider: NotificationHandlerService.ActionProvider = { [weak resolver] notification in
                resolver?.resolve(Action.self, name: "openNotification", arguments: notification)
            }
            
            return NotificationHandlerService(
                dispatcher: resolver.resolve(Dispatcher.self)!,
                influenceTracker: resolver.resolve(InfluenceTracker.self)!,
                actionProvider: actionProvider
            )
        }
        
        // MARK: NotificationStore
        
        container.register(NotificationStore.self) { [maxNotifications] resolver in
            NotificationStoreService(
                maxSize: maxNotifications,
                eventQueue: resolver.resolve(EventQueue.self),
                userDefaults: UserDefaults(suiteName: self.appGroup)!
            )
        }
        
        // MARK: RouteHandler (notificationCenter)
        
        container.register(RouteHandler.self, name: "inbox") { resolver in
            let actionProvider: InboxRouteHandler.ActionProvider = { [weak resolver] in
                resolver?.resolve(Action.self, name: "presentNotificationCenter")
            }
            
            return InboxRouteHandler(actionProvider: actionProvider)
        }
        
        // MARK: RouteHandler (communicationHub)
        
        container.register(RouteHandler.self, name: "communicationHub") { resolver in
            let postsListActionProvider: ShowPostRouteHandler.PostsListActionProvider = { [weak resolver] postId in
                resolver?.resolve(Action.self, name: "presentPost", arguments: postId)
            }
            
            return ShowPostRouteHandler(
                postsListActionProvider: postsListActionProvider
            )
        }
        
        // MARK: SyncParticipant (notifications)
        
        container.register(SyncParticipant.self, name: "notifications") { resolver in
            NotificationsSyncParticipant(
                store: resolver.resolve(NotificationStore.self)!
            )
        }

         
        // MARK: Communication Hub

        container.register(RCHPersistentContainer.self, scope: .singleton) { resolver in
            RCHPersistentContainer(storage: .persistent)
        }

        container.register(RCHSync.self, scope: .singleton) { resolver in
            return MainActor.assumeIsolatedOrFatalError {
                RCHSync(
                    persistentContainer: resolver.resolve(RCHPersistentContainer.self)!,
                    httpClient: resolver.resolve(HTTPClient.self)!
                )
            }
        }

        if updateAppBadge {
            container.register(RoverBadge.self, scope: .singleton) { resolver in
                return MainActor.assumeIsolatedOrFatalError {
                    RoverBadge(
                        persistentContainer: resolver.resolve(RCHPersistentContainer.self)!,
                        updateAppBadge: updateAppBadge
                    )
                }
            }
        }
        
        // MARK: UIViewController (inbox)
        
        container.register(UIViewController.self, name: "inbox") { resolver in
            let presentWebsiteActionProvider: InboxViewController.ActionProvider = { [weak resolver] url in
                resolver?.resolve(Action.self, name: "presentWebsite", arguments: url)
            }
            
            return InboxViewController(
                dispatcher: resolver.resolve(Dispatcher.self)!,
                eventQueue: resolver.resolve(EventQueue.self)!,
                imageStore: resolver.resolve(ImageStore.self)!,
                notificationStore: resolver.resolve(NotificationStore.self)!,
                router: resolver.resolve(Router.self)!,
                sessionController: resolver.resolve(SessionController.self)!,
                syncCoordinator: resolver.resolve(SyncCoordinator.self)!,
                conversionsTracker: resolver.resolve(ConversionsTrackerService.self)!,
                presentWebsiteActionProvider: presentWebsiteActionProvider
            )
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        if isInfluenceTrackingEnabled {
            let influenceTracker = resolver.resolve(InfluenceTracker.self)!
            influenceTracker.startMonitoring()
        }
        
        if let router = resolver.resolve(Router.self) {
            let inboxHandler = resolver.resolve(RouteHandler.self, name: "inbox")!
            router.addHandler(inboxHandler)
            
            let communicationHubHandler = resolver.resolve(RouteHandler.self, name: "communicationHub")!
            router.addHandler(communicationHubHandler)
        }
        
        let store = resolver.resolve(NotificationStore.self)!
        store.restore()

        // start up persistence and sync for comms hub
        let commSync = resolver.resolve(RCHSync.self)!

        resolver.resolve(SyncCoordinator.self)!.registerStandaloneParticipant(commSync)


        let syncParticipant = resolver.resolve(SyncParticipant.self, name: "notifications")!
        resolver.resolve(SyncCoordinator.self)!.participants.append(syncParticipant)
    }
}

private extension MainActor {
    static func assumeIsolatedOrFatalError<T>(_ operation: @MainActor () -> T) -> T where T : Sendable {
        if Thread.isMainThread {
                return MainActor.assumeIsolated {
                    operation()
                }
        } else {
            fatalError("Rover must be initialized on the main thread")
        }
    }
}
