//
//  DeviceAttributesService.swift
//  RoverData
//
//  Created by Sean Rucker on 2017-10-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import Foundation

fileprivate let storageKey = "io.rover.deviceAttributes"

class DeviceAttributesService: DeviceAttributes {
    let eventQueue: EventQueue
    let logger: Logger
    let userDefaults: UserDefaults
    
    var attributes = Attributes()
    
    init(eventQueue: EventQueue, logger: Logger, userDefaults: UserDefaults) {
        self.eventQueue = eventQueue
        self.logger = logger
        self.userDefaults = userDefaults
    }
    
    func restore() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            logger.debug("No device attributes to restore")
            return
        }
        
        guard let attributes = try? JSONDecoder().decode(Attributes.self, from: data) else {
            logger.error("Failed to decode device attributes")
            return
        }
        
        self.attributes = attributes
        logger.debug("Device attributes restored from local storage")
    }
    
    func current() -> Attributes {
        return attributes
    }
    
    func update(_ block: (inout Attributes) -> Void) {
        block(&attributes)
        
        if attributes.count < 1 {
            userDefaults.removeObject(forKey: storageKey)
            return
        }
                
        guard let data = try? JSONEncoder().encode(attributes) else {
            logger.error("Failed to encode device attributes")
            return
        }
        
        userDefaults.set(data, forKey: storageKey)
        let event = EventInfo(name: "Device Attributes Updated", namespace: "rover")
        eventQueue.addEvent(event)
    }
    
    func clear() {
        attributes = Attributes()
        userDefaults.removeObject(forKey: storageKey)
    }
}
