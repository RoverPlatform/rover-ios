//
//  NotificationService.swift
//  NotificationService
//
//  Created by Sean Rucker on 2019-04-30.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import RoverAppExtensions
import UserNotifications

// This is a standard `UNNotificationServiceExtension` implementation which is used for modifying the content of a remote notification before it's delivered to the user. 
class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            // Pass the notification content to Rover to configure "Rich Media" attachments before it is displayed to the user. Additionally, Rover will capture the delivered time for influence tracking.
            NotificationExtensionHelper(appGroup: "group.io.rover.Example")?.didReceive(request, withContent: bestAttemptContent)
            
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

}
