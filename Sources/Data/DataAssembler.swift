//
//  DataAssembler.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-06-01.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

public struct DataAssembler: Assembler {
    public var accountToken: String
    public var endpoint: URL
    
    public var flushEventsAt: Int
    public var flushEventsInterval: Double
    public var maxEventBatchSize: Int
    public var maxEventQueueSize: Int
    
    public var isAutoFetchEnabled: Bool
    
    public init(accountToken: String, endpoint: URL = URL(string: "https://api.rover.io/graphql")!, flushEventsAt: Int = 20, flushEventsInterval: Double = 30.0, maxEventBatchSize: Int = 100, maxEventQueueSize: Int = 1000, isAutoFetchEnabled: Bool = true) {
        self.accountToken = accountToken
        self.endpoint = endpoint
        
        self.flushEventsAt = flushEventsAt
        self.flushEventsInterval = flushEventsInterval
        self.maxEventBatchSize = maxEventBatchSize
        self.maxEventQueueSize = maxEventQueueSize
        
        self.isAutoFetchEnabled = isAutoFetchEnabled
    }
    
    public func assemble(container: Container) {
        
        // MARK: GraphQLClient
        
        container.register(GraphQLClient.self) { [accountToken, endpoint] resolver in
            let session = URLSession(configuration: URLSessionConfiguration.default)
            return GraphQLClientService(accountToken: accountToken, endpoint: endpoint, session: session)
        }
        
        // MARK: ContextProvider (app)
        
        container.register(ContextProvider.self, name: "app") { resolver in
            let logger = resolver.resolve(Logger.self)!
            return AppContextProvider(bundle: Bundle.main, logger: logger)
        }
        
        // MARK: ContextProvider (userInfo)
        
        container.register(ContextProvider.self, name: "userInfo") { resolver in
            let userInfo = resolver.resolve(UserInfo.self)!
            return UserInfoContextProvider(userInfo: userInfo)
        }
        
        // MARK: ContextProvider (device)
        
        container.register(ContextProvider.self, name: "device") { resolver in
            let logger = resolver.resolve(Logger.self)!
            return DeviceContextProvider(device: UIDevice.current, logger: logger)
        }
        
        // MARK: ContextProvider (locale)
        
        container.register(ContextProvider.self, name: "locale") { resolver in
            let logger = resolver.resolve(Logger.self)!
            return LocaleContextProvider(locale: Locale.current, logger: logger)
        }
        
        // MARK: ContextProvider (pushEnvironment)
        
        container.register(ContextProvider.self, name: "pushEnvironment") { resolver in
            let logger = resolver.resolve(Logger.self)!
            return PushEnvironmentContextProvider(bundle: Bundle.main, logger: logger)
        }
        
        // MARK: ContextProvider (pushToken)
        
        container.register(ContextProvider.self, name: "pushToken") { resolver in
            let tokenManager = resolver.resolve(TokenManager.self)!
            return PushTokenContextProvider(tokenManager: tokenManager)
        }
        
        // MARK: ContextProvider (reachability)
        
        container.register(ContextProvider.self, name: "reachability") { resolver in
            let logger = resolver.resolve(Logger.self)!
            return ReachabilityContextProvider(logger: logger)
        }
        
        // MARK: ContextProvider (screen)
        
        container.register(ContextProvider.self, name: "screen") { resolver in
            return ScreenContextProvider(screen: UIScreen.main)
        }
        
        // MARK: ContextProvider (sdk)
        
        container.register(ContextProvider.self, name: "sdk") { resolver in
            let logger = resolver.resolve(Logger.self)!
            return SDKContextProvider(logger: logger)
        }
        
        // MARK: ContextProvider (timeZone)
        
        container.register(ContextProvider.self, name: "timeZone") { resolver in
            let timeZone = NSTimeZone.local as NSTimeZone
            return TimeZoneContextProvider(timeZone: timeZone)
        }
        
        // MARK: UserInfo
        
        container.register(UserInfo.self) { resolver in
            let eventQueue = resolver.resolve(EventQueue.self)!
            let logger = resolver.resolve(Logger.self)!
            return UserInfoService(eventQueue: eventQueue, logger: logger, userDefaults: UserDefaults.standard)
        }
        
        // MARK: EventQueue
        
        container.register(EventQueue.self) { [flushEventsAt, flushEventsInterval, maxEventBatchSize, maxEventQueueSize] resolver in
            return EventQueueService(
                client: resolver.resolve(GraphQLClient.self)!,
                flushAt: flushEventsAt,
                flushInterval: flushEventsInterval,
                logger: resolver.resolve(Logger.self)!,
                maxBatchSize: maxEventBatchSize,
                maxQueueSize: maxEventQueueSize
            )
        }
        
        // MARK: StateFetcher
        
        container.register(StateFetcher.self) { resolver in
            let client = resolver.resolve(GraphQLClient.self)!
            let logger = resolver.resolve(Logger.self)!
            return StateFetcherService(client: client, logger: logger)
        }
        
        // MARK: TokenManager
        
        container.register(TokenManager.self) { resolver in
            return TokenManagerService(
                eventQueue: resolver.resolve(EventQueue.self)!,
                logger: resolver.resolve(Logger.self)!,
                userDefaults: UserDefaults.standard
            )
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        let userInfo = resolver.resolve(UserInfo.self)!
        userInfo.restore()
        
        let eventQueue = resolver.resolve(EventQueue.self)!
        let contextProviders = [
            resolver.resolve(ContextProvider.self, name: "app"),
            resolver.resolve(ContextProvider.self, name: "bluetooth"),
            resolver.resolve(ContextProvider.self, name: "debug"),
            resolver.resolve(ContextProvider.self, name: "device"),
            resolver.resolve(ContextProvider.self, name: "locale"),
            resolver.resolve(ContextProvider.self, name: "location"),
            resolver.resolve(ContextProvider.self, name: "notificationAuthorization"),
            resolver.resolve(ContextProvider.self, name: "pushEnvironment"),
            resolver.resolve(ContextProvider.self, name: "pushToken"),
            resolver.resolve(ContextProvider.self, name: "reachability"),
            resolver.resolve(ContextProvider.self, name: "screen"),
            resolver.resolve(ContextProvider.self, name: "sdk"),
            resolver.resolve(ContextProvider.self, name: "telephony"),
            resolver.resolve(ContextProvider.self, name: "timeZone"),
            resolver.resolve(ContextProvider.self, name: "userInfo")
            ].compactMap { $0 }
        
        eventQueue.addContextProviders(contextProviders)
        eventQueue.restore()
        
        var stateFetcher = resolver.resolve(StateFetcher.self)!
        stateFetcher.isAutoFetchEnabled = isAutoFetchEnabled
    }
}
