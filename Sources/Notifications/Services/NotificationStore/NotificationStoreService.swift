//
//  NotificationStoreService.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-03-07.
//  Copyright © 2018 Sean Rucker. All rights reserved.
//

import os.log
import UIKit
#if !COCOAPODS
import RoverFoundation
import RoverData
#endif

class NotificationStoreService: NotificationStore {
    let eventQueue: EventQueue?
    
    let userDefaults: UserDefaults
    
    let maxSize: Int
    
    var notifications = [Notification]() {
        didSet {
            observers.notify(parameters: notifications)
        }
    }
    
    var observers = ObserverSet<[Notification]>()
    var stateObservation: NSObjectProtocol?
    
    init(maxSize: Int, eventQueue: EventQueue?, userDefaults: UserDefaults) {
        self.maxSize = maxSize
        self.eventQueue = eventQueue
        self.userDefaults = userDefaults
    }
    
    // MARK: Observers
    
    func addObserver(block: @escaping ([Notification]) -> Void) -> NSObjectProtocol {
        return observers.add(block: block)
    }
    
    func removeObserver(_ token: NSObjectProtocol) {
        observers.remove(token: token)
    }
    
    // MARK: File Storage
    
    var cache: URL? {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("notifications").appendingPathExtension("plist")
    }
    
    func restore() {
        os_log("Restoring notifications from cache", log: .notifications, type: .debug)
        
        guard let cache = cache else {
            os_log("Failed to restore notifications from cache: Cache not found", log: .notifications, type: .error)
            return
        }
        
        if !FileManager.default.fileExists(atPath: cache.path) {
            os_log("Cache is empty, no notifications to restore", log: .notifications, type: .debug)
            return
        }
        
        do {
            let data = try Data(contentsOf: cache)
            notifications = try PropertyListDecoder().decode([Notification].self, from: data)
            os_log("%d notification(s) restored from cache", log: .notifications, type: .debug, notifications.count)
        } catch {
            os_log("Failed to restore notifications from cache: %@", log: .notifications, type: .error, error.logDescription)
        }
    }
    
    func persist() {
        os_log("Persisting notifications to cache...", log: .notifications, type: .debug)
        
        guard let cache = cache else {
            os_log("Cache not found", log: .notifications, type: .error)
            return
        }
        
        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml
            let data = try encoder.encode(notifications)
            try data.write(to: cache, options: [.atomic])
            
            // now store a computed unread count in app-group scoped UserDefaults so it is available in the Notification Extension.
            let unreadCount = notifications.filter { !$0.isRead }.count
            userDefaults.set(unreadCount, forKey: "io.rover.unreadNotifications")
            os_log("Cache now contains notification(s)", log: .notifications, type: .debug, notifications.count)
        } catch {
            os_log("Failed to persist notifications to cache: %@", log: .notifications, type: .error, error.logDescription)
        }
    }
    
    // MARK: Adding Notifications
    
    func addNotifications(_ notifications: [Notification]) {
        let map: ([Notification]) -> [String: Notification] = { notifications in
            let ids = notifications.map { $0.id }
            let zipped = zip(ids, notifications)
            return Dictionary(zipped) { a, _ in
                a
            }
        }
        
        let existing = map(self.notifications)
        let new = map(notifications)
        let merged = existing.merging(new) {
            var notification = $1
            notification.isRead = $0.isRead || $1.isRead
            notification.isDeleted = $0.isDeleted || $1.isDeleted
            return notification
        }
        
        let sorted = merged.values.sorted { $0.deliveredAt > $1.deliveredAt }
        let trimmed = sorted.prefix(maxSize)
        self.notifications = Array(trimmed)
        persist()
    }
    
    // MARK: Updating Notifications
    
    func markNotificationDeleted(_ notificationID: String) {
        guard let notification = notifications.first(where: { $0.id == notificationID }) else {
            return
        }
        
        notifications = notifications.map {
            if $0.id != notification.id {
                return $0
            }
            
            var notification = $0
            notification.isDeleted = true
            return notification
        }
        
        persist()
        
        guard let eventQueue = eventQueue else {
            return
        }
        
        let attributes: Attributes = ["notification": notification.attributes]
        let event = EventInfo(name: "Notification Marked Deleted", namespace: "rover", attributes: attributes)
        eventQueue.addEvent(event)
    }
    
    func markNotificationRead(_ notificationID: String) {
        guard let notification = notifications.first(where: { $0.id == notificationID }) else {
            return
        }
        
        notifications = notifications.map {
            if $0.id != notification.id {
                return $0
            }
            
            var notification = $0
            notification.isRead = true
            return notification
        }
        
        persist()
        
        guard let eventQueue = eventQueue else {
            return
        }
        
        let attributes: Attributes = ["notification": notification.attributes]
        let event = EventInfo(name: "Notification Marked Read", namespace: "rover", attributes: attributes)
        eventQueue.addEvent(event)
    }
}
