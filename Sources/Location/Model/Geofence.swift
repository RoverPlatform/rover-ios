//
//  Geofence.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-08-28.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import CoreLocation
import os
#if !COCOAPODS
import RoverFoundation
import RoverData
#endif

public final class Geofence: NSManagedObject {
    @nonobjc @available(*, deprecated, message: "Please use Geofence.geofenceFetchRequest() instead.")
    public class func fetchRequest() -> NSFetchRequest<Geofence> {
        return NSFetchRequest<Geofence>(entityName: "Geofence")
    }
    
    public class func geofenceFetchRequest() -> NSFetchRequest<Geofence> {
        return NSFetchRequest<Geofence>(entityName: "Geofence")
    }
    
    @NSManaged public internal(set) var id: String
    @NSManaged public internal(set) var name: String
    @NSManaged public internal(set) var latitude: Double
    @NSManaged public internal(set) var longitude: Double
    @NSManaged public internal(set) var radius: Double
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

// MARK: Core Location

extension Geofence {
    public var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    public var location: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    public var region: CLCircularRegion {
        return CLCircularRegion(
            center: location.coordinate,
            radius: radius,
            identifier: "\(latitude):\(longitude):\(radius)"
        )
    }
}

// MARK: Events

extension Geofence {
    public var enterEvent: EventInfo {
        return EventInfo(
            name: "Geofence Entered",
            namespace: "rover",
            attributes: ["geofence": self.attributes]
        )
    }
    
    public var exitEvent: EventInfo {
        return EventInfo(
            name: "Geofence Exited",
            namespace: "rover",
            attributes: ["geofence": self.attributes]
        )
    }
}

// MARK: Store Requests

extension Geofence {
    public static func fetchAll(in context: NSManagedObjectContext) -> Set<Geofence> {
        let fetchRequest: NSFetchRequest<Geofence> = Geofence.geofenceFetchRequest()
        let geofences: [Geofence]
        
        do {
            os_log("Fetching all geofences", log: .persistence, type: .debug)
            
            if #available(iOS 12.0, *) {
                os_signpost(.begin, log: .persistence, name: "fetchGeofences", "type=all")
            }
            
            geofences = try context.fetch(fetchRequest)
            
            if #available(iOS 12.0, *) {
                os_signpost(.end, log: .persistence, name: "fetchGeofences", "type=all")
            }
        } catch {
            os_log("Failed to fetch geofences: %@", log: .persistence, type: .error, error.logDescription)
            return []
        }
        
        os_log("Successfully fetched %d geofences", log: .persistence, type: .debug, geofences.count)
        return Set(geofences)
    }
    
    public static func fetch(regionIdentifier: String, in context: NSManagedObjectContext) -> Geofence? {
        let fetchRequest: NSFetchRequest<Geofence> = Geofence.geofenceFetchRequest()
        let predicate = NSPredicate(format: "regionIdentifier == %@", regionIdentifier)
        fetchRequest.predicate = predicate
        
        let geofences: [Geofence]
        
        do {
            os_log("Fetching geofence with predicate: %{public}", log: .persistence, type: .debug, predicate)
            
            if #available(iOS 12.0, *) {
                os_signpost(.begin, log: .persistence, name: "fetchGeofences", "type=regionIdentifier")
            }
            
            geofences = try context.fetch(fetchRequest)
            
            if #available(iOS 12.0, *) {
                os_signpost(.end, log: .persistence, name: "fetchGeofences", "type=regionIdentifier")
            }
        } catch {
            os_log("Failed to fetch geofence: %@", log: .persistence, type: .error, error.logDescription)
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
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Geofence.geofenceFetchRequest()  as! NSFetchRequest<NSFetchRequestResult>
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
        } catch {
            os_log("Failed to delete geofences: %@", log: .persistence, type: .error, error.logDescription)
        }
    }
}

// MARK: Collection

extension Collection where Element == Geofence {
    public func sortedByDistance(from coordinate: CLLocationCoordinate2D) -> [Geofence] {
        os_log("Sorting geofences...", log: .general, type: .debug)

        if #available(iOS 12.0, *) {
            os_signpost(.begin, log: .general, name: "sortGeofences")
        }
        
        let sorted = self.sorted {
            coordinate.distanceTo($0.coordinate) < coordinate.distanceTo($1.coordinate)
        }
        
        if #available(iOS 12.0, *) {
            os_signpost(.end, log: .general, name: "sortGeofences")
        }
        
        os_log("Sorted %d geofences", log: .general, type: .debug, self.count)
        return sorted
    }
    
    public func regions(closestTo coordinate: CLLocationCoordinate2D?, maxLength: Int) -> Set<CLCircularRegion> {
        let regions: [CLCircularRegion]
        if let coordinate = coordinate {
            regions = self.sortedByDistance(from: coordinate).prefix(maxLength).map { $0.region }
        } else {
            regions = self.shuffled().prefix(maxLength).compactMap { $0.region }
        }
        
        return Set<CLCircularRegion>(regions)
    }
}
