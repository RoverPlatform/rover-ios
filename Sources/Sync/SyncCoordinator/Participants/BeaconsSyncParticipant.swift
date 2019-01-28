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
    typealias Response = BeaconsSyncResponse

    let context: NSManagedObjectContext
    let userDefaults: UserDefaults

    var cursorKey: String {
        // TODO: rename into RoverSync
        return "io.rover.RoverLocation.beaconsCursor"
    }

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

        return SyncRequest(query: SyncQuery.beacons, values: values)
    }

    func insertObject(from node: BeaconNode) {
        Beacon.insert(
            from: Beacon.InsertionInfo(
                id: node.id,
                name: node.name,
                uuid: node.uuid,
                major: node.major,
                minor: node.minor,
                tags: node.tags
            ),
            into: self.context
        )
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
