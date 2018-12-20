//
//  EventPipeline.swift
//  RoverData
//
//  Created by Andrew Clunis on 2018-12-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import CoreData
import os

public class EventPipeline {
    public var deviceInfoProvider: DeviceInfoProvider? = nil
    
    private let managedObjectContext: NSManagedObjectContext
    
    public init(
        managedObjectContext: NSManagedObjectContext
    ) {
        self.managedObjectContext = managedObjectContext
    }

    public func addEvent(_ eventInfo: EventInfo) {
        guard let deviceSnapshot = deviceInfoProvider?.deviceSnapshot else {
            os_log("Event added before Device Info Provider set. Dropping event.", log: .events, type: .error)
            return
        }
        
        let event = Event(
            createFrom: eventInfo,
            forDevice: deviceSnapshot,
            inContext: self.managedObjectContext
        )
        
        event.attemptInsert()
    }
}
