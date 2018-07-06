//
//  FetchNotificationsResult.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-05-07.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public enum FetchNotificationsResult {
    case error(error: Error?, isRetryable: Bool)
    case success(notifications: [Notification])
}
