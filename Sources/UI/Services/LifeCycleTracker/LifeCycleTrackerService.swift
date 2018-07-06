//
//  LifeCycleTrackerService.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-06-12.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

class LifeCycleTrackerService: LifeCycleTracker {
    let eventQueue: EventQueue
    let sessionController: SessionController
    
    var applicationDidBecomeActiveToken: NSObjectProtocol?
    var applicationWillResignActiveToken: NSObjectProtocol?
    
    init(eventQueue: EventQueue, sessionController: SessionController) {
        self.eventQueue = eventQueue
        self.sessionController = sessionController
    }
    
    func enable() {
        sessionController.registerSession(identifier: "application") { duration in
            let attributes: Attributes = ["duration": duration]
            return EventInfo(name: "App Viewed", namespace: "rover", attributes: attributes)
        }
        
        applicationDidBecomeActiveToken = NotificationCenter.default.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: OperationQueue.main) { [weak self] _ in
            let event = EventInfo(name: "App Opened", namespace: "rover")
            self?.eventQueue.addEvent(event)
        }
        
        applicationWillResignActiveToken = NotificationCenter.default.addObserver(forName: .UIApplicationWillResignActive, object: nil, queue: OperationQueue.main) { [weak self] _ in
            let event = EventInfo(name: "App Closed", namespace: "rover")
            self?.eventQueue.addEvent(event)
        }
    }
    
    func disable() {
        sessionController.unregisterSession(identifier: "application")
    
        if let applicationDidBecomeActiveToken = applicationDidBecomeActiveToken {
            NotificationCenter.default.removeObserver(applicationDidBecomeActiveToken)
        }
        
        if let applicationWillResignActiveToken = applicationWillResignActiveToken {
            NotificationCenter.default.removeObserver(applicationWillResignActiveToken)
        }
    }
}
