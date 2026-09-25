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

import Foundation
import RoverFoundation
import UIKit
import os.log

public extension Rover {
    var notificationHandler: NotificationHandler {
        resolve(NotificationHandler.self)!
    }

    var notificationStore: NotificationStore {
        resolve(NotificationStore.self)!
    }

    /// Use this object to obtain the badge state for the Inbox/Comunication Hub.
    ///
    /// The badge counts the unread posts and unread conversations with activity since the user
    /// last viewed the inbox. Counts above 9 are reported as `"9+"`.
    var roverBadge: RoverBadge {
        resolve(RoverBadge.self)!
    }

    /// Call this method from your ``UIApplicationDelegate``'s ``didReceiveRemoteNotification`` method.
    ///
    /// iOS calls that method when a `"content-available": 1`(aka silent) push notification is received, regardless of whether the app is in the foreground or background.
    ///
    /// If the notification was handled as Rover notification, Rover calls completionHandler for you and returns true.
    func didReceiveRemoteNotification(
        userInfo: [AnyHashable: Any],
        fetchCompletionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) -> Bool {
        guard let persistentContainer = self.resolve(InboxPersistentContainer.self) else {
            os_log(
                "Rover.didReceiveRemoteNotification: called before Rover is initialized (or RoverNotifications module missing)",
                log: .notifications,
                type: .error
            )
            return false
        }
        // Check if this is a Rover notification using the Hub container
        if persistentContainer.receiveFromPush(userInfo: userInfo) {
            // rover handled the notification.
            fetchCompletionHandler(.newData)
            return true
        }

        return false
    }

    /// Call this method from your ``UNUserNotificationCenterDelegate``'s ``UNUserNotificationCenterDelegate/userNotificationCenter(_:willPresent:withCompletionHandler:)`` method.
    ///
    /// iOS calls that method when a push notification is received while the app is in the foreground.
    ///
    /// If the notification was handled as Rover notification, Rover calls completionHandler for you and returns true.
    func userNotificationCenterWillPresent(
        notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) -> Bool {
        guard let persistentContainer = self.resolve(InboxPersistentContainer.self) else {
            os_log(
                "Rover.willPresent: called before Rover is initialized (or RoverNotifications module missing)",
                log: .notifications,
                type: .error
            )
            return false
        }

        var handledByRover: Bool = false

        // handle a legacy inbox notification if one is present.
        if let roverNotification = notification.roverNotification {
            // If it's a Rover notification, add it to the Rover Notification Center immediately. This means if the app is currently open to the notification center the table view can live update to include it immediately.
            Rover.shared.notificationStore.addNotifications([roverNotification])
            handledByRover = true
        }

        let userInfo = notification.request.content.userInfo
        if persistentContainer.receiveFromPush(userInfo: userInfo) {
            handledByRover = true
        }

        guard handledByRover else {
            return false
        }

        // Read the currently displayed conversation ID on the main thread (where
        // UNUserNotificationCenterDelegate callbacks are always delivered) before
        // passing it into the actor-agnostic service method.
        let displayedConversationID = MainActor.assumeIsolated {
            resolve(HubCoordinator.self)?.displayedConversationID
        }

        completionHandler(
            resolve(NotificationHandler.self)?.willPresent(
                userInfo: userInfo,
                displayedConversationID: displayedConversationID
            ) ?? defaultNotificationPresentationOptions
        )

        return true
    }

    /// Call this method from your ``UNUserNotificationCenterDelegate``'s ``UNUserNotificationCenterDelegate/userNotificationCenter(_:didReceive:withCompletionHandler:)`` method.
    ///
    /// iOS calls that method when a push notification is tapped by the user.
    ///
    /// If the notification was handled as Rover notification, Rover calls completionHandler for you and returns true.
    func userNotificationCenterDidReceive(
        response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) -> Bool {
        guard let notificationHandler = Rover.shared.resolve(NotificationHandler.self) else {
            os_log(
                "Rover.userNotificationCenterDidReceive: called before NotificationHandler is initialized",
                log: .notifications,
                type: .error
            )
            return false
        }

        return notificationHandler.handle(response, completionHandler: completionHandler)
    }

    /// Reset all data in the Rover Hub.
    ///
    /// Every locally stored Hub row is dropped, so the Hub is usable immediately: it shows an
    /// empty inbox and refetches from the server on its next appearance. No restart is required.
    ///
    /// This is the same coordinated reset the SDK runs when the server declares the local Hub
    /// stale (HTTP 410): the sync epoch moves first, so a response already in flight cannot
    /// repopulate what is about to be dropped, and the Hub's in-flight sync work is cancelled.
    ///
    /// Call from any thread. The rows are gone by the time this returns — which is what lets a
    /// caller reset and then exit the process. Off the main thread, the drop is bridged
    /// synchronously onto it, so don't call this from a worker the main thread is itself
    /// blocked waiting on.
    func resetHub() {
        guard let coordinator = self.resolve(HubSyncCoordinator.self) else {
            os_log(
                "Rover.resetHub: called before Rover is initialized (or RoverNotifications module missing)",
                log: .hub,
                type: .error
            )
            return
        }

        if Thread.isMainThread {
            MainActor.assumeIsolated {
                coordinator.resetHubDataOnDemand()
            }
        } else {
            DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    coordinator.resetHubDataOnDemand()
                }
            }
        }
    }

    func resetCommunicationHub() {
        resetHub()
    }
}
