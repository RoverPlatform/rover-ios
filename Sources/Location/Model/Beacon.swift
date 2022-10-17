//
//  Beacon.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-09-09.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import CoreLocation
import os.log
#if !COCOAPODS
import RoverFoundation
import RoverData
#endif

public final class Beacon: NSManagedObject {
    @nonobjc @available(*, deprecated, message: "Please use Beacon.beaconFetchRequest() instead.")
    public class func fetchRequest() -> NSFetchRequest<Beacon> {
        return NSFetchRequest<Beacon>(entityName: "Beacon")
    }
    
    public class func beaconFetchRequest() -> NSFetchRequest<Beacon> {
        return NSFetchRequest<Beacon>(entityName: "Beacon")
    }
    
    @NSManaged public internal(set) var id: String
    @NSManaged public internal(set) var name: String
    @NSManaged public internal(set) var uuid: UUID
    @NSManaged public internal(set) var major: Int32
    @NSManaged public internal(set) var minor: Int32
    @NSManaged public internal(set) var tags: [String]

    @NSManaged public private(set) var regionIdentifier: String
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        self.tags = []
    }
    
    override public func willSave() {
        if self.regionIdentifier != self.region.identifier {
            self.regionIdentifier = self.region.identifier
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
            "major": Int(self.major),
            "minor": Int(self.minor),
            "tags": self.tags
        ]
    }
}

// MARK: Core Location

extension Beacon {
    public var region: CLBeaconRegion {
        return CLBeaconRegion(
            proximityUUID: self.uuid,
            major: UInt16(self.major),
            minor: UInt16(self.minor),
            identifier: "\(self.uuid.uuidString):\(self.major):\(self.minor)"
        )
    }
}

// MARK: Events

extension Beacon {
    public var enterEvent: EventInfo {
        return EventInfo(
            name: "Beacon Entered",
            namespace: "rover",
            attributes: ["beacon": self.attributes]
        )
    }
    
    public var exitEvent: EventInfo {
        return EventInfo(
            name: "Beacon Exited",
            namespace: "rover",
            attributes: ["beacon": self.attributes]
        )
    }
}

// MARK: Store Requests

extension Beacon {
    public static func fetchAll(in context: NSManagedObjectContext) -> Set<Beacon> {
        let fetchRequest: NSFetchRequest<Beacon> = Beacon.beaconFetchRequest()
        let beacons: [Beacon]
        
        do {
            beacons = try context.fetch(fetchRequest)
        } catch {
            os_log("Failed to fetch beacons: %@", log: .persistence, type: .error, error.logDescription)
            return []
        }
        
        return Set(beacons)
    }
    
    public static func fetchAll(matchingRegionIdentifiers regionIdentifiers: Set<String>, in context: NSManagedObjectContext) -> Set<Beacon> {
        let fetchRequest: NSFetchRequest<Beacon> = Beacon.beaconFetchRequest()
        fetchRequest.predicate = NSPredicate(format: "regionIdentifier IN %@", regionIdentifiers)
        
        do {
            let beacons = try context.fetch(fetchRequest)
            return Set(beacons)
        } catch {
            os_log("Failed to fetch beacons: %@", log: .persistence, type: .error, error.logDescription)
            return []
        }
    }

    public static func deleteAll(in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Beacon.beaconFetchRequest() as! NSFetchRequest<NSFetchRequestResult>
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
        } catch {
            os_log("Failed to delete beacons: %@", log: .persistence, type: .error, error.logDescription)
        }
    }
}

// MARK: Collection

extension Collection where Element == Beacon {
    public func wildCardRegions(maxLength: Int) -> Set<CLBeaconRegion> {
        let uuids = self.map { $0.uuid }
        let unique = Set(uuids)
        
        let regions = unique.shuffled().prefix(maxLength).map { $0.region }
        
        return Set<CLBeaconRegion>(regions)
    }
}
