//
//  GeofencesSyncParticipant.swift
//  RoverSync
//
//  Created by Sean Rucker on 2018-08-29.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import os.log

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
        let orderBy: [String: Any] = [
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

    func insertObject(from node: GeofenceNode) {
        Geofence.insert(
            from: Geofence.InsertionInfo(id: node.id, name: node.name, latitude: node.center.latitude, longitude: node.center.longitude, radius: node.radius, tags: node.tags),
            into: self.context
        )
    }
}

// MARK: GeofencesSyncResponse

struct GeofencesSyncResponse: Decodable {
    struct Data: Decodable {
        struct Geofences: Decodable {
            
            var nodes: [GeofenceNode]?
            var pageInfo: PageInfo
        }
        
        var geofences: Geofences
    }
    
    var data: Data
}

extension GeofencesSyncResponse: PagingResponse {
    var nodes: [GeofenceNode]? {
        return data.geofences.nodes
    }
    
    var pageInfo: PageInfo {
        return data.geofences.pageInfo
    }
}
