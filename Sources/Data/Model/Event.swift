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
