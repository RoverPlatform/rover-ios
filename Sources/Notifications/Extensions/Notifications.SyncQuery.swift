//
//  SyncQuery.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-09-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

extension SyncQuery {
    static let notifications = SyncQuery(
        name: "notifications",
        body: """
            nodes {
                ...notificationFields
            }
            """,
        arguments: [
            SyncQuery.Argument.last,
            SyncQuery.Argument.deviceIdentifier
        ],
        fragments: ["notificationFields"]
    )
}

extension SyncQuery.Argument {
    static let deviceIdentifier = SyncQuery.Argument(
        name: "deviceIdentifier",
        style: .string,
        isRequired: true
    )
}
