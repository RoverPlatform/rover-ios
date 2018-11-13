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
    let dispatcher: Dispatcher
    let influenceTracker: InfluenceTracker
    
    typealias ActionProvider = (Notification) -> Action?
    let actionProvider: ActionProvider
    let notificationStore: NotificationStore
    let eventQueue: EventQueue
    
    init(dispatcher: Dispatcher, influenceTracker: InfluenceTracker, actionProvider: @escaping ActionProvider, notificationStore: NotificationStore, eventQueue: EventQueue) {
        self.dispatcher = dispatcher
        self.actionProvider = actionProvider
        self.influenceTracker = influenceTracker
        self.notificationStore = notificationStore
        self.eventQueue = eventQueue
    }
    
    
    
    func handle(_ response: UNNotificationResponse, completionHandler: (() -> Void)?) -> Bool {
        // The app was opened directly from a push notification. Clear the last received
        // notification from the influence tracker so we don't erroneously track an influenced open.
        influenceTracker.clearLastReceivedNotification()
        
        guard let notification = notification(for: response) else {
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
        completionHandler?()
        
        return true
    }
    
    func notification(for response: UNNotificationResponse) -> Notification? {
        guard let data = try? JSONSerialization.data(withJSONObject: response.notification.request.content.userInfo, options: []) else {
            return nil
        }
        
        struct Payload: Decodable {
            struct Rover: Decodable {
                var notification: Notification
            }
            
            var rover: Rover
        }
        
        do {
            let payload = try JSONDecoder.default.decode(Payload.self, from: data)
            return payload.rover.notification
        } catch {
            return nil
        }
    }
}
