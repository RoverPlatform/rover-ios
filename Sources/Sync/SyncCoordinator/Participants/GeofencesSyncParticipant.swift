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
    typealias Storage = CoreDataSyncStorage
    typealias Response = GeofencesSyncResponse
    
    let userDefaults: UserDefaults
    let syncStorage: Storage<GeofenceNode>
    
    var cursorKey: String {
        return "io.rover.RoverLocation.geofencesCursor"
    }
    
    var participants = [SyncParticipant]()
    
    init(syncStorage: Storage<GeofenceNode>, userDefaults: UserDefaults) {
        self.syncStorage = syncStorage
        self.userDefaults = userDefaults
    }
    
    func nextRequestVariables(cursor: String?) -> [String: Any] {
        let orderBy: [String: Any] = [
            "field": "UPDATED_AT",
            "direction": "ASC"
        ]
        
        var values: [String: Any] = [
            "geofencesFirst": 500,
            "geofencesOrderBy": orderBy
        ]
        
        if let cursor = cursor {
            values["geofencesAfter"] = cursor
        }
        
        return values
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

extension GeofenceNode: CoreDataStorable {
    public func store(context: NSManagedObjectContext) {
        Geofence.insert(
            from: Geofence.InsertionInfo(
                id: self.id,
                name: self.name,
                latitude: self.center.latitude,
                longitude: self.center.longitude,
                radius: self.radius,
                tags: self.tags
            ),
            into: context
        )
    }
}
