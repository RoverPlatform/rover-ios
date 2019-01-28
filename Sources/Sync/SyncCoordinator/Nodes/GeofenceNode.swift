//
//  GeofenceNode.swift
//  RoverSync
//
//  Created by Andrew Clunis on 2019-01-28.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

/// This structure represents the Geofence data coming back from the cloud-side GraphQL API for Sync.
public struct GeofenceNode: Decodable {
    public struct Center: Decodable {
        var latitude: Double
        var longitude: Double
    }
    
    var id: String
    var name: String
    var center: Center
    var radius: Double
    var tags: [String]
}
