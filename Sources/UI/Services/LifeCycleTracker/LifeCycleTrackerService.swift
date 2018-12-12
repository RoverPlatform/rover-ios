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
    
    var didBecomeActiveObserver: NSObjectProtocol?
    var willResignActiveObserver: NSObjectProtocol?
    
    init(eventQueue: EventQueue, sessionController: SessionController) {
        self.eventQueue = eventQueue
        self.sessionController = sessionController
    }
    
    func enable() {
        self.sessionController.registerSession(identifier: "application") { duration in
            let attributes: Attributes = ["duration": duration]
            return EventInfo(name: "App Viewed", namespace: "rover", attributes: attributes)
        }
        
        #if swift(>=4.2)
        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: OperationQueue.main) { [weak self] _ in
            let event = EventInfo(name: "App Opened", namespace: "rover")
            self?.eventQueue.addEvent(event)
        }
        
        self.willResignActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: OperationQueue.main) { [weak self] _ in
            let event = EventInfo(name: "App Closed", namespace: "rover")
            self?.eventQueue.addEvent(event)
        }
        #else
        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: OperationQueue.main) { [weak self] _ in
            let event = EventInfo(name: "App Opened", namespace: "rover")
            self?.eventQueue.addEvent(event)
        }
        
        self.willResignActiveObserver = NotificationCenter.default.addObserver(forName: .UIApplicationWillResignActive, object: nil, queue: OperationQueue.main) { [weak self] _ in
            let event = EventInfo(name: "App Closed", namespace: "rover")
            self?.eventQueue.addEvent(event)
        }
        #endif
    }
    
    func disable() {
        self.sessionController.unregisterSession(identifier: "application")
    
        if let didBecomeActiveObserver = didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
            self.didBecomeActiveObserver = nil
        }
        
        if let willResignActiveObserver = willResignActiveObserver {
            NotificationCenter.default.removeObserver(willResignActiveObserver)
            self.willResignActiveObserver = nil
        }
    }
    
    deinit {
        self.disable()
    }
}
