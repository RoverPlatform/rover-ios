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
    private let deviceInfoProvider: DeviceInfoProvider
    private var objectsDidChangeObserver: NSObjectProtocol!
    
    init(
        managedObjectContext: NSManagedObjectContext,
        deviceInfoProvider: DeviceInfoProvider
    ) {
        self.managedObjectContext = managedObjectContext
        self.deviceInfoProvider = deviceInfoProvider
        self.objectsDidChangeObserver = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: managedObjectContext, queue: nil) { [weak self] notification in
            guard let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSObject> else {
                return
            }
            
            let insertedEvents = insertedObjects
                .compactMap({ $0 as? Event })

            insertedEvents.forEach({ self?.observers.notify(parameters: $0) })
            
            insertedEvents.forEach({ (event) in
                self?.observers.notify(parameters: event)
            })
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self.objectsDidChangeObserver)
    }
    
    func addEvent(_ eventInfo: EventInfo) {
        let event = Event()
        // TODO: decide if a stricter error regime is worth it here?
        
        event.attributes = eventInfo.attributes ?? Attributes()
        event.deviceSnapshot = deviceInfoProvider.deviceSnapshot
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
