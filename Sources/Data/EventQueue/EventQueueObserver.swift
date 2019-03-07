//
//  EventQueueObserver.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-03-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public protocol EventQueueObserver: AnyObject {
    func eventQueue(_ eventQueue: EventQueue, didAddEvent info: EventInfo)
}
