//
//  NotificationCenterSessionObserver.swift
//  RoverCampaignsUI
//
//  Created by Andrew Clunis on 2019-03-15.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import os

public class NotificationCenterSessionObserver {
    let sessionController: SessionController
    var openEventNotificationCenterObserverChit: NSObjectProtocol?
    var closeEventNotificationCenterObserverChit: NSObjectProtocol?
    
    init(
        sessionController: SessionController
    ) {
        self.sessionController = sessionController
    }
    
    public func startListening() {
        let openName = Notification.Name(rawValue: "RoverSessionDidOpen")
        let closeName = Notification.Name(rawValue: "RoverSessionDidClose")
        
        self.openEventNotificationCenterObserverChit = NotificationCenter.default.addObserver(forName: openName, object: nil, queue: nil) { [weak self] notification in
            guard let userInfo = notification.userInfo else {
                os_log("Rover session event sent via Notification Center lacked its `userInfo` field.", log: .events, type: .error)
                return
            }
            
            guard let sessionIdentifier = userInfo["sessionIdentifier"] as? String else {
                os_log("Rover session event sent via Notification Center lacked its `sessionIdentifier` field.", log: .events, type: .error)
                return
            }
            guard let name = userInfo["name"] as? String else {
                os_log("Rover session event sent via Notification Center lacked its `name` field.", log: .events, type: .error)
                return
            }
            let namespace = userInfo["namespace"] as? String
            let attributes: [String: Any] = userInfo["attributes"] as? [String: Any] ?? [String: Any]()
            
            self?.sessionController.registerSession(identifier: sessionIdentifier) { duration -> EventInfo in
                let attributesWithDuration = attributes.merging(["duration": duration]) { a, _ -> Any in
                    a
                }
                return EventInfo(
                    name: name,
                    namespace: namespace,
                    attributes: Attributes(rawValue: attributesWithDuration),
                    timestamp: Date()
                )
            }
        }
        
        self.closeEventNotificationCenterObserverChit = NotificationCenter.default.addObserver(forName: closeName, object: nil, queue: nil) { [weak self] notification in
            guard let userInfo = notification.userInfo else {
                os_log("Rover session event sent via Notification Center lacked its `userInfo` field.", log: .events, type: .error)
                return
            }
            
            guard let sessionIdentifier = userInfo["sessionIdentifier"] as? String else {
                os_log("Rover session event sent via Notification Center lacked its `sessionIdentifier` field.", log: .events, type: .error)
                return
            }
            self?.sessionController.unregisterSession(identifier: sessionIdentifier)
        }
    }
}
