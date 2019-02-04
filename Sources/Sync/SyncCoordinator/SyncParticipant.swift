//
//  SyncParticipant.swift
//  RoverSync
//
//  Created by Sean Rucker on 2018-06-05.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol SyncParticipant: AnyObject {
    /// Request variables for requesting the TODO doc this.
    func initialRequestVariables() -> [String: Any]?
    func saveResponse(_ data: Data) -> SyncResult
}
