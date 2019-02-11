//
//  SyncStorage.swift
//  RoverSync
//
//  Created by Andrew Clunis on 2019-02-05.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

/// Describes how multiple synced objects may be stored for PagingSyncParticipant.
protocol SyncStorage {
    associatedtype Node
    
    /// Insert the objects into the storage.  Returns false if the insertion was not successful.
    func insertObjects(from nodes: [Node]) -> Bool
}
