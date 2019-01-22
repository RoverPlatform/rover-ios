//
//  SyncAssembler.swift
//  RoverSync
//
//  Created by Andrew Clunis on 2018-11-16.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import RoverFoundation
import CoreData

public class SyncAssembler: Assembler {
    public var accountToken: String
    public var endpoint: URL
    
    public init(
        accountToken: String,
        endpoint: URL = URL(string: "https://api.rover.io/graphql")!
    ) {
        self.accountToken = accountToken
        self.endpoint = endpoint
    }
    
    public func assemble(container: Container) {
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
        
        // MARK: Location
        
        container.register(GeofencesSyncParticipant.self) { (resolver) in
            return GeofencesSyncParticipant(
                context: resolver.resolve(NSManagedObjectContext.self, name: "backgroundContext")!,
                userDefaults: UserDefaults.standard
            )
        }
        
        container.register(BeaconsSyncParticipant.self) { (resolver) in
            return BeaconsSyncParticipant(
                context: resolver.resolve(NSManagedObjectContext.self, name: "backgroundContext")!,
                userDefaults: UserDefaults.standard
            )
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        let syncCoordinator = resolver.resolve(SyncCoordinator.self)!
    
        syncCoordinator.participants.append(resolver.resolve(GeofencesSyncParticipant.self)!)
        syncCoordinator.participants.append(resolver.resolve(BeaconsSyncParticipant.self)!)
        syncCoordinator.sync()

    }
}
