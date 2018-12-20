//
//  Event.swift
//  RoverData
//
//  Created by Andrew Clunis on 2018-11-23.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import CoreData
import os

/// A fully filled out Event, modelled to be suitable for storage in the local database.
///
/// These are used both for store-and-forwarding events to the Rover cloud services, but also kept and queried locally to power automated campaigns.
public final class Event : NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Event> {
        return NSFetchRequest<Event>(entityName: "Event")
    }
    
    @NSManaged internal(set) var id: String
    @NSManaged internal(set) var name: String
    @NSManaged internal(set) var namespace: String?
    @NSManaged internal(set) var attributes: Attributes
    @NSManaged internal(set) var deviceSnapshot: DeviceSnapshot
    @NSManaged internal(set) var timestamp: Date
    @NSManaged internal(set) var isFlushed: Bool
    
    public override func awakeFromInsert() {
        // default values for newly created and inserted Events.
        
        self.id = UUID().uuidString
        self.attributes = Attributes()
        self.deviceSnapshot = DeviceSnapshot()
        self.timestamp = Date()
    }
}

// TODO: move eventpipeline trackevent here, then can set above nsmanaged properties to fileprivate and have this be sort of immutable. That is, if a solution for DeviceSnapshot can be engineered.

// TODO: static extension function for setting up an Notification Center obserserver.  This allows us to retire EventPipeline.

extension Event {
    /// Register a callback to be fired whenever Events are inserted
    ///
    /// Note that this returns an opaque chit object that you must retain until you no longer wish the callback to be fired.
    public static func observeNewEvents(
        managedObjectContext: NSManagedObjectContext,
        observerCallback: @escaping ([Event]) -> Void
    ) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: managedObjectContext, queue: nil) { (iosNotification) in
            guard let insertedObjects = iosNotification.userInfo?[NSInsertedObjectsKey] as? Set<NSObject> else {
                return
            }
            
            let insertedEvents = insertedObjects
                .compactMap({ $0 as? Event })
            
            if !insertedEvents.isEmpty {
                observerCallback(insertedEvents)
            }
        }
    }
    
    public func attemptInsert(managedObjectContext: NSManagedObjectContext) {
        managedObjectContext.perform { [managedObjectContext] in
            managedObjectContext.insert(self)
            
            do {
                try managedObjectContext.save()
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
    
    public convenience init(
        createFrom eventInfo: EventInfo,
        forDevice deviceSnapshot: DeviceSnapshot,
        inContext managedObjectContext: NSManagedObjectContext
    ) {
        self.init(context: managedObjectContext)

        self.attributes = eventInfo.attributes ?? Attributes()
        self.deviceSnapshot = deviceSnapshot
        self.name = eventInfo.name
        self.namespace = eventInfo.namespace
    }
}
