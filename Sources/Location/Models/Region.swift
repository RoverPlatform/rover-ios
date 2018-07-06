//
//  Region.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-05-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreLocation

public enum Region: Equatable {
    case beacon(uuid: UUID, major: UInt16?, minor: UInt16?)
    case geofence(latitude: Double, longitude: Double, radius: Double)
    
    public var identifier: String {
        switch self {
        case let .beacon(uuid, major?, minor?):
            return "\(uuid):\(major):\(minor)"
        case let .beacon(uuid, major?, _):
            return "\(uuid):\(major)"
        case let .beacon(uuid, _, _):
            return uuid.uuidString
        case let .geofence(latitude, longitude, radius):
            return "\(latitude):\(longitude):\(radius)"
        }
    }
}

extension Region {
    var clRegion: CLRegion {
        switch self {
        case let .beacon(uuid, major?, minor?):
            return CLBeaconRegion(proximityUUID: uuid, major: major, minor: minor, identifier: identifier)
        case let .beacon(uuid, major?, _):
            return CLBeaconRegion(proximityUUID: uuid, major: major, identifier: identifier)
        case let .beacon(uuid, _, _):
            return CLBeaconRegion(proximityUUID: uuid, identifier: identifier)
        case let .geofence(latitude, longitude, radius):
            let center = CLLocationCoordinate2DMake(latitude, longitude)
            return CLCircularRegion(center: center, radius: radius, identifier: identifier)
        }
    }
}


// MARK: Decodable

extension Region: Decodable {
    enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
        case uuid
        case major
        case minor
        case latitude
        case longitude
        case radius
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .typeName)
        switch typeName {
        case "BeaconRegion":
            let uuid = try container.decode(UUID.self, forKey: .uuid)
            let major = try container.decodeIfPresent(UInt16.self, forKey: .major)
            let minor = try container.decodeIfPresent(UInt16.self, forKey: .minor)
            self = .beacon(uuid: uuid, major: major, minor: minor)
        case "GeofenceRegion":
            let latitude = try container.decode(Double.self, forKey: .latitude)
            let longitude = try container.decode(Double.self, forKey: .longitude)
            let radius = try container.decode(Double.self, forKey: .radius)
            self = .geofence(latitude: latitude, longitude: longitude, radius: radius)
        default:
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected beacon or geofence – found \(typeName)")
        }
    }
}

// MARK: Hashable

extension Region: Hashable {
    public var hashValue: Int {
        return identifier.hashValue
    }
}
