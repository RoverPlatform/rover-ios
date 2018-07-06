//
//  ActionObserver.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2018-05-10.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol ActionObserver {
    func actionDidStart(_ action: Action)
    func action(_ action: Action, didProduceAction newAction: Action)
    func actionDidFinish(_ action: Action, errors: [Error])
}
