//
//  Rover.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2017-03-31.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

public class Rover {
    static var sharedInstance: Rover?
    
    public static var shared: Resolver? {
        return sharedInstance
    }
    
    public static func initialize(assemblers: [Assembler]) {
        if let sharedInstance = sharedInstance {
            if let logger = sharedInstance.resolve(Logger.self) {
                logger.warn("Rover already initialized")
            }
            return
        }
        
        let rover = Rover()
        
        assemblers.forEach { $0.assemble(container: rover) }
        assemblers.forEach { $0.containerDidAssemble(resolver: rover) }
        
        if let logger = rover.resolve(Logger.self) {
            logger.warnUnlessMainThread("Rover must be initialized on the main thread")
        }
        
        sharedInstance = rover
    }
    
    public static func deinitialize() {
        sharedInstance = nil
    }
    
    var services = [ServiceKey: Any]()
}

// MARK: Container

extension Rover: Container {
    public func set<Service>(entry: ServiceEntry<Service>, for key: ServiceKey) {
        services[key] = entry
    }
}

// MARK: Resolver

extension Rover: Resolver {
    public func entry<Service>(for key: ServiceKey) -> ServiceEntry<Service>? {
        return services[key] as? ServiceEntry<Service>
    }
}
