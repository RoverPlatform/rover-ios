//
//  NotificationAuthorizationContextProvider.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-02-08.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UserNotifications

class NotificationAuthorizationContextProvider: ContextProvider {
    let userNotificationCenter: UNUserNotificationCenter
    
    internal private(set) var authorizationStatus: String?
    
    init(userNotificationCenter: UNUserNotificationCenter) {
        self.userNotificationCenter = userNotificationCenter
    }
    
    func refreshAuthorizationStatus() {
        userNotificationCenter.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized:
                self.authorizationStatus = "authorized"
            case .denied:
                self.authorizationStatus = "denied"
            case .notDetermined:
                self.authorizationStatus = "notDetermined"
            }
        }
    }
    
    func captureContext(_ context: Context) -> Context {
        var nextContext = context
        nextContext.notificationAuthorization = authorizationStatus
        
        // Refresh on context capture ensures NEXT capture has up to date value. This is an acceptable tradeoff to keep context providers synchronous
        refreshAuthorizationStatus()
        
        return nextContext
    }
}
