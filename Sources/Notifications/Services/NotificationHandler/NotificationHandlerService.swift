//
//  NotificationHandlerService.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-06-19.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UserNotifications
#if !COCOAPODS
import RoverFoundation
#endif

class NotificationHandlerService: NotificationHandler {
    let dispatcher: Dispatcher
    let influenceTracker: InfluenceTracker
    
    typealias ActionProvider = (Notification) -> Action?
    
    let actionProvider: ActionProvider
    
    init(dispatcher: Dispatcher, influenceTracker: InfluenceTracker, actionProvider: @escaping ActionProvider) {
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
        
        dispatcher.dispatch(action) {
            DispatchQueue.main.async {
                completionHandler?()
            }
        }
        return true
    }
    
    func action(for response: UNNotificationResponse) -> Action? {
        guard let notification = response.notification.roverNotification else {
            return nil
        }
        return actionProvider(notification)
    }
}

public extension UNNotification {
    /// Decode the Rover notification in the APNS UNNotification, if it contains one.
    var roverNotification: Notification? {
        guard let data = try? JSONSerialization.data(withJSONObject: self.request.content.userInfo, options: []) else {
            return nil
        }
        
        struct Payload: Decodable {
            struct Rover: Decodable {
                var notification: Notification
            }
            
            var rover: Rover
        }
        
        do {
            return try JSONDecoder.default.decode(Payload.self, from: data).rover.notification
        } catch {
            return nil
        }
    }
}
