//
//  NotificationHandlerService.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-06-19.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UserNotifications

class NotificationHandlerService: NotificationHandler {
    let dispatcher: Dispatcher
    let influenceTracker: InfluenceTracker
    let actionProvider: (Notification) -> Action
    
    init(dispatcher: Dispatcher, influenceTracker: InfluenceTracker, actionProvider: @escaping (Notification) -> Action) {
        self.dispatcher = dispatcher
        self.actionProvider = actionProvider
        self.influenceTracker = influenceTracker
    }
    
    func handle(_ response: UNNotificationResponse, completionHandler: (() -> Void)?) -> Bool {
        // The app was opened directly from a push notification. Clear the last received
        // notification from the influence tracker so we don't erroneously track an influenced open.
        influenceTracker.clearLastReceivedNotification()
        
        guard let action = action(for: response) else {
            return false
        }
        
        dispatcher.dispatch(action, completionHandler: completionHandler)
        return true
    }
    
    func action(for response: UNNotificationResponse) -> Action? {
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
            return actionProvider(payload.rover.notification)
        } catch {
            return nil
        }
    }
}
