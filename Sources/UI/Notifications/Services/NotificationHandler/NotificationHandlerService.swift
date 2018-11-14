//
//  NotificationHandlerService.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-06-19.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UserNotifications
import UIKit
import os

class NotificationHandlerService: NotificationHandler {
    let influenceTracker: InfluenceTracker
    let notificationStore: NotificationStore
    let eventQueue: EventQueue
    
    init(influenceTracker: InfluenceTracker, notificationStore: NotificationStore, eventQueue: EventQueue) {
        self.influenceTracker = influenceTracker
        self.notificationStore = notificationStore
        self.eventQueue = eventQueue
    }
    
    func handle(_ response: UNNotificationResponse) -> Bool {
        // The app was opened directly from a push notification. Clear the last received
        // notification from the influence tracker so we don't erroneously track an influenced open.
        influenceTracker.clearLastReceivedNotification()
        
        guard let notification = response.roverNotification else {
            return false
        }
        
        notificationStore.addNotification(notification)
        
        if !notification.isRead {
            notificationStore.markNotificationRead(notification.id)
        }
        
        switch notification.tapBehavior {
        case .openApp:
            break
        case .openURL(let url):
            DispatchQueue.main.sync {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        
        case .presentWebsite(let url):
            // TODO
            os_log("TODO .presentWebsite currently NOT IMPLEMENTED.", log: .general, type: .error)
//            if let action = presentWebsiteActionProvider(url) {
//                produceAction(action)
//            }
        }
        
        let eventInfo = notification.openedEvent(source: .pushNotification)
        eventQueue.addEvent(eventInfo)
        
        return true
    }
}
