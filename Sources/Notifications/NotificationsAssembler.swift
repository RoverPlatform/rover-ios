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

import RoverData
import RoverFoundation
import RoverUI
import SwiftUI
import UIKit
import UserNotifications
import os.log

public struct NotificationsAssembler: Assembler {
    public var appGroup: String?
    public var influenceTime: Int
    public var isInfluenceTrackingEnabled: Bool
    public var maxNotifications: Int
    public var updateAppBadge: Bool

    public init(
        appGroup: String? = nil, isInfluenceTrackingEnabled: Bool = true, influenceTime: Int = 120,
        maxNotifications: Int = 200, updateAppBadge: Bool = true
    ) {
        self.appGroup = appGroup
        self.influenceTime = influenceTime
        self.isInfluenceTrackingEnabled = isInfluenceTrackingEnabled
        self.maxNotifications = maxNotifications
        self.updateAppBadge = updateAppBadge
    }

    // swiftlint:disable:next function_body_length // Assemblers are fairly declarative.
    public func assemble(container: Container) {
        // MARK: Action (openNotification)

        container.register(Action.self, name: "openNotification", scope: .transient) {
            (resolver, notification: Notification) in
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

        // MARK: Action (presentHub)

        container.register(Action.self, name: "presentHub", scope: .transient) { (resolver) in
            let viewControllerToPresent = HubHostingController()

            os_log("Presenting Hub", log: .hub, type: .debug)

            return resolver.resolve(
                Action.self, name: "presentView", arguments: viewControllerToPresent as UIViewController)!
        }

        // MARK: Action (presentPost)

        container.register(Action.self, name: "presentPost", scope: .transient) { (resolver, postID: String?) in

            let viewControllerToPresent = ShowPostHostingController(
                postID: postID,
            )

            os_log("Presenting Post Detail", log: .hub, type: .debug)

            return resolver.resolve(
                Action.self, name: "presentView", arguments: viewControllerToPresent as UIViewController)!
        }

        // MARK: Action (navigateToPost)

        container.register(Action.self, name: "navigateToPost", scope: .transient) { (resolver, postID: String) in
            NavigateToPostAction(
                coordinator: resolver.resolve(HubCoordinator.self)!,
                postID: postID
            )
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

        // MARK: RouteHandler (Hub)

        container.register(RouteHandler.self, name: "hub") { resolver in
            let presentPostActionProvider: (String?) -> Action? = { [weak resolver] postId in
                resolver?.resolve(Action.self, name: "presentPost", arguments: postId)
            }

            let navigateToPostActionProvider: (String) -> Action? = { [weak resolver] postID in
                resolver?.resolve(Action.self, name: "navigateToPost", arguments: postID)
            }

            return MainActor.assumeIsolatedOrFatalError {
                HubRouteHandler(
                    coordinator: resolver.resolve(HubCoordinator.self)!,
                    presentPostActionProvider: presentPostActionProvider,
                    navigateToPostActionProvider: navigateToPostActionProvider
                )
            }
        }

        // MARK: SyncParticipant (notifications)

        container.register(SyncParticipant.self, name: "notifications") { resolver in
            NotificationsSyncParticipant(
                store: resolver.resolve(NotificationStore.self)!
            )
        }

        // MARK: Hub

        container.register(InboxPersistentContainer.self, scope: .singleton) { resolver in
            InboxPersistentContainer(storage: .persistent)
        }

        container.register(InboxSync.self, scope: .singleton) { resolver in
            return MainActor.assumeIsolatedOrFatalError {
                InboxSync(
                    persistentContainer: resolver.resolve(InboxPersistentContainer.self)!,
                    httpClient: resolver.resolve(HTTPClient.self)!
                )
            }
        }

        container.register(HubCoordinator.self, scope: .singleton) { resolver in
            return MainActor.assumeIsolatedOrFatalError {
                HubCoordinator(
                    configManager: resolver.resolve(ConfigManager.self)!,
                    homeViewManager: resolver.resolve(HomeViewManager.self)!
                )
            }
        }

        if updateAppBadge {
            container.register(RoverBadge.self, scope: .singleton) { resolver in
                return MainActor.assumeIsolatedOrFatalError {
                    RoverBadge(
                        persistentContainer: resolver.resolve(InboxPersistentContainer.self)!,
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

            let hubHandler = resolver.resolve(RouteHandler.self, name: "hub")!
            router.addHandler(hubHandler)
        }

        let store = resolver.resolve(NotificationStore.self)!
        store.restore()

        // start up persistence and sync for comms hub
        let commSync = resolver.resolve(InboxSync.self)!

        resolver.resolve(SyncCoordinator.self)!.registerStandaloneParticipant(commSync)

        let syncParticipant = resolver.resolve(SyncParticipant.self, name: "notifications")!
        resolver.resolve(SyncCoordinator.self)!.participants.append(syncParticipant)
    }
}

private extension MainActor {
    static func assumeIsolatedOrFatalError<T>(_ operation: @MainActor () -> T) -> T where T: Sendable {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                operation()
            }
        } else {
            fatalError("Rover must be initialized on the main thread")
        }
    }
}
