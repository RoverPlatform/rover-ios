//
//  Assembler.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2017-09-15.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

public protocol Assembler {
    func assemble(container: Container)
    func containerDidAssemble(resolver: Resolver)
}

extension Assembler {
    public func assemble(container: Container) { }
    public func containerDidAssemble(resolver: Resolver) { }
}
