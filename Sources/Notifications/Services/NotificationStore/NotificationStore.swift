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
    func addNotifications(_ notifications: [Notification])
    func markNotificationDeleted(_ notificationID: String)
    func markNotificationRead(_ notificationID: String)
}

extension NotificationStore {
    public func addNotification(_ notification: Notification) {
        addNotifications([notification])
    }
}
