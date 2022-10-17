//
//  SyncCoordinator.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-06-01.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

public protocol SyncCoordinator: AnyObject {
    var participants: [SyncParticipant] { get set }
    
    func sync()
    func sync(completionHandler: @escaping () -> Void)
    func sync(completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
}

extension SyncCoordinator {
    public func sync() {
        self.sync { _ in }
    }
    
    public func sync(completionHandler: @escaping () -> Void) {
        self.sync { _ in
            completionHandler()
        }
    }
}
