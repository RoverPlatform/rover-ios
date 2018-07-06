//
//  NotificationStore.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-05-07.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol NotificationStore {
    var notifications: [Notification] { get }
    
    func addObserver(block: @escaping ([Notification]) -> Void) -> NSObjectProtocol
    func removeObserver(_ token: NSObjectProtocol)
    
    func restore()
    func fetchNotifications(completionHandler: ((FetchNotificationsResult) -> Void)?)
    func addNotification(_ notification: Notification)
    func markNotificationDeleted(_ notificationID: ID)
    func markNotificationRead(_ notificationID: ID)
}
