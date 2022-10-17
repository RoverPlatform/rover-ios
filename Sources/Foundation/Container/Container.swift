//
//  Container.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2017-09-19.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

public protocol Container {
    func set<Service>(entry: ServiceEntry<Service>, for key: ServiceKey)
}

extension Container {
    public func register<Service>(_ serviceType: Service.Type, factory: @escaping (Resolver) -> Service) {
        _register(serviceType, name: nil, scope: .singleton, factory: factory)
    }
    
    public func register<Service>(_ serviceType: Service.Type, name: String?, factory: @escaping (Resolver) -> Service) {
        _register(serviceType, name: name, scope: .singleton, factory: factory)
    }
    
    public func register<Service>(_ serviceType: Service.Type, scope: ServiceScope, factory: @escaping (Resolver) -> Service) {
        _register(serviceType, name: nil, scope: scope, factory: factory)
    }
    
    public func register<Service>(_ serviceType: Service.Type, name: String?, scope: ServiceScope, factory: @escaping (Resolver) -> Service) {
        _register(serviceType, name: name, scope: scope, factory: factory)
    }
    
    public func register<Service, Arg1>(_ serviceType: Service.Type, factory: @escaping (Resolver, Arg1) -> Service) {
        _register(serviceType, name: nil, scope: .singleton, factory: factory)
    }
    
    public func register<Service, Arg1>(_ serviceType: Service.Type, name: String?, factory: @escaping (Resolver, Arg1) -> Service) {
        _register(serviceType, name: name, scope: .singleton, factory: factory)
    }
    
    public func register<Service, Arg1>(_ serviceType: Service.Type, scope: ServiceScope, factory: @escaping (Resolver, Arg1) -> Service) {
        _register(serviceType, name: nil, scope: scope, factory: factory)
    }
    
    public func register<Service, Arg1>(_ serviceType: Service.Type, name: String?, scope: ServiceScope, factory: @escaping (Resolver, Arg1) -> Service) {
        _register(serviceType, name: name, scope: scope, factory: factory)
    }
    
    public func register<Service, Arg1, Arg2>(_ serviceType: Service.Type, factory: @escaping (Resolver, Arg1, Arg2) -> Service) {
        _register(serviceType, name: nil, scope: .singleton, factory: factory)
    }
    
    public func register<Service, Arg1, Arg2>(_ serviceType: Service.Type, name: String?, factory: @escaping (Resolver, Arg1, Arg2) -> Service) {
        _register(serviceType, name: name, scope: .singleton, factory: factory)
    }
    
    public func register<Service, Arg1, Arg2>(_ serviceType: Service.Type, scope: ServiceScope, factory: @escaping (Resolver, Arg1, Arg2) -> Service) {
        _register(serviceType, name: nil, scope: scope, factory: factory)
    }
    
    public func register<Service, Arg1, Arg2>(_ serviceType: Service.Type, name: String?, scope: ServiceScope, factory: @escaping (Resolver, Arg1, Arg2) -> Service) {
        _register(serviceType, name: name, scope: scope, factory: factory)
    }
    
    public func register<Service, Arg1, Arg2, Arg3>(_ serviceType: Service.Type, factory: @escaping (Resolver, Arg1, Arg2, Arg3) -> Service) {
        _register(serviceType, name: nil, scope: .singleton, factory: factory)
    }
    
    public func register<Service, Arg1, Arg2, Arg3>(_ serviceType: Service.Type, name: String?, factory: @escaping (Resolver, Arg1, Arg2, Arg3) -> Service) {
        _register(serviceType, name: name, scope: .singleton, factory: factory)
    }
    
    public func register<Service, Arg1, Arg2, Arg3>(_ serviceType: Service.Type, scope: ServiceScope, factory: @escaping (Resolver, Arg1, Arg2, Arg3) -> Service) {
        _register(serviceType, name: nil, scope: scope, factory: factory)
    }
    
    public func register<Service, Arg1, Arg2, Arg3>(_ serviceType: Service.Type, name: String?, scope: ServiceScope, factory: @escaping (Resolver, Arg1, Arg2, Arg3) -> Service) {
        _register(serviceType, name: name, scope: scope, factory: factory)
    }
    
    public func register<Service, Arg1, Arg2, Arg3, Arg4>(_ serviceType: Service.Type, factory: @escaping (Resolver, Arg1, Arg2, Arg3, Arg4) -> Service) {
        _register(serviceType, name: nil, scope: .singleton, factory: factory)
    }
    
    public func register<Service, Arg1, Arg2, Arg3, Arg4>(_ serviceType: Service.Type, name: String?, factory: @escaping (Resolver, Arg1, Arg2, Arg3, Arg4) -> Service) {
        _register(serviceType, name: name, scope: .singleton, factory: factory)
    }
    
    public func register<Service, Arg1, Arg2, Arg3, Arg4>(_ serviceType: Service.Type, scope: ServiceScope, factory: @escaping (Resolver, Arg1, Arg2, Arg3, Arg4) -> Service) {
        _register(serviceType, name: nil, scope: scope, factory: factory)
    }
    
    public func register<Service, Arg1, Arg2, Arg3, Arg4>(_ serviceType: Service.Type, name: String?, scope: ServiceScope, factory: @escaping (Resolver, Arg1, Arg2, Arg3, Arg4) -> Service) {
        _register(serviceType, name: name, scope: scope, factory: factory)
    }
    
    func _register<Service, Factory>(_ serviceType: Service.Type, name: String?, scope: ServiceScope, factory: Factory) {
        let factoryType = type(of: factory)
        let key = ServiceKey(factoryType: factoryType, name: name)
        let entry = ServiceEntry(serviceType: serviceType, scope: scope, factory: factory)
        set(entry: entry, for: key)
    }
}
