//
//  SyncQuery.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-09-14.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

extension SyncQuery {
    static let beacons = SyncQuery(
        name: "beacons",
        body: """
            nodes {
                ...beaconFields
            }
            pageInfo {
                endCursor
                hasNextPage
            }
            """,
        arguments: [
            SyncQuery.Argument(name: "first", type: "Int"),
            SyncQuery.Argument(name: "after", type: "String"),
            SyncQuery.Argument(name: "orderBy", type: "BeaconOrder")
        ],
        fragments: ["beaconFields"]
    )
    
    static let geofences = SyncQuery(
        name: "geofences",
        body: """
            nodes {
                ...geofenceFields
            }
            pageInfo {
                endCursor
                hasNextPage
            }
            """,
        arguments: [
            SyncQuery.Argument(name: "first", type: "Int"),
            SyncQuery.Argument(name: "after", type: "String"),
            SyncQuery.Argument(name: "orderBy", type: "GeofenceOrder")
        ],
        fragments: ["geofenceFields"]
    )
}
