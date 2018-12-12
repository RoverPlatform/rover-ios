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

class EventPipeline {
    public var observers = ObserverSet<Event>()
    
    private let managedObjectContext: NSManagedObjectContext
    private var objectsDidChangeObserver: NSObjectProtocol!
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        
        self.objectsDidChangeObserver = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: managedObjectContext, queue: nil) { [weak self] notification in
            guard let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSObject> else {
                return
            }
            
            insertedObjects
                .compactMap({ $0 as? Event })
                .forEach({ self?.observers.notify(parameters: $0) })
            
//            let insertedEvents = insertedObjects.filter({ (potentialInsertedEvent) -> Bool in
//                return potentialInsertedEvent is Event
//            }) as! Set<Event>
            
            insertedEvents.forEach({ (event) in
                self?.observers.notify(parameters: event)
            })
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self.objectsDidChangeObserver)
    }
    
    func addEvent(_ event: EventInfo) {
        let eventSnapshot = event.snapshot
        managedObjectContext.perform { [managedObjectContext] in
            managedObjectContext.insert(eventSnapshot)
           
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

extension EventInfo {
    var snapshot: Event {
        let event = Event()
        // TODO: decide if a stricter error regime is worth it here?
        event.attributes = Attributes.init(rawValue: self.attributes ?? [:]) ?? Attributes()
        event.deviceSnapshot = DeviceSnapshot() // TODO: solve once Device indirection is solved
        event.name = self.name
        event.namespace = self.namespace
        return event
    }
}
