//
//  TokenManagerService.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-02-08.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

class TokenManagerService: TokenManager {
    let eventQueue: EventQueue
    let logger: Logger
    let userDefaults: UserDefaults
    
    internal private(set) var pushToken: String?
    
    init(eventQueue: EventQueue, logger: Logger, userDefaults: UserDefaults) {
        self.eventQueue = eventQueue
        self.logger = logger
        self.userDefaults = userDefaults
        
        pushToken = userDefaults.string(forKey: "io.rover.pushToken")
    }
    
    func setToken(_ data: Data) {
        let newToken = data.map { String(format: "%02.2hhx", $0) }.joined()
        
        if newToken == pushToken {
            return
        }
        
        let previousToken = pushToken
        pushToken = newToken
        userDefaults.set(pushToken, forKey: "io.rover.pushToken")
        
        if let previousToken = previousToken {
            logger.debug("Current and previous tokens do not match – push token updated")
            
            let attributes: Attributes = ["currentToken": pushToken!, "previousToken": previousToken]
            let event = EventInfo(name: "Push Token Updated", namespace: "rover", attributes: attributes)
            eventQueue.addEvent(event)
        } else {
            logger.debug("Previous token not found - push token added")
            
            let attributes: Attributes = ["currentToken": pushToken!]
            let event = EventInfo(name: "Push Token Added", namespace: "rover", attributes: attributes)
            eventQueue.addEvent(event)
        }
        
        eventQueue.flush()
    }
    
    func removeToken() {
        guard let previousToken = pushToken else {
            logger.debug("Previous token not found - nothing to remove")
            return
        }
        
        pushToken = nil
        userDefaults.removeObject(forKey: "io.rover.pushToken")
        logger.debug("Previous token found - push token removed")
        
        let attributes: Attributes = ["previousToken": previousToken]
        let event = EventInfo(name: "Push Token Removed", namespace: "rover", attributes: attributes)
        eventQueue.addEvent(event)
        eventQueue.flush()
    }
}
