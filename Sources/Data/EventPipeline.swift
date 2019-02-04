//
//  EventPipeline.swift
//  RoverData
//
//  Created by Andrew Clunis on 2018-12-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation
import os

public class EventPipeline {
    public var deviceInfoProvider: DeviceInfoProvider?
    
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
            from: eventInfo,
            forDevice: deviceSnapshot,
            inContext: self.managedObjectContext
        )
        
        event.attemptInsert()
    }
    
    /// Register a callback to be fired whenever Events are inserted.
    ///
    /// Note that this returns an opaque chit object that you must retain until you no longer wish the callback to be fired.
    public func observeNewEvents(
        observerCallback: @escaping ([Event]) -> Void
    ) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: self.managedObjectContext, queue: nil) { iosNotification in
            guard let insertedObjects = iosNotification.userInfo?[NSInsertedObjectsKey] as? Set<NSObject> else {
                return
            }
            
            let insertedEvents = insertedObjects
                .compactMap { $0 as? Event }
            
            if !insertedEvents.isEmpty {
                observerCallback(insertedEvents)
            }
        }
    }
}
