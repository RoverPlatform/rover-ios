//
//  ServiceKey.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2017-09-20.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

public struct ServiceKey: Hashable, Equatable {
    public var factoryType: ServiceFactory.Type
    public var name: String?
    
    public init(factoryType: ServiceFactory.Type, name: String?) {
        self.factoryType = factoryType
        self.name = name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(factoryType).hashValue ^ (name?.hashValue ?? 0))
    }
    
    public static func == (lhs: ServiceKey, rhs: ServiceKey) -> Bool {
        return lhs.factoryType == rhs.factoryType && lhs.name == rhs.name
    }
}
