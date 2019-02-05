//
//  SyncAssembler.swift
//  RoverSync
//
//  Created by Andrew Clunis on 2018-11-16.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation
import RoverFoundation

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
            HTTPClient(
                accountToken: accountToken,
                endpoint: endpoint,
                session: URLSession(configuration: URLSessionConfiguration.default)
            )
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
        
        // MARK: URLSession
        
        container.register(URLSession.self) { _ in
            URLSession(configuration: URLSessionConfiguration.default)
        }
        
        // MARK: Campaigns
        
        container.register(CampaignSyncParticipant.self) { resolver in
            CampaignSyncParticipant(
                userDefaults: UserDefaults.standard,
                syncStorage: CoreDataSyncStorage(context: resolver.resolve(NSManagedObjectContext.self, name: "backgroundContext")!)
            )
        }
        
        // MARK: Location
        
        container.register(GeofencesSyncParticipant.self) { resolver in
            GeofencesSyncParticipant(
                userDefaults: UserDefaults.standard,
                syncStorage: CoreDataSyncStorage(context: resolver.resolve(NSManagedObjectContext.self, name: "backgroundContext")!)
            )
        }
        
        container.register(BeaconsSyncParticipant.self) { resolver in
            BeaconsSyncParticipant(
                userDefaults: UserDefaults.standard,
                syncStorage: CoreDataSyncStorage(context: resolver.resolve(NSManagedObjectContext.self, name: "backgroundContext")!)
            )
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        let syncCoordinator = resolver.resolve(SyncCoordinator.self)!
    
        syncCoordinator.participants.append(resolver.resolve(GeofencesSyncParticipant.self)!)
        syncCoordinator.participants.append(resolver.resolve(BeaconsSyncParticipant.self)!)
        syncCoordinator.participants.append(resolver.resolve(CampaignSyncParticipant.self)!)
    }
}
