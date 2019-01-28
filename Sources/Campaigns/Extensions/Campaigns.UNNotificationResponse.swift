//
//  Campaigns.UNNotificationResponse.swift
//  RoverCampaigns
//
//  Created by Andrew Clunis on 2018-11-14.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import UserNotifications

extension UNNotificationResponse {
    // TODO change to return a campaign.
    var roverNotification: RoverUI.Notification? {
        guard let data = try? JSONSerialization.data(withJSONObject: self.notification.request.content.userInfo, options: []) else {
            return nil
        }

        struct Payload: Decodable {
            struct Rover: Decodable {
                // TODO: a campaign will go here, if anything.
            }

            var rover: Rover
        }

        // TODO: replace once again with decoding the campaign.
        return RoverData.Notification()
    }
}
