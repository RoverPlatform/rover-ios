//
//  SyncAssembler.swift
//  RoverSync
//
//  Created by Andrew Clunis on 2018-11-16.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import RoverFoundation

public class SyncAssembler: Assembler {
    
    init(
        
    ) {
        
    }
    
    override func assemble(container: Container) {
        // MARK: HTTPClient
        
        container.register(HTTPClient.self) { [accountToken, endpoint] _ in
            return HTTPClient(
                accountToken: accountToken,
                endpoint: endpoint,
                session: URLSession(configuration: URLSessionConfiguration.default)
            )
        }
        
        // MARK: SyncClient
        
        container.register(SyncClient.self) {  resolver in
            return resolver.resolve(HTTPClient.self)!
        }
        
        // MARK: SyncCoordinator
        
        container.register(SyncCoordinator.self) { resolver in
            let client = resolver.resolve(SyncClient.self)!
            return SyncCoordinatorService(client: client)
        }
        
        // MARK: URLSession
        
        container.register(URLSession.self) { _ in
            return URLSession(configuration: URLSessionConfiguration.default)
        }
    }
}
