//
//  OpenNotificationAction.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-06-19.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit
#if !COCOAPODS
import RoverFoundation
import RoverData
#endif

class OpenNotificationAction: Action {
    let eventQueue: EventQueue
    let notification: Notification
    let notificationStore: NotificationStore
    
    typealias ActionProvider = (URL) -> Action?
    
    let presentWebsiteActionProvider: ActionProvider
    
    init(eventQueue: EventQueue, notification: Notification, notificationStore: NotificationStore, presentWebsiteActionProvider: @escaping ActionProvider) {
        self.eventQueue = eventQueue
        self.notification = notification
        self.notificationStore = notificationStore
        self.presentWebsiteActionProvider = presentWebsiteActionProvider

        super.init()
        name = "Open Notification"
    }
    
    override func execute() {
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
            if let action = presentWebsiteActionProvider(url) {
                produceAction(action)
            }
        }
        
        let eventInfo = notification.openedEvent(source: .pushNotification)
        eventQueue.addEvent(eventInfo)
        finish()
    }
}
