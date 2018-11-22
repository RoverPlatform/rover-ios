//
//  TicketmasterManager.swift
//  RoverTicketmaster
//
//  Created by Sean Rucker on 2018-09-29.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import os.log

class TicketmasterManager {
    let device: Device
    
    struct Member: Codable {
        var hostID: String
        var teamID: String
    }
    
    var member = PersistedValue<Member>(storageKey: "io.rover.RoverTicketmaster")
    
    init(device: Device) {
        self.device = device
    }
}

// MARK: TicketmasterAuthorizer

extension TicketmasterManager: TicketmasterAuthorizer {
    func setCredentials(accountManagerMemberID: String, hostMemberID: String) {
        self.member.value = Member(hostID: hostMemberID, teamID: accountManagerMemberID)
    }
    
    func clearCredentials() {
        self.member.value = nil
        self.device.updateUserInfo { attributes in
            attributes["ticketmaster"] = nil
        }
    }
}

// MARK: SyncParticipant

extension SyncQuery {
    static let ticketmaster = SyncQuery(
        name: "ticketmasterProfile",
        body: """
            attributes
            """,
        arguments: [
            SyncQuery.Argument(name: "hostMemberID", type: "String"),
            SyncQuery.Argument(name: "teamMemberID", type: "String")
        ],
        fragments: []
    )
}

extension TicketmasterManager: SyncParticipant {
    func initialRequest() -> SyncRequest? {
        guard let member = self.member.value else {
            return nil
        }
        
        return SyncRequest(
            query: .ticketmaster,
            values: [
                "hostMemberID": member.hostID,
                "teamMemberID": member.teamID
            ]
        )
    }
    
    struct Response: Decodable {
        struct Data: Decodable {
            struct Profile: Decodable {
                var attributes: Attributes?
            }
            
            var ticketmasterProfile: Profile
        }
        
        var data: Data
    }
    
    func saveResponse(_ data: Data) -> SyncResult {
        let response: Response
        do {
            response = try JSONDecoder.default.decode(Response.self, from: data)
        } catch {
            os_log("Failed to decode response: %@", log: .sync, type: .error, error.localizedDescription)
            return .failed
        }
        
        guard let attributes = response.data.ticketmasterProfile.attributes else {
            return .noData
        }
        
        self.device.updateUserInfo {
            $0["ticketmaster"] = attributes
        }
        
        return .newData(nextRequest: nil)
    }
}
