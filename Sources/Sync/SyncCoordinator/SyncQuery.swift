//
//  SyncQuery.swift
//  RoverSync
//
//  Created by Sean Rucker on 2018-08-28.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public struct SyncQuery {
    public struct Argument: Equatable, Hashable {
        public var name: String
        public var type: String

        public init(name: String, type: String) {
            self.name = name
            self.type = type
        }
    }

    public var name: String
    public var body: String
    public var arguments: [Argument]
    public var fragments: [String]

    public init(name: String, body: String, arguments: [Argument], fragments: [String]) {
        self.name = name
        self.body = body
        self.arguments = arguments
        self.fragments = fragments
    }
}

extension SyncQuery {
    var signature: String? {
        if arguments.isEmpty {
            return nil
        }

        return arguments.map({
            "$\(name)\($0.name.capitalized):\($0.type)"
        }).joined(separator: ", ")
    }

    var definition: String {
        let expression: String = {
            if arguments.isEmpty {
                return ""
            }

            let signature = arguments.map({
                "\($0.name):$\(name)\($0.name.capitalized)"
            }).joined(separator: ", ")

            return "(\(signature))"
        }()

        return """
            \(name)\(expression) {
                \(body)
            }
            """
    }
}

// MARK: Notifications

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

// MARK: Location

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

// Campaigns

extension SyncQuery {
    static let campaigns = SyncQuery(
        name: "campaigns",
        body: """
            nodes {
                ...campaignFields
            }
            pageInfo {
                endCursor
                hasNextPage
            }
            """,
        arguments: [
            SyncQuery.Argument(name: "first", type: "Int"),
            SyncQuery.Argument(name: "after", type: "String"),
            SyncQuery.Argument(name: "orderBy", type: "CampaignOrder")
        ],
        fragments: ["campaignFields"]
    )
}
