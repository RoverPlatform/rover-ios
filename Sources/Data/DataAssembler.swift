//
//  DataAssembler.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-06-01.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

public struct DataAssembler: Assembler {

    
    public var flushEventsAt: Int
    public var flushEventsInterval: Double
    public var maxEventBatchSize: Int
    public var maxEventQueueSize: Int
    
    public init(flushEventsAt: Int = 20, flushEventsInterval: Double = 30.0, maxEventBatchSize: Int = 100, maxEventQueueSize: Int = 1000) {
        self.flushEventsAt = flushEventsAt
        self.flushEventsInterval = flushEventsInterval
        self.maxEventBatchSize = maxEventBatchSize
        self.maxEventQueueSize = maxEventQueueSize
    }
    
    public func assemble(container: Container) {
        
        // MARK: ContextManager
        
        container.register(ContextManager.self) { resolver in
            return ContextManager()
        }
        
        // MARK: ContextProvider
        
        container.register(ContextProvider.self) { resolver in
            return ModularContextProvider(
                adSupportContextProvider: resolver.resolve(AdSupportContextProvider.self),
                bluetoothContextProvider: resolver.resolve(BluetoothContextProvider.self),
                debugContextProvider: resolver.resolve(DebugContextProvider.self),
                locationContextProvider: resolver.resolve(LocationContextProvider.self),
                localeContextProvider: resolver.resolve(LocaleContextProvider.self),
                notificationsContextProvider: resolver.resolve(NotificationsContextProvider.self),
                pushTokenContextProvider: resolver.resolve(PushTokenContextProvider.self),
                reachabilityContextProvider: resolver.resolve(ReachabilityContextProvider.self),
                staticContextProvider: resolver.resolve(StaticContextProvider.self)!,
                telephonyContextProvider: resolver.resolve(TelephonyContextProvider.self),
                timeZoneContextProvider: resolver.resolve(TimeZoneContextProvider.self),
                userInfoContextProvider: resolver.resolve(UserInfoContextProvider.self)
            )
        }

        // MARK: LocaleContextProvider
        
        container.register(LocaleContextProvider.self) { resolver in
            return resolver.resolve(ContextManager.self)!
        }
        
        // MARK: PushTokenContextProvider
        
        container.register(PushTokenContextProvider.self) { resolver in
            return resolver.resolve(ContextManager.self)!
        }
        
        // MARK: ReachabilityContextProvider
        
        container.register(ReachabilityContextProvider.self) { resolver in
            return resolver.resolve(ContextManager.self)!
        }
        
        // MARK: StaticContextProvider
        
        container.register(StaticContextProvider.self) { resolver in
            return resolver.resolve(ContextManager.self)!
        }

        // MARK: TimeZoneContextProvider
        
        container.register(TimeZoneContextProvider.self) { resolver in
            return resolver.resolve(ContextManager.self)!
        }
        
        // MARK: TokenManager
        
        container.register(TokenManager.self) { resolver in
            return resolver.resolve(ContextManager.self)!
        }
        
        // MARK: UserInfoManager
        
        container.register(UserInfoManager.self) { resolver in
            return resolver.resolve(ContextManager.self)!
        }
        
        // MARK: UserInfoContextProvider
        
        container.register(UserInfoContextProvider.self) { resolver in
            return resolver.resolve(ContextManager.self)!
        }
    }
}
