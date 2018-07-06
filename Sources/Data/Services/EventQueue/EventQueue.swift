//
//  EventQueue.swift
//  RoverData
//
//  Created by Sean Rucker on 2017-09-19.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

public protocol EventQueue {
    func addContextProviders(_ contextProviders: [ContextProvider])
    func addEvent(_ eventInfo: EventInfo)
    func addObserver(_ observer: EventQueueObserver)
    func flush()
    func restore()
}

extension EventQueue {
    public func addContextProviders(_ contextProviders: ContextProvider...) {
        addContextProviders(contextProviders)
    }
}
