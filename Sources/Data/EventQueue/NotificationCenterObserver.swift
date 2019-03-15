//
//  NotificationCenterObserver.swift
//  RoverCampaignsData
//
//  Created by Andrew Clunis on 2019-03-12.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import os

/// Responsible for listening to specially crafted events emitted on the iOS Notification Center (an event bus built into iOS) so that affilianted modules that are not linked against RoverCampaigns (and thus do not have access to its types) are still able to track events.
public class NotificationCenterObserver {
    // The naming convention for NotificationCenter events is "did" or "will".
    
    // Explicit? ExperienceDidEmitEvent
    // Open-ended? RoverEmitterDidEmitEvent
    
    let eventQueue: EventQueue
    var notificationCenterObserverChit: NSObjectProtocol?
    
    init(
        eventQueue: EventQueue
    ) {
        self.eventQueue = eventQueue
    }
    
    public func startListening() {
        if notificationCenterObserverChit != nil {
            return
        }
        let name = Notification.Name("RoverEmitterDidEmitEvent")
        self.notificationCenterObserverChit = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] notification in
            guard let userInfo = notification.userInfo else {
                return
            }
            guard let name = userInfo["name"] as? String else {
                os_log("Rover event sent via Notification Center lacked its `name` field.")
                return
            }
            let namespace = userInfo["namespace"] as? String
            
            let attributes: Attributes?
            if let attributesHash = userInfo["attributes"] as? [String: Any] {
                attributes = Attributes(rawValue: attributesHash)
            } else {
                attributes = nil
            }
            
            let eventInfo = EventInfo(
                name: name,
                namespace: namespace,
                attributes: attributes,
                timestamp: Date()
            )
            self?.eventQueue.addEvent(eventInfo)
        }
    }
}
