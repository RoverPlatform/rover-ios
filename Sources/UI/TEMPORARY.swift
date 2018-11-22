//
//  TEMPORARY.swift
//  RoverUI
//
//  Created by Andrew Clunis on 2018-11-22.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol EventQueue {
    func addEvent(_ event: EventInfo)
}

extension EventQueue {
    func addEvent(_ event: EventInfo) { }
}

public protocol SyncCoordinator {
    func sync(_ cb: (Bool) -> Void)
}

extension SyncCoordinator {
    func sync(_ cb: (Bool) -> Void) { }
}
