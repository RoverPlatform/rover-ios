//
//  NotificationAuthorizationManager.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-02-08.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UserNotifications
#if !COCOAPODS
import RoverFoundation
import RoverData
#endif

class NotificationAuthorizationManager {
    let authorizationStatus = PersistedValue<Int>(storageKey: "io.rover.RoverNotifications.authorizationStatus")
    let userNotificationCenter = UNUserNotificationCenter.current()
    
    init() { }
}

extension NotificationAuthorizationManager: NotificationsContextProvider {
    var notificationAuthorization: String {
        // Refresh status for _next_ time context is requested
        userNotificationCenter.getNotificationSettings { settings in
            self.authorizationStatus.value = settings.authorizationStatus.rawValue
        }
        
        let authorizationStatus: UNAuthorizationStatus = {
            guard let value = self.authorizationStatus.value, let authorizationStatus = UNAuthorizationStatus(rawValue: value) else {
                return  .notDetermined
            }
            
            return authorizationStatus
        }()
        
        switch authorizationStatus {
        case .authorized:
            return "authorized"
        case .denied:
            return "denied"
        case .notDetermined:
            return "notDetermined"
        case .provisional:
            return "provisional"
        #if swift(>=5.3)
        case .ephemeral:
            return "ephemeral"
        #endif
        @unknown default:
            return "notDetermined"
        }
    }
}
