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
import UIKit
import RoverFoundation
import os.log

public extension Rover {
    var notificationHandler: NotificationHandler {
        get {
            resolve(NotificationHandler.self)!
        }
    }
    
    var notificationStore: NotificationStore {
        get {
            resolve(NotificationStore.self)!
        }
    }

    /// Use this object to obtain the badge state for the Inbox/Comunication Hub.
    var roverBadge: RoverBadge {
        get {
            resolve(RoverBadge.self)!
        }
    }

    /// Call this method from your ``UIApplicationDelegate``'s ``didReceiveRemoteNotification`` method.
    ///
    /// iOS calls that method when a `"content-available": 1`(aka silent) push notification is received, regardless of whether the app is in the foreground or background.
    ///
    /// If the notification was handled as Rover notification, Rover calls completionHandler for you and returns true.
    func didReceiveRemoteNotification(userInfo: [AnyHashable: Any], fetchCompletionHandler: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {
        guard let persistentContainer = self.resolve(InboxPersistentContainer.self) else {
            os_log("Rover.didReceiveRemoteNotification: called before Rover is initialized (or RoverNotifications module missing)", log: .notifications, type: .error)
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
    func userNotificationCenterWillPresent(notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) -> Bool {
        guard let persistentContainer = self.resolve(InboxPersistentContainer.self) else {
            os_log("Rover.willPresent: called before Rover is initialized (or RoverNotifications module missing)", log: .notifications, type: .error)
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

        if handledByRover {
            completionHandler([.sound, .banner])
        }

        return handledByRover
    }

    /// Call this method from your ``UNUserNotificationCenterDelegate``'s ``UNUserNotificationCenterDelegate/userNotificationCenter(_:didReceive:withCompletionHandler:)`` method.
    /// 
    /// iOS calls that method when a push notification is tapped by the user.
    ///
    /// If the notification was handled as Rover notification, Rover calls completionHandler for you and returns true.
    func userNotificationCenterDidReceive(response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) -> Bool {
        guard let notificationHandler = Rover.shared.resolve(NotificationHandler.self) as? NotificationHandlerService else {
            os_log("Rover.userNotificationCenterDidReceive: called before NotificationHandler is initialized", log: .notifications, type: .error)
            return false
        }
        
        return notificationHandler.handle(response, completionHandler: completionHandler)
    }

    /// Reset all data in the Rover Hub.
    /// 
    /// Note that this will leave the store in a dropped state, and the app (and Rover SDK) should be restarted afterward.
    func resetHub() {
        let container = self.resolve(InboxPersistentContainer.self)
        container?.reset()
    }

    func resetCommunicationHub() {
        resetHub()
    }
}
