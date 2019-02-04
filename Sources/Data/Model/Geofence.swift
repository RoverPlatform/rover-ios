//
//  Geofence.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-08-28.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import os

public final class Geofence: NSManagedObject {
    public struct InsertionInfo {
        var id: String
        var name: String
        var latitude: Double
        var longitude: Double
        var radius: Double
        var tags: [String]
        
        public init(id: String, name: String, latitude: Double, longitude: Double, radius: Double, tags: [String] = []) {
            self.id = id
            self.name = name
            self.latitude = latitude
            self.longitude = longitude
            self.radius = radius
            self.tags = tags
        }
    }
    
    @discardableResult
    public static func insert(from info: InsertionInfo, into context: NSManagedObjectContext) -> Geofence {
        let geofence = Geofence(context: context)
        geofence.id = info.id
        geofence.name = info.name
        geofence.latitude = info.latitude
        geofence.longitude = info.longitude
        geofence.radius = info.radius
        geofence.tags = info.tags
        return geofence
    }
    
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<Geofence> {
        return NSFetchRequest<Geofence>(entityName: "Geofence")
    }
    
    @NSManaged public private(set) var id: String
    @NSManaged public private(set) var name: String
    @NSManaged public private(set) var latitude: Double
    @NSManaged public private(set) var longitude: Double
    @NSManaged public private(set) var radius: Double
    @NSManaged public private(set) var tags: [String]
    
    @NSManaged public private(set) var regionIdentifier: String
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        self.tags = []
    }
    
    override public func willSave() {
        let regionIdentifier = "\(latitude):\(longitude):\(radius)"
        if self.regionIdentifier != regionIdentifier {
            self.regionIdentifier = regionIdentifier
        }
    }
}

// MARK: Attributes

extension Geofence {
    public var attributes: Attributes {
        return [
            "id": self.id,
            "name": self.name,
            "center": [self.latitude, self.longitude],
            "radius": self.radius,
            "tags": self.tags
        ]
    }
}

// MARK: Events

extension Geofence {
    public var enterEvent: EventInfo {
        return EventInfo(
            name: "Geofence Entered",
            namespace: "rover",
            attributes: ["geofence": self]
        )
    }
    
    public var exitEvent: EventInfo {
        return EventInfo(
            name: "Geofence Exited",
            namespace: "rover",
            attributes: ["geofence": self]
        )
    }
}

// MARK: Store Requests

extension Geofence {
    public static func fetchAll(in context: NSManagedObjectContext) -> Set<Geofence> {
        let fetchRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
        let geofences: [Geofence]
        
        do {
            os_log("Fetching all geofences", log: .persistence, type: .debug)
            
            #if swift(>=4.2)
            if #available(iOS 12.0, *) {
                os_signpost(.begin, log: .persistence, name: "fetchGeofences", "type=all")
            }
            #endif
            
            geofences = try context.fetch(fetchRequest)
            
            #if swift(>=4.2)
            if #available(iOS 12.0, *) {
                os_signpost(.end, log: .persistence, name: "fetchGeofences", "type=all")
            }
            #endif
        } catch {
            os_log("Failed to fetch geofences: %@", log: .persistence, type: .error, error.localizedDescription)
            return []
        }
        
        os_log("Successfully fetched %d geofences", log: .persistence, type: .debug, geofences.count)
        return Set(geofences)
    }
    
    public static func fetch(regionIdentifier: String, in context: NSManagedObjectContext) -> Geofence? {
        let fetchRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
        let predicate = NSPredicate(format: "regionIdentifier == %@", regionIdentifier)
        fetchRequest.predicate = predicate
        
        let geofences: [Geofence]
        
        do {
            os_log("Fetching geofence with predicate: %{public}", log: .persistence, type: .debug, predicate)
            
            #if swift(>=4.2)
            if #available(iOS 12.0, *) {
                os_signpost(.begin, log: .persistence, name: "fetchGeofences", "type=regionIdentifier")
            }
            #endif
            
            geofences = try context.fetch(fetchRequest)
            
            #if swift(>=4.2)
            if #available(iOS 12.0, *) {
                os_signpost(.end, log: .persistence, name: "fetchGeofences", "type=regionIdentifier")
            }
            #endif
        } catch {
            os_log("Failed to fetch geofence: %@", log: .persistence, type: .error, error.localizedDescription)
            return nil
        }
        
        guard let geofence = geofences.first else {
            os_log("No geofence found matching regionIdentifier: %@", log: .persistence, type: .error, regionIdentifier)
            return nil
        }
        
        os_log("Successfully fetched geofence: %{public}", log: .persistence, type: .debug, geofence)
        return geofence
    }

    public static func deleteAll(in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Geofence.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
        } catch {
            os_log("Failed to delete geofences: %@", log: .persistence, type: .error, error.localizedDescription)
        }
    }
}
