//
//  Event.swift
//  RoverData
//
//  Created by Andrew Clunis on 2018-11-23.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation
import os

/// A fully filled out Event, modelled to be suitable for storage in the local database.
///
/// These are used both for store-and-forwarding events to the Rover cloud services, but also kept and queried locally to power automated campaigns.
public final class Event: NSManagedObject {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<Event> {
        return NSFetchRequest<Event>(entityName: "Event")
    }
    
    @NSManaged public internal(set) var id: String
    @NSManaged public internal(set) var name: String
    @NSManaged public internal(set) var namespace: String?
    @NSManaged public internal(set) var attributes: Attributes
    @NSManaged public internal(set) var deviceSnapshot: DeviceSnapshot
    @NSManaged public internal(set) var timestamp: Date
    @NSManaged public internal(set) var isFlushed: Bool
    
    override public func awakeFromInsert() {
        // default values for newly created and inserted Events.
        
        self.id = UUID().uuidString
        self.attributes = Attributes()
        self.deviceSnapshot = DeviceSnapshot()
        self.timestamp = Date()
    }
}

extension Event {
    public convenience init(
        from eventInfo: EventInfo,
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
