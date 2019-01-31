//
//  Beacon.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-09.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import os.log

public final class Beacon: NSManagedObject {
    public struct InsertionInfo {
        var id: String
        var name: String
        var uuid: UUID
        var major: Int32
        var minor: Int32
        var tags: [String]
        
        public init(id: String, name: String, uuid: UUID, major: Int32, minor: Int32, tags: [String] = []) {
            self.id = id
            self.name = name
            self.uuid = uuid
            self.major = major
            self.minor = minor
            self.tags = tags
        }
    }
    
    @discardableResult
    public static func insert(from info: InsertionInfo, into context: NSManagedObjectContext) -> Beacon {
        let beacon = Beacon(context: context)
        beacon.id = info.id
        beacon.name = info.name
        beacon.uuid = info.uuid
        beacon.major = info.major
        beacon.minor = info.minor
        beacon.tags = info.tags
        return beacon
    }
    
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<Beacon> {
        return NSFetchRequest<Beacon>(entityName: "Beacon")
    }
    
    @NSManaged public private(set) var id: String
    @NSManaged public private(set) var name: String
    @NSManaged public private(set) var uuid: UUID
    @NSManaged public private(set) var major: Int32
    @NSManaged public private(set) var minor: Int32
    @NSManaged public private(set) var tags: [String]

    @NSManaged public private(set) var regionIdentifier: String
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        self.tags = []
    }
    
    override public func willSave() {
        let regionIdentifier = "\(self.uuid.uuidString):\(self.major):\(self.minor)"
        if self.regionIdentifier != regionIdentifier {
            self.regionIdentifier = regionIdentifier
        }
    }
}

// MARK: Attributes

extension Beacon {
    public var attributes: Attributes {
        return [
            "id": self.id,
            "name": self.name,
            "uuid": self.uuid.uuidString,
            "major": self.major,
            "minor": self.minor,
            "tags": self.tags
        ]
    }
}

// MARK: Events

extension Beacon {
    public var enterEvent: EventInfo {
        return EventInfo(
            name: "Beacon Entered",
            namespace: "rover",
            attributes: ["beacon": self]
        )
    }
    
    public var exitEvent: EventInfo {
        return EventInfo(
            name: "Beacon Exited",
            namespace: "rover",
            attributes: ["beacon": self]
        )
    }
}

// MARK: Store Requests

extension Beacon {
    public static func fetchAll(in context: NSManagedObjectContext) -> Set<Beacon> {
        let fetchRequest: NSFetchRequest<Beacon> = Beacon.fetchRequest()
        let beacons: [Beacon]
        
        do {
            beacons = try context.fetch(fetchRequest)
        } catch {
            os_log("Failed to fetch beacons: %@", log: .persistence, type: .error, error.localizedDescription)
            return []
        }
        
        return Set(beacons)
    }
    
    public static func fetchAll(matchingRegionIdentifiers regionIdentifiers: Set<String>, in context: NSManagedObjectContext) -> Set<Beacon> {
        let fetchRequest: NSFetchRequest<Beacon> = Beacon.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "regionIdentifier IN %@", regionIdentifiers)
        
        do {
            let beacons = try context.fetch(fetchRequest)
            return Set(beacons)
        } catch {
            os_log("Failed to fetch beacons: %@", log: .persistence, type: .error, error.localizedDescription)
            return []
        }
    }

    public static func deleteAll(in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Beacon.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
        } catch {
            os_log("Failed to delete beacons: %@", log: .persistence, type: .error, error.localizedDescription)
        }
    }
}
