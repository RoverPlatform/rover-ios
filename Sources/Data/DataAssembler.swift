//
//  DataAssembler.swift
//  Rover
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
    
    public init(accountToken: String, endpoint: URL = URL(string: "https://api.rover.io/graphql")!, flushEventsAt: Int = 20, flushEventsInterval: Double = 30.0, maxEventBatchSize: Int = 100, maxEventQueueSize: Int = 1_000) {
        self.accountToken = accountToken
        self.endpoint = endpoint
        
        self.flushEventsAt = flushEventsAt
        self.flushEventsInterval = flushEventsInterval
        self.maxEventBatchSize = maxEventBatchSize
        self.maxEventQueueSize = maxEventQueueSize
    }
    
    // swiftlint:disable:next function_body_length // Assemblers are fairly declarative.
    public func assemble(container: Container) {
        // MARK: HTTPClient
        
        container.register(HTTPClient.self) { [accountToken, endpoint] _ in
            HTTPClient(
                accountToken: accountToken,
                endpoint: endpoint,
                session: URLSession(configuration: URLSessionConfiguration.default)
            )
        }
        
        // MARK: URLSession
        
        container.register(URLSession.self) { _ in
            URLSession(configuration: URLSessionConfiguration.default)
        }
    }
}
