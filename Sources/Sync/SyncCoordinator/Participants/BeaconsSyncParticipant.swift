//
//  BeaconsSyncParticipant.swift
//  RoverSync
//
//  Created by Sean Rucker on 2018-09-06.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import os.log

class BeaconsSyncParticipant: PagingSyncParticipant {
    typealias Storage = CoreDataSyncStorage
    typealias Response = BeaconsSyncResponse
    
    let userDefaults: UserDefaults
    let syncStorage: Storage<BeaconNode>
    
    var cursorKey: String {
        // TODO: rename into RoverSync
        return "io.rover.RoverLocation.beaconsCursor"
    }
    
    init(syncStorage: Storage<BeaconNode>, userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        self.syncStorage = syncStorage
    }
    
    func nextRequestVariables(cursor: String?) -> [String: Any] {
        let orderBy: [String: Any] = [
            "field": "UPDATED_AT",
            "direction": "ASC"
        ]
        
        var values: [String: Any] = [
            "beaconsFirst": 500,
            "beaconsOrderBy": orderBy
        ]
        
        if let cursor = cursor {
            values["beaconsAfter"] = cursor
        }
        
        return values
    }
}

struct BeaconsSyncResponse: Decodable {
    struct Data: Decodable {
        struct Beacons: Decodable {
            var nodes: [BeaconNode]?
            var pageInfo: PageInfo
        }
        
        var beacons: Beacons
    }
    
    var data: Data
}

extension BeaconsSyncResponse: PagingResponse {
    var nodes: [BeaconNode]? {
        return data.beacons.nodes
    }
    
    var pageInfo: PageInfo {
        return data.beacons.pageInfo
    }
}

extension BeaconNode: CoreDataStorable {
    public func store(context: NSManagedObjectContext) {
        Beacon.insert(
            from: Beacon.InsertionInfo(
                id: self.id,
                name: self.name,
                uuid: self.uuid,
                major: self.major,
                minor: self.minor,
                tags: self.tags
            ),
            into: context
        )
    }
}
