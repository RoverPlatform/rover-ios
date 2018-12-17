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
    public var observers = ObserverSet<Event>()
    
    public var deviceInfoProvider: DeviceInfoProvider? = nil
    
    private let managedObjectContext: NSManagedObjectContext
    private var objectsDidChangeObserver: NSObjectProtocol!
    
    
    public init(
        managedObjectContext: NSManagedObjectContext
    ) {
        self.managedObjectContext = managedObjectContext
        self.objectsDidChangeObserver = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: managedObjectContext, queue: nil) { [weak self] notification in
            guard let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSObject> else {
                return
            }
            
            let insertedEvents = insertedObjects
                .compactMap({ $0 as? Event })

            insertedEvents.forEach({ event in self?.observers.notify(parameters: event) })
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self.objectsDidChangeObserver)
    }
    
    public func addEvent(_ eventInfo: EventInfo) {
        let event = Event(context: self.managedObjectContext)
        
        guard let deviceSnapshot = deviceInfoProvider?.deviceSnapshot else {
            os_log("Event added before Device Info Provider set. Dropping event.", log: .events, type: .error)
            return
        }
        
        event.attributes = eventInfo.attributes ?? Attributes()
        event.deviceSnapshot = deviceSnapshot
        event.name = eventInfo.name
        event.namespace = eventInfo.namespace
        
        managedObjectContext.perform { [managedObjectContext] in
            managedObjectContext.insert(event)
           
            do {
                try managedObjectContext.save()
                managedObjectContext.reset()
            } catch {
                if let multipleErrors = (error as NSError).userInfo[NSDetailedErrorsKey] as? [Error] {
                    multipleErrors.forEach {
                        os_log("Unable to save event into the EventPipeline. Dropping it. Reason: %s", log: .persistence, type: .error, $0.localizedDescription)
                    }
                } else {
                    os_log("Unable to save event into the EventPipeline. Dropping it. Reason: %s", log: .persistence, type: .error, error.localizedDescription)
                }
                
                managedObjectContext.rollback()
            }
        }
    }
    
    
}
