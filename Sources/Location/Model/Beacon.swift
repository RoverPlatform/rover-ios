//
//  Beacon.swift
//  RoverCampaignsLocation
//
//  Created by Sean Rucker on 2018-09-09.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import CoreLocation
import os.log

public final class Beacon: NSManagedObject {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<Beacon> {
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

// MARK: AttributeRepresentable

extension Beacon: AttributeRepresentable {
    public var attributeValue: AttributeValue {
        let attributes: Attributes = [
            "id": self.id,
            "name": self.name,
            "uuid": self.uuid.uuidString,
            "major": self.major,
            "minor": self.minor,
            "tags": self.tags
        ]
        
        return .object(attributes)
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

// MARK: Collection

extension Collection where Element == Beacon {
    public func wildCardRegions(maxLength: Int) -> Set<CLBeaconRegion> {
        let uuids = self.map { $0.uuid }
        let unique = Set(uuids)
        
        #if swift(>=4.2)
        let regions = unique.shuffled().prefix(maxLength).map { $0.region }
        #else
        let regions = unique.prefix(maxLength).map { $0.region }
        #endif
        
        return Set<CLBeaconRegion>(regions)
    }
}
