//
//  BlockObserver.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2018-05-10.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public struct BlockObserver: ActionObserver {
    public typealias StartHandler = (Action) -> Void
    public typealias ProduceHandler = (Action, Action) -> Void
    public typealias FinishHandler = (Action, [Error]) -> Void
    
    private let startHandler: StartHandler?
    private let produceHandler: ProduceHandler?
    private let finishHandler: FinishHandler?
    
    public init(startHandler: StartHandler? = nil, produceHandler: ProduceHandler? = nil, finishHandler: FinishHandler? = nil) {
        self.startHandler = startHandler
        self.produceHandler = produceHandler
        self.finishHandler = finishHandler
    }
    
    public func actionDidStart(_ action: Action) {
        startHandler?(action)
    }
    
    public func action(_ action: Action, didProduceAction newAction: Action) {
        produceHandler?(action, newAction)
    }
    
    public func actionDidFinish(_ action: Action, errors: [Error]) {
        finishHandler?(action, errors)
    }
}
