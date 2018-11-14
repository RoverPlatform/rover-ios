//
//  UI.UNNotificationResponse.swift
//  RoverFoundation
//
//  Created by Andrew Clunis on 2018-11-14.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import UserNotifications

extension UNNotificationResponse {
    var roverNotification: Notification? {
        get {
            guard let data = try? JSONSerialization.data(withJSONObject: self.notification.request.content.userInfo, options: []) else {
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
}
