//
//  InfluenceTrackerService.swift
//  RoverCampaigns
//
//  Created by Sean Rucker on 2018-03-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

class InfluenceTrackerService: InfluenceTracker {
    let influenceTime: Int
    let eventPipeline: EventPipeline?
    let notificationCenter: NotificationCenter
    let userDefaults: UserDefaults
    
    var didBecomeActiveObserver: NSObjectProtocol?
    
    init(influenceTime: Int, eventPipeline: EventPipeline?, notificationCenter: NotificationCenter, userDefaults: UserDefaults) {
        self.influenceTime = influenceTime
        self.eventPipeline = eventPipeline
        self.notificationCenter = notificationCenter
        self.userDefaults = userDefaults
    }
    
    deinit {
        self.stopMonitoring()
    }
    
    func startMonitoring() {
        #if swift(>=4.2)
        self.didBecomeActiveObserver = notificationCenter.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.trackInfluencedOpen()
        }
        #else
        self.didBecomeActiveObserver = notificationCenter.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.trackInfluencedOpen()
        }
        #endif
    }
    
    func stopMonitoring() {
        if let didBecomeActiveObserver = self.didBecomeActiveObserver {
            notificationCenter.removeObserver(didBecomeActiveObserver)
        }
    }
    
    func trackInfluencedOpen() {
        guard let data = userDefaults.value(forKey: "io.rover.lastReceivedNotification") as? Data else {
            return
        }
        
        defer {
            clearLastReceivedNotification()
        }
        
        struct NotificationReceipt: Decodable {
            var notificationID: String
            var campaignID: String
            var receivedAt: Date
            
            var attributes: Attributes {
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
        
        guard let eventPipeline = self.eventPipeline else {
            return
        }
        
        let attributes: Attributes = [
            "notification": lastReceivedNotification,
            "source": NotificationSource.influencedOpen.rawValue
        ]
        
        let event = EventInfo(name: "Notification Opened", namespace: "rover", attributes: attributes)
        eventPipeline.addEvent(event)
    }
    
    func clearLastReceivedNotification() {
        userDefaults.removeObject(forKey: "io.rover.lastReceivedNotification")
    }
}