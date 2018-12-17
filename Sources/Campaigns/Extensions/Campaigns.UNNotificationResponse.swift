//
//  UI.UNNotificationResponse.swift
//  RoverUI
//
//  Created by Andrew Clunis on 2018-11-14.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import UserNotifications

extension UNNotificationResponse {
    var roverNotification: RoverUI.Notification? {
        guard let data = try? JSONSerialization.data(withJSONObject: self.notification.request.content.userInfo, options: []) else {
            return nil
        }
        
        struct Payload: Decodable {
            struct Rover: Decodable {
                var notification: RoverUI.Notification
            }
            
            var rover: Rover
        }
        
        return try? JSONDecoder.default.decode(Payload.self, from: data).rover.notification
    }
}
