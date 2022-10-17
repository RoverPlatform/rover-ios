//
//  GeofencesSyncParticipant.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-08-29.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import os.log
#if !COCOAPODS
import RoverFoundation
import RoverData
#endif

class GeofencesSyncParticipant: PagingSyncParticipant {
    typealias Response = GeofencesSyncResponse
    
    let context: NSManagedObjectContext
    let userDefaults: UserDefaults
    
    var cursorKey: String {
        return "io.rover.RoverLocation.geofencesCursor"
    }
    
    var participants = [SyncParticipant]()
    
    init(context: NSManagedObjectContext, userDefaults: UserDefaults) {
        self.context = context
        self.userDefaults = userDefaults
    }
    
    func nextRequest(cursor: String?) -> SyncRequest {
        let orderBy: Attributes = [
            "field": "UPDATED_AT",
            "direction": "ASC"
        ]
        
        var values: [String: Any] = [
            "first": 500,
            "orderBy": orderBy
        ]
        
        if let cursor = cursor {
            values["after"] = cursor
        }
        
        return SyncRequest(query: SyncQuery.geofences, values: values)
    }

    func insertObject(from node: GeofencesSyncResponse.Data.Geofences.Node) {
        let geofence = Geofence(context: context)
        geofence.id = node.id
        geofence.name = node.name
        geofence.latitude = node.center.latitude
        geofence.longitude = node.center.longitude
        geofence.radius = node.radius
        geofence.tags = node.tags
    }
}

// MARK: GeofencesSyncResponse

struct GeofencesSyncResponse: Decodable {
    struct Data: Decodable {
        struct Geofences: Decodable {
            struct Node: Decodable {
                struct Center: Decodable {
                    var latitude: Double
                    var longitude: Double
                }
                
                var id: String
                var name: String
                var center: Center
                var radius: Double
                var tags: [String]
            }
            
            var nodes: [Node]?
            var pageInfo: PageInfo
        }
        
        var geofences: Geofences
    }
    
    var data: Data
}

extension GeofencesSyncResponse: PagingResponse {
    var nodes: [Data.Geofences.Node]? {
        return data.geofences.nodes
    }
    
    var pageInfo: PageInfo {
        return data.geofences.pageInfo
    }
}
