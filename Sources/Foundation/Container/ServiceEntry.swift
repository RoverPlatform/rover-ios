//
//  ServiceEntry.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2017-09-20.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

public class ServiceEntry<T> {
    public let serviceType: T.Type
    public let factory: ServiceFactory
    public let scope: ServiceScope
    
    public var instance: T?
    
    public init(serviceType: T.Type, scope: ServiceScope, factory: ServiceFactory) {
        self.serviceType = serviceType
        self.factory = factory
        self.scope = scope
    }
}
