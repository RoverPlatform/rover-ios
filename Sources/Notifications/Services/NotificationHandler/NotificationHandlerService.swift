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
    let actionProvider: (Notification) -> Action
    
    init(dispatcher: Dispatcher, actionProvider: @escaping (Notification) -> Action) {
        self.dispatcher = dispatcher
        self.actionProvider = actionProvider
    }
    
    func handle(_ response: UNNotificationResponse, completionHandler: (() -> Void)?) -> Bool {
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
