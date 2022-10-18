//
//  Rover.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2017-03-31.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import Foundation
import os.log

public private(set) var shared: RoverContainer? = nil

public func initialize(assemblers: [Assembler]) {
    guard shared == nil else {
        os_log("Rover already initialized", log: .general, type: .default)
        return
    }
    
    shared = RoverContainer(assemblers: assemblers)
}

public func deinitialize() {
    shared = nil
}

public class RoverContainer {
    var services = [ServiceKey: Any]()
    
    init(assemblers: [Assembler]) {
        assemblers.forEach { $0.assemble(container: self) }
        assemblers.forEach { $0.containerDidAssemble(resolver: self) }
        
        if !Thread.isMainThread {
            os_log("Rover must be initialized on the main thread", log: .general, type: .default)
        }
    }
}

// MARK: Container

extension RoverContainer: Container {
    public func set<Service>(entry: ServiceEntry<Service>, for key: ServiceKey) {
        services[key] = entry
    }
}

// MARK: Resolver

extension RoverContainer: Resolver {
    public func entry<Service>(for key: ServiceKey) -> ServiceEntry<Service>? {
        return services[key] as? ServiceEntry<Service>
    }
}
