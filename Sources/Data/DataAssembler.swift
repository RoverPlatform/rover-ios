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

import UIKit
import RoverFoundation

public struct DataAssembler: Assembler {
    public var accountToken: String
    public var endpoint: URL
    
    public var flushEventsAt: Int
    public var flushEventsInterval: Double
    public var maxEventBatchSize: Int
    public var maxEventQueueSize: Int
    public var engageEndpoint: URL
    
    public init(accountToken: String, endpoint: URL = URL(string: "https://api.rover.io/graphql")!, engageEndpoint: URL = URL(string: "https://engage.rover.io")!, flushEventsAt: Int = 20, flushEventsInterval: Double = 30.0, maxEventBatchSize: Int = 100, maxEventQueueSize: Int = 1_000) {
        self.accountToken = accountToken
        self.endpoint = endpoint
        
        self.flushEventsAt = flushEventsAt
        self.flushEventsInterval = flushEventsInterval
        self.maxEventBatchSize = maxEventBatchSize
        self.maxEventQueueSize = maxEventQueueSize
        self.engageEndpoint = engageEndpoint
    }
    
    // swiftlint:disable:next function_body_length // Assemblers are fairly declarative.
    public func assemble(container: Container) {
        // MARK: Privacy
        
        container.register(PrivacyService.self) { _ in
            PrivacyService()
        }
        
        // MARK: ContextManager
        
        container.register(ContextManager.self) { resolver in
            let privacyService = resolver.resolve(PrivacyService.self)!
            return ContextManager(privacyService: privacyService)
        }
        
        // MARK: ContextProvider
        
        container.register(ContextProvider.self) { resolver in
            ModularContextProvider(
                privacyContextProvider: resolver.resolve(PrivacyService.self),
                darkModeContextProvider: resolver.resolve(DarkModeContextProvider.self),
                debugContextProvider: resolver.resolve(DebugContextProvider.self),
                locationContextProvider: resolver.resolve(LocationContextProvider.self),
                localeContextProvider: resolver.resolve(LocaleContextProvider.self),
                notificationsContextProvider: resolver.resolve(NotificationsContextProvider.self),
                pushTokenContextProvider: resolver.resolve(PushTokenContextProvider.self),
                reachabilityContextProvider: resolver.resolve(ReachabilityContextProvider.self),
                staticContextProvider: resolver.resolve(StaticContextProvider.self)!,
                telephonyContextProvider: resolver.resolve(TelephonyContextProvider.self),
                timeZoneContextProvider: resolver.resolve(TimeZoneContextProvider.self),
                userInfoContextProvider: resolver.resolve(UserInfoContextProvider.self),
                conversionsContextProvider: resolver.resolve(ConversionsContextProvider.self),
                appLastSeenContextProvider:  resolver.resolve(AppLastSeenContextProvider.self)
            )
        }
        
        // MARK: EventsClient
        
        container.register(EventsClient.self) { resolver in
            resolver.resolve(HTTPClient.self)!
        }
        
        // MARK: EventQueue
        
        container.register(EventQueue.self) { [flushEventsAt, flushEventsInterval, maxEventBatchSize, maxEventQueueSize] resolver in
            EventQueue(
                client: resolver.resolve(EventsClient.self)!,
                flushAt: flushEventsAt,
                flushInterval: flushEventsInterval,
                maxBatchSize: maxEventBatchSize,
                maxQueueSize: maxEventQueueSize
            )
        }
        
        // MARK: HTTPClient
        
        container.register(HTTPClient.self) { [accountToken, endpoint] resolver in
            let authContext = resolver.resolve(AuthenticationContext.self)!
            return HTTPClient(
                accountToken: accountToken,
                endpoint: endpoint,
                engageEndpoint: engageEndpoint,
                session: URLSession(configuration: URLSessionConfiguration.default),
                authContext: authContext
            )
        }
        
        // MARK: DarkModeContextProvider
        
        container.register(DarkModeContextProvider.self) { resolver in
            resolver.resolve(ContextManager.self)!
        }
        
        // MARK: LocaleContextProvider
        
        container.register(LocaleContextProvider.self) { resolver in
            resolver.resolve(ContextManager.self)!
        }
        
        // MARK: PushTokenContextProvider
        
        container.register(PushTokenContextProvider.self) { resolver in
            resolver.resolve(ContextManager.self)!
        }
        
        // MARK: ReachabilityContextProvider
        
        container.register(ReachabilityContextProvider.self) { resolver in
            resolver.resolve(ContextManager.self)!
        }
        
        // MARK: StaticContextProvider
        
        container.register(StaticContextProvider.self) { resolver in
            resolver.resolve(ContextManager.self)!
        }
        
        // MARK: SyncClient
        
        container.register(SyncClient.self) {  resolver in
            resolver.resolve(HTTPClient.self)!
        }
        
        // MARK: SyncCoordinator
        
        container.register(SyncCoordinator.self) { resolver in
            let client = resolver.resolve(SyncClient.self)!
            return SyncCoordinatorService(client: client)
        }
        
        // MARK: TimeZoneContextProvider
        
        container.register(TimeZoneContextProvider.self) { resolver in
            resolver.resolve(ContextManager.self)!
        }
        
        // MARK: TokenManager
        
        container.register(TokenManager.self) { resolver in
            resolver.resolve(ContextManager.self)!
        }
        
        // MARK: DeviceNameManager
        
        container.register(DeviceNameManager.self) { resolver in
            resolver.resolve(ContextManager.self)!
        }
        
        // MARK: URLSession
        
        container.register(URLSession.self) { _ in
            URLSession(configuration: URLSessionConfiguration.default)
        }
        
        // MARK: UserInfoManager
        
        container.register(UserInfoManager.self) { resolver in
            resolver.resolve(ContextManager.self)!
        }
        
        // MARK: UserInfoContextProvider
        
        container.register(UserInfoContextProvider.self) { resolver in
            resolver.resolve(ContextManager.self)!
        }
        
        // MARK: ConversionsManager
        
        container.register(ConversionsManager.self) { resolver in
            ConversionsManager()
        }
        
        // MARK: ConversionsContextProvider
        
        container.register(ConversionsContextProvider.self) { resolver in
            resolver.resolve(ConversionsManager.self)!
        }
        
        // MARK: ConversionsTrackerService
        
        container.register(ConversionsTrackerService.self) { resolver in
            resolver.resolve(ConversionsManager.self)!
        }
        
        // MARK: AppLastSeenContextManager
        
        container.register(AppLastSeenTimestampManager.self) { resolver in
            resolver.resolve(ContextManager.self)!
        }
        
        // MARK: AppLastSeenContextProvider
        
        container.register(AppLastSeenContextProvider.self) { resolver in
            resolver.resolve(ContextManager.self)!
        }
        
        // MARK: AuthContext
        
        container.register(AuthenticationContext.self) { resolver in
            AuthenticationContext()
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        let eventQueue = resolver.resolve(EventQueue.self)!
        eventQueue.restore()
        
        // Set the context provider on the event queue after assembly to allow circular dependency injection
        eventQueue.contextProvider = resolver.resolve(ContextProvider.self)!
        
        let conversionsManager = resolver.resolve(ConversionsManager.self)!
        // Migrate any conversion tags from previous versions of Rover
        conversionsManager.migrateTags()
        
        resolver.resolve(PrivacyService.self)?.refreshAllListeners()
    }
}
