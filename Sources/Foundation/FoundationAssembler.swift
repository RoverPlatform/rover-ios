//
//  FoundationAssembler.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2017-10-24.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

public struct FoundationAssembler: Assembler {
    public init() { }

    public func assemble(container: Container) {
        container.register(Dispatcher.self) { _ in
            DispatcherService()
        }
    }
}
