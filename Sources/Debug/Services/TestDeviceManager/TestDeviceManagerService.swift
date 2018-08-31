//
//  TestDeviceManagerService.swift
//  RoverDebug
//
//  Created by Sean Rucker on 2018-06-25.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

class TestDeviceManagerService: TestDeviceManager {
    let eventQueue: EventQueue
    let logger: Logger
    let userDefaults: UserDefaults
    
    private var _isTestDevice: Bool
    
    var isTestDevice: Bool {
        get {
            return _isTestDevice
        }
        set {
            if _isTestDevice == newValue {
                return
            }
            
            _isTestDevice = newValue
            userDefaults.set(_isTestDevice, forKey: "io.rover.isTestDevice")
            
            if _isTestDevice {
                logger.debug("Enabled testing")
                
                let event = EventInfo(name: "Testing Enabled", namespace: "rover")
                eventQueue.addEvent(event)
            } else {
                logger.debug("Disabled testing")
                
                let event = EventInfo(name: "Testing Disabled", namespace: "rover")
                eventQueue.addEvent(event)
            }
            
            eventQueue.flush()
        }
    }
    
    init(eventQueue: EventQueue, logger: Logger, userDefaults: UserDefaults) {
        self.eventQueue = eventQueue
        self.logger = logger
        self.userDefaults = userDefaults
        
        _isTestDevice = userDefaults.bool(forKey: "io.rover.isTestDevice")
    }
}
