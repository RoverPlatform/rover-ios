// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

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
