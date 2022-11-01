//
//  BeaconsSyncParticipant.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-09-06.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import os.log
#if !COCOAPODS
import RoverFoundation
import RoverData
#endif

class BeaconsSyncParticipant: PagingSyncParticipant {
    typealias Response = BeaconsSyncResponse
    
    let context: NSManagedObjectContext
    let userDefaults: UserDefaults
    
    var cursorKey: String {
        return "io.rover.RoverLocation.beaconsCursor"
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
        
        return SyncRequest(query: SyncQuery.beacons, values: values)
    }
    
    func insertObject(from node: BeaconsSyncResponse.Data.Beacons.Node) {
        let beacon = Beacon(context: context)
        beacon.id = node.id
        beacon.name = node.name
        beacon.uuid = node.uuid
        beacon.major = node.major
        beacon.minor = node.minor
        beacon.tags = node.tags
    }
}

struct BeaconsSyncResponse: Decodable {
    struct Data: Decodable {
        struct Beacons: Decodable {
            struct Node: Decodable {
                var id: String
                var name: String
                var uuid: UUID
                var major: Int32
                var minor: Int32
                var tags: [String]
            }
            
            var nodes: [Node]?
            var pageInfo: PageInfo
        }
        
        var beacons: Beacons
    }
    
    var data: Data
}

extension BeaconsSyncResponse: PagingResponse {
    var nodes: [Data.Beacons.Node]? {
        return data.beacons.nodes
    }
    
    var pageInfo: PageInfo {
        return data.beacons.pageInfo
    }
}
