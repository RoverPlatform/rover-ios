//
//  Resolver.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2017-09-15.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

public protocol Resolver: AnyObject {
    func entry<Service>(for key: ServiceKey) -> ServiceEntry<Service>?
}

extension Resolver {
    public func resolve<Service>(_ serviceType: Service.Type) -> Service? {
        return resolve(serviceType, name: nil)
    }
    
    public func resolve<Service, Arg1>(_ serviceType: Service.Type, arguments arg1: Arg1) -> Service? {
        return resolve(serviceType, name: nil, arguments: arg1)
    }
    
    public func resolve<Service, Arg1, Arg2>(_ serviceType: Service.Type, arguments arg1: Arg1, _ arg2: Arg2) -> Service? {
        return resolve(serviceType, name: nil, arguments: arg1, arg2)
    }
    
    public func resolve<Service, Arg1, Arg2, Arg3>(_ serviceType: Service.Type, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3) -> Service? {
        return resolve(serviceType, name: nil, arguments: arg1, arg2, arg3)
    }
    
    public func resolve<Service, Arg1, Arg2, Arg3, Arg4>(_ serviceType: Service.Type, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4) -> Service? {
        return resolve(serviceType, name: nil, arguments: arg1, arg2, arg3, arg4)
    }
    
    public func resolve<Service>(_ serviceType: Service.Type, name: String?) -> Service? {
        typealias Factory = (Resolver) -> Service
        return _resolve(name: name) { (factory: Factory) -> Service in factory(self) }
    }
    
    public func resolve<Service, Arg1>(_ serviceType: Service.Type, name: String?, arguments arg1: Arg1) -> Service? {
        typealias Factory = (Resolver, Arg1) -> Service
        return _resolve(name: name) { (factory: Factory) -> Service in factory(self, arg1) }
    }
    
    public func resolve<Service, Arg1, Arg2>(_ serviceType: Service.Type, name: String?, arguments arg1: Arg1, _ arg2: Arg2) -> Service? {
        typealias Factory = (Resolver, Arg1, Arg2) -> Service
        return _resolve(name: name) { (factory: Factory) -> Service in factory(self, arg1, arg2) }
    }
    
    public func resolve<Service, Arg1, Arg2, Arg3>(_ serviceType: Service.Type, name: String?, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3) -> Service? {
        typealias Factory = (Resolver, Arg1, Arg2, Arg3) -> Service
        return _resolve(name: name) { (factory: Factory) -> Service in factory(self, arg1, arg2, arg3) }
    }
    
    // These functions use explicitly rolled out 'varargs', so in this case the parameter count is reasonable, so silence the param count warning.
    // swiftlint:disable:next function_parameter_count
    public func resolve<Service, Arg1, Arg2, Arg3, Arg4>(_ serviceType: Service.Type, name: String?, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4) -> Service? {
        typealias Factory = (Resolver, Arg1, Arg2, Arg3, Arg4) -> Service
        return _resolve(name: name) { (factory: Factory) -> Service in factory(self, arg1, arg2, arg3, arg4) }
    }
    
    func _resolve<Service, Factory>(name: String?, invoker: (Factory) -> Service) -> Service? {
        let key = ServiceKey(factoryType: Factory.self, name: name)
        
        guard let entry: ServiceEntry<Service> = entry(for: key), let factory = entry.factory as? Factory else {
            return nil
        }
        
        if entry.scope == .transient {
            return invoker(factory)
        }
        
        if let persistedInstance = entry.instance {
            return persistedInstance
        }
        
        let resolvedInstance = invoker(factory)
        entry.instance = resolvedInstance
        return resolvedInstance
    }
}
