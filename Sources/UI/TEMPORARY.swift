//
//  TEMPORARY.swift
//  RoverUI
//
//  Created by Andrew Clunis on 2018-11-22.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import UIKit


public protocol EventQueue {
    func addEvent(_ event: EventInfo)
}

public extension EventQueue {
    public func addEvent(_ event: EventInfo) { }
    public func flush() { }
}

public protocol SyncCoordinator {
    func sync(completionHandler: (UIBackgroundFetchResult) -> Void)
}

extension SyncCoordinator {
    public func sync(completionHandler: (UIBackgroundFetchResult) -> Void) { }
}

public class FakeEventQueue : EventQueue {
    
}

public class FakeSyncCoordinator: SyncCoordinator {
    
}

