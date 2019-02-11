//
//  BeaconNode.swift
//  RoverSync
//
//  Created by Andrew Clunis on 2019-01-28.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

/// This structure represents the Beacon data coming back from the cloud-side GraphQL API for Sync.
struct BeaconNode: Decodable {
    var id: String
    var name: String
    var uuid: UUID
    var major: Int32
    var minor: Int32
    var tags: [String]
}
