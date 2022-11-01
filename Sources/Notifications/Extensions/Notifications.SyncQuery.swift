//
//  SyncQuery.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-09-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

#if !COCOAPODS
import RoverData
#endif

extension SyncQuery {
    static let notifications = SyncQuery(
        name: "notifications",
        body: """
            nodes {
                ...notificationFields
            }
            """,
        arguments: [
            SyncQuery.Argument(name: "last", type: "Int"),
            SyncQuery.Argument(name: "orderBy", type: "NotificationOrder"),
            SyncQuery.Argument(name: "deviceIdentifier", type: "String!")
        ],
        fragments: ["notificationFields"]
    )
}
