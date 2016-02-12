//
//  Mappables.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-28.
//
//

import Foundation
import CoreLocation

extension CLRegion : Mappable {
    static func instance(JSON: [String: AnyObject], included: [Any]?) -> CLRegion? {
        guard let type = JSON["type"] as? String, identifier = JSON["id"] as? String, attributes = JSON["attributes"] as? [String: AnyObject] else {
            return nil
        }
        
        switch type {
        case "ibeacon-regions":
            guard let uuidString = attributes["uuid"] as? String, uuid = NSUUID(UUIDString: uuidString) else { return nil }
            let major = attributes["major-number"] as? CLBeaconMajorValue
            let minor = attributes["minor-number"] as? CLBeaconMinorValue
            
            if major != nil && minor != nil {
                return CLBeaconRegion(proximityUUID: uuid, major: major!, minor: minor!, identifier: identifier)
            } else if major != nil {
                return CLBeaconRegion(proximityUUID: uuid, major: major!, identifier: identifier)
            } else {
                return CLBeaconRegion(proximityUUID: uuid, identifier: identifier)
            }
        case "geofence-regions":
            guard let latitude = attributes["latitude"] as? CLLocationDegrees, longitude = attributes["longitude"] as? CLLocationDegrees, radius = attributes["radius"] as? CLLocationDistance else { return nil }
            return CLCircularRegion(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), radius: radius, identifier: identifier)
        default:
            // invalid type
            return nil
        }
        
    }
}

extension Event : Mappable {
    static func instance(JSON: [String : AnyObject], included: [Any]?) -> Event? {
        guard let type = JSON["type"] as? String,
            attributes = JSON["attributes"],
            action = attributes["action"] as? String,
            relationships = JSON["relationships"] as? [String: AnyObject]//,
            //region = relationships["region"] as? CLRegion
            where type == "events" else { return nil }
        
        // Relationships
        
        guard let region = included?.filter({ $0 is CLRegion }).first as? CLRegion else {
            // error no region
            return nil
        }
        
        var config: BeaconConfiguration?
        for (key, value) in relationships {
            guard let data = value["data"] as? [String : AnyObject], id = data["id"] as? String else { continue }
            
            switch key {
            case "configuration":
                guard let idx = included?.indexOf({ ($0 as? BeaconConfiguration)?.identifier == id }) else { continue }
                config = included?[idx] as? BeaconConfiguration
            default:
                break
            }
        }
        
        switch action {
        case "enter-beacon-region":
            return Event.DidEnterBeaconRegion(region as! CLBeaconRegion, config)
        case "exit-beacon-region":
            return Event.DidExitBeaconRegion(region as! CLBeaconRegion, config)
        default:
            return nil
        }
    }
}

extension Device : Mappable {
    static func instance(JSON: [String : AnyObject], included: [Any]?) -> Device? {
        return nil
    }
}
