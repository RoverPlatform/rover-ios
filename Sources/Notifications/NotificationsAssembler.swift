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
        appGroup: String? = nil,
        isInfluenceTrackingEnabled: Bool = true,
        influenceTime: Int = 120,
        maxNotifications: Int = 200,
        updateAppBadge: Bool = true
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
                Action.self,
                name: "presentView",
                arguments: viewControllerToPresent as UIViewController
            )!
        }

        // MARK: Action (presentPost)

        container.register(Action.self, name: "presentPost", scope: .transient) { (resolver, postID: String?) in

            let viewControllerToPresent = ShowPostHostingController(
                postID: postID,
            )

            os_log("Presenting Post Detail", log: .hub, type: .debug)

            return resolver.resolve(
                Action.self,
                name: "presentView",
                arguments: viewControllerToPresent as UIViewController
            )!
        }

        // MARK: Action (presentConversation)

        container.register(Action.self, name: "presentConversation", scope: .transient) {
            (resolver, conversationID: UUID) in

            let viewControllerToPresent = ShowConversationHostingController(
                conversationID: conversationID
            )

            os_log("Presenting Conversation Detail", log: .hub, type: .debug)

            return resolver.resolve(
                Action.self,
                name: "presentView",
                arguments: viewControllerToPresent as UIViewController
            )!
        }

        // MARK: Action (navigateToPost)

        container.register(Action.self, name: "navigateToPost", scope: .transient) { (resolver, postID: String) in
            NavigateToPostAction(
                coordinator: resolver.resolve(HubCoordinator.self)!,
                postID: postID
            )
        }

        // MARK: Action (navigateToConversation)

        container.register(Action.self, name: "navigateToConversation", scope: .transient) {
            (resolver, conversationID: UUID) in
            NavigateToConversationAction(
                coordinator: resolver.resolve(HubCoordinator.self)!,
                conversationID: conversationID
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
            let notificationActionProvider: NotificationHandlerService.NotificationActionProvider = {
                [weak resolver] notification in
                resolver?.resolve(Action.self, name: "openNotification", arguments: notification)
            }

            let openURLActionProvider: NotificationHandlerService.URLActionProvider = { [weak resolver] url in
                resolver?.resolve(Action.self, name: "openURL", arguments: url)
            }

            return NotificationHandlerService(
                dispatcher: resolver.resolve(Dispatcher.self)!,
                influenceTracker: resolver.resolve(InfluenceTracker.self)!,
                notificationActionProvider: notificationActionProvider,
                openURLActionProvider: openURLActionProvider,
                replySync: resolver.resolve(ReplySync.self)!,
                inboxPersistentContainer: resolver.resolve(InboxPersistentContainer.self)
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

            let presentConversationActionProvider: (UUID) -> Action? = { [weak resolver] conversationID in
                resolver?.resolve(Action.self, name: "presentConversation", arguments: conversationID)
            }

            let navigateToConversationActionProvider: (UUID) -> Action? = { [weak resolver] conversationID in
                resolver?.resolve(Action.self, name: "navigateToConversation", arguments: conversationID)
            }

            return MainActor.assumeIsolatedOrFatalError {
                HubRouteHandler(
                    coordinator: resolver.resolve(HubCoordinator.self)!,
                    presentPostActionProvider: presentPostActionProvider,
                    navigateToPostActionProvider: navigateToPostActionProvider,
                    presentConversationActionProvider: presentConversationActionProvider,
                    navigateToConversationActionProvider: navigateToConversationActionProvider
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

        container.register(PostSync.self, scope: .singleton) { resolver in
            MainActor.assumeIsolatedOrFatalError {
                PostSync(
                    persistentContainer: resolver.resolve(InboxPersistentContainer.self)!,
                    hubSyncCoordinator: resolver.resolve(HubSyncCoordinator.self)!
                )
            }
        }

        container.register(HubSyncCoordinator.self, scope: .singleton) { resolver in
            MainActor.assumeIsolatedOrFatalError {
                HubSyncCoordinator(
                    httpClient: resolver.resolve(HTTPClient.self)!,
                    persistentContainer: resolver.resolve(InboxPersistentContainer.self)!
                )
            }
        }

        container.register(ConversationSync.self, scope: .singleton) { resolver in
            ConversationSync(
                persistentContainer: resolver.resolve(InboxPersistentContainer.self)!,
                hubSyncCoordinator: resolver.resolve(HubSyncCoordinator.self)!
            )
        }

        container.register(SubscriptionSync.self, scope: .singleton) { resolver in
            SubscriptionSync(
                persistentContainer: resolver.resolve(InboxPersistentContainer.self)!,
                hubSyncCoordinator: resolver.resolve(HubSyncCoordinator.self)!
            )
        }

        container.register(ParticipantSync.self, scope: .singleton) { resolver in
            ParticipantSync(
                persistentContainer: resolver.resolve(InboxPersistentContainer.self)!,
                hubSyncCoordinator: resolver.resolve(HubSyncCoordinator.self)!
            )
        }

        container.register(ReplySync.self, scope: .singleton) { resolver in
            ReplySync(
                persistentContainer: resolver.resolve(InboxPersistentContainer.self)!,
                hubSyncCoordinator: resolver.resolve(HubSyncCoordinator.self)!
            )
        }

        container.register(HubCoordinator.self, scope: .singleton) { resolver in
            return MainActor.assumeIsolatedOrFatalError {
                HubCoordinator(
                    configManager: resolver.resolve(ConfigManager.self)!,
                    homeViewManager: resolver.resolve(HomeViewManager.self)!,
                    notificationHandler: resolver.resolve(NotificationHandler.self)!
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

    /// The `UNNotificationCategory` objects that Rover requires to be registered with
    /// `UNUserNotificationCenter` for interactive notification features to work.
    ///
    /// Rover registers these automatically during SDK initialisation. However, if your app
    /// calls `UNUserNotificationCenter.current().setNotificationCategories(_:)` **after**
    /// calling `Rover.initialize(...)`, it will replace the registered set and remove
    /// Rover's categories. To avoid this, merge Rover's categories with your own:
    ///
    /// ```swift
    /// let categories = NotificationsAssembler.roverNotificationCategories
    ///     .union(myAppCategories)
    /// UNUserNotificationCenter.current().setNotificationCategories(categories)
    /// ```
    public static var roverNotificationCategories: Set<UNNotificationCategory> {
        let replyAction = UNTextInputNotificationAction(
            identifier: NotificationCategories.inlineReplyAction,
            title: "Reply",
            options: [],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Reply..."
        )
        let conversationReplyCategory = UNNotificationCategory(
            identifier: NotificationCategories.conversationReply,
            actions: [replyAction],
            intentIdentifiers: []
        )
        return [conversationReplyCategory]
    }

    public func containerDidAssemble(resolver: Resolver) {
        // Register Rover's notification categories by merging them into any categories the
        // host app has already registered. This handles the common case where Rover is
        // initialised before the host app sets its own categories.
        //
        // NOTE: If the host app calls setNotificationCategories *after* Rover initialises,
        // it must include Rover's categories — see `roverNotificationCategories` above.
        UNUserNotificationCenter.current().getNotificationCategories { existing in
            let merged = existing.union(NotificationsAssembler.roverNotificationCategories)
            UNUserNotificationCenter.current().setNotificationCategories(merged)
        }

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
        let syncCoordinator = resolver.resolve(SyncCoordinator.self)!

        let postSync = resolver.resolve(PostSync.self)!
        syncCoordinator.registerStandaloneParticipant(postSync)

        let replySync = resolver.resolve(ReplySync.self)!
        syncCoordinator.registerStandaloneParticipant(replySync)

        let conversationSync = resolver.resolve(ConversationSync.self)!
        syncCoordinator.registerStandaloneParticipant(conversationSync)

        let subscriptionSync = resolver.resolve(SubscriptionSync.self)!
        syncCoordinator.registerStandaloneParticipant(subscriptionSync)

        let participantSync = resolver.resolve(ParticipantSync.self)!
        syncCoordinator.registerStandaloneParticipant(participantSync)

        // HubSyncCoordinator is @MainActor (see its doc comment); containerDidAssemble is a
        // synchronous, main-thread call at SDK startup, so this bridges into that isolation
        // rather than hopping through an unstructured Task, preserving the guarantee that every
        // sync actor is registered before any sync can possibly start.
        let hubSyncCoordinator = resolver.resolve(HubSyncCoordinator.self)!
        MainActor.assumeIsolatedOrFatalError {
            hubSyncCoordinator.register(replySync)
            hubSyncCoordinator.register(conversationSync)
            hubSyncCoordinator.register(participantSync)
            hubSyncCoordinator.register(postSync)
            hubSyncCoordinator.register(subscriptionSync)
        }

        let syncParticipant = resolver.resolve(SyncParticipant.self, name: "notifications")!
        syncCoordinator.participants.append(syncParticipant)

        if updateAppBadge {
            _ = resolver.resolve(RoverBadge.self)
        }
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
