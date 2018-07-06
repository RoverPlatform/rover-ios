//
//  DebugAssembler.swift
//  RoverDebug
//
//  Created by Sean Rucker on 2018-06-25.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

public struct DebugAssembler: Assembler {
    public init() { }
    
    public func assemble(container: Container) {
        
        // MARK: Action (settings)
        
        container.register(Action.self, name: "settings", scope: .transient) { resolver in
            return PresentViewAction(
                viewControllerToPresent: resolver.resolve(UIViewController.self, name: "settings")!,
                animated: true,
                logger: resolver.resolve(Logger.self)!
            )
        }
        
        // MARK: ContextProvider (debug)
        
        container.register(ContextProvider.self, name: "debug") { resolver in
            return DebugContextProvider(
                testDeviceManager: resolver.resolve(TestDeviceManager.self)!
            )
        }
        
        // MARK: RouteHandler (settings)
        
        container.register(RouteHandler.self, name: "settings") { resolver in
            return SettingsRouteHandler(
                actionProvider: {
                    return resolver.resolve(Action.self, name: "settings")!
                }
            )
        }
        
        // MARK: TestDeviceManager
        
        container.register(TestDeviceManager.self) { resolver in
            return TestDeviceManagerService(
                eventQueue: resolver.resolve(EventQueue.self)!,
                logger: resolver.resolve(Logger.self)!,
                userDefaults: UserDefaults.standard
            )
        }
        
        // MARK: UIViewController (settings)
        
        container.register(UIViewController.self, name: "settings", scope: .transient) { resolver in
            return SettingsViewController(
                testDeviceManager: resolver.resolve(TestDeviceManager.self)!
            )
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        let handler = resolver.resolve(RouteHandler.self, name: "settings")!
        resolver.resolve(Router.self)!.addHandler(handler)
    }
}
