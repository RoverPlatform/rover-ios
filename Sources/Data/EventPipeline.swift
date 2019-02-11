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
    
    public var observers = ObserverSet<Event>()
    
    private let managedObjectContext: NSManagedObjectContext
    
    private var observerChit: NSObjectProtocol?
    
    public init(
        managedObjectContext: NSManagedObjectContext
    ) {
        self.managedObjectContext = managedObjectContext
        self.observerChit = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: self.managedObjectContext, queue: nil) { [weak self] iosNotification in
            guard let insertedObjects = iosNotification.userInfo?[NSInsertedObjectsKey] as? Set<NSObject> else {
                return
            }
            guard let self = self else {
                return
            }
            
            let insertedEvents = insertedObjects
                .compactMap { $0 as? Event }
            
            if !insertedEvents.isEmpty {
                insertedEvents.forEach { event in self.observers.notify(parameters: event) }
            }
        }
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
}
