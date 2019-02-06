//
//  SyncParticipant.swift
//  RoverSync
//
//  Created by Sean Rucker on 2018-06-05.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol SyncParticipant: AnyObject {
    /// GraphQL query variables to add to the sync request on behalf of this Sync Participant.
    func initialRequestVariables() -> [String: Any]?
    func saveResponse(_ data: Data) -> SyncResult
}
