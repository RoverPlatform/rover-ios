//
//  InfluenceTrackerService.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-03-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

class InfluenceTrackerService: InfluenceTracker {
    let influenceTime: Int
    let eventQueue: EventQueue?
    let notificationCenter: NotificationCenter
    let userDefaults: UserDefaults
    
    var didBecomeActiveObserver: NSObjectProtocol?
    
    init(influenceTime: Int, eventQueue: EventQueue?, notificationCenter: NotificationCenter, userDefaults: UserDefaults) {
        self.influenceTime = influenceTime
        self.eventQueue = eventQueue
        self.notificationCenter = notificationCenter
        self.userDefaults = userDefaults
    }
    
    func startMonitoring() {
        #if swift(>=4.2)
        didBecomeActiveObserver = notificationCenter.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { _ in
            self.trackInfluencedOpen()
        }
        #else
        didBecomeActiveObserver = notificationCenter.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: nil) { _ in
            self.trackInfluencedOpen()
        }
        #endif
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
        
        struct NotificationReceipt: AttributeRepresentable, Decodable {
            var notificationID: ID
            var campaignID: ID
            var receivedAt: Date
            
            var attributeValue: AttributeValue {
                return [
                    "id": notificationID,
                    "campaignID": campaignID
                ]
            }
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
            "notification": lastReceivedNotification,
            "source": NotificationSource.influencedOpen.rawValue
        ]
        
        let event = EventInfo(name: "Notification Opened", namespace: "rover", attributes: attributes)
        eventQueue.addEvent(event)
    }
}
