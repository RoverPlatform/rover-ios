//
//  SyncParticipant.swift
//  RoverSync
//
//  Created by Sean Rucker on 2018-06-05.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol SyncParticipant: class {
    func initialRequest() -> SyncRequest?
    func saveResponse(_ data: Data) -> SyncResult
}
