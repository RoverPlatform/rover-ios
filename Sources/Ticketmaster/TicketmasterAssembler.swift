//
//  TicketmasterAssembler.swift
//  RoverTicketmaster
//
//  Created by Sean Rucker on 2018-09-29.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

#if !COCOAPODS
import RoverFoundation
import RoverData
#endif

public class TicketmasterAssembler: Assembler {
    public init() {
    }
    
    public func assemble(container: Container) {
        container.register(TicketmasterAuthorizer.self) { resolver in
            resolver.resolve(TicketmasterManager.self)!
        }
        
        container.register(TicketmasterManager.self) { resolver in
            let userInfoManager = resolver.resolve(UserInfoManager.self)!
            let eventQueue = resolver.resolve(EventQueue.self)!
            return TicketmasterManager(userInfoManager: userInfoManager, eventQueue: eventQueue)
        }
        
        container.register(SyncParticipant.self, name: "ticketmaster") { resolver in
            resolver.resolve(TicketmasterManager.self)!
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        let participant = resolver.resolve(SyncParticipant.self, name: "ticketmaster")!
        resolver.resolve(SyncCoordinator.self)!.participants.append(participant)
    }
}
