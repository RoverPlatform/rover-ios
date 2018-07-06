//
//  InfluenceTrackerService.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-03-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

class InfluenceTrackerService: InfluenceTracker {
    let influenceTime: Int
    let eventQueue: EventQueue?
    let logger: Logger
    let notificationCenter: NotificationCenter
    let userDefaults: UserDefaults
    
    var didBecomeActiveObserver: NSObjectProtocol?
    
    init(influenceTime: Int, eventQueue: EventQueue?, logger: Logger, notificationCenter: NotificationCenter, userDefaults: UserDefaults) {
        self.influenceTime = influenceTime
        self.eventQueue = eventQueue
        self.logger = logger
        self.notificationCenter = notificationCenter
        self.userDefaults = userDefaults
    }
    
    func startMonitoring() {
        didBecomeActiveObserver = notificationCenter.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: nil) { _ in
            self.trackInfluencedOpen()
        }
    }
    
    func stopMonitoring() {
        guard let didBecomeActiveObserver = didBecomeActiveObserver else {
            return
        }
        
        notificationCenter.removeObserver(didBecomeActiveObserver)
    }
    
    func trackInfluencedOpen() {
        guard let data = userDefaults.value(forKey: "io.rover.lastReceivedNotification") as? Data else {
            return
        }
        
        struct NotificationReceipt: Decodable {
            var notificationID: ID
            var campaignID: ID
            var receivedAt: Date
        }
        
        guard let lastReceivedNotification = try? PropertyListDecoder().decode(NotificationReceipt.self, from: data) else {
            return
        }
        
        let now = Date().timeIntervalSince1970
        
        // If its been more than the alloted influence time since the notification was received, don't consider this an influenced open
        
        if now - lastReceivedNotification.receivedAt.timeIntervalSince1970 > TimeInterval(influenceTime) {
            return
        }
        
        guard let eventQueue = eventQueue else {
            return
        }
        
        let attributes: Attributes = [
            "notificationID": lastReceivedNotification.notificationID.rawValue,
            "campaignID": lastReceivedNotification.campaignID.rawValue,
            "source": NotificationSource.influencedOpen.rawValue
        ]
        
        let event = EventInfo(name: "Notification Opened", namespace: "rover", attributes: attributes)
        eventQueue.addEvent(event)
    }
}
