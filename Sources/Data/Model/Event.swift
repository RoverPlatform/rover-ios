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

public final class Event : NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Event> {
        return NSFetchRequest<Event>(entityName: "Event")
    }
    
    @NSManaged public internal(set) var id: String
    @NSManaged public internal(set) var name: String
    @NSManaged public internal(set) var namespace: String?
    @NSManaged public internal(set) var attributes: NSDictionary
    @NSManaged public internal(set) var deviceSnapshot: DeviceSnapshot
    @NSManaged public internal(set) var timestamp: Date
    @NSManaged public internal(set) var isFlushed: Bool
}

// MARK: Value Object Serialization

class DeviceSnapshotTransformer : ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let deviceSnapshot = value as? DeviceSnapshot else {
            os_log("DeviceSnapshotTransformer given something other than DeviceSnapshot.  Returning nil", log: .persistence, type: .error)
            return nil
        }
        guard let encoded = try? JSONEncoder.default.encode(deviceSnapshot) else {
            os_log("DeviceSnapshotTransformer could not encode DeviceSnapshot.  Returning nil.", log: .persistence, type: .error)
            return nil
        }
        return encoded
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {

    }
}
