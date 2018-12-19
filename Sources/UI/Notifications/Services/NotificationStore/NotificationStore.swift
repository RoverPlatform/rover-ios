//
//  NotificationStore.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-05-07.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol NotificationStore {
    
    // TODO: replace this with returning a fetch request or similar?
    var notifications: [RoverData.Notification] { get }
    
    func addObserver(block: @escaping ([RoverData.Notification]) -> Void) -> NSObjectProtocol
    func removeObserver(_ token: NSObjectProtocol)
    
    func restore()
    func addNotifications(_ notifications: [RoverData.Notification])
    func markNotificationDeleted(_ notificationID: String)
    func markNotificationRead(_ notificationID: String)
}

extension NotificationStore {
    public func addNotification(_ notification: RoverData.Notification) {
        addNotifications([notification])
    }
}
