//
//  CampaignSyncParticipant.swift
//  RoverSync
//
//  Created by Andrew Clunis on 2019-01-22.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import os.log
import CoreData

class CampaignSyncParticipant: PagingSyncParticipant {
    typealias Response = CampaignsSyncResponse
    
    let context: NSManagedObjectContext
    let userDefaults: UserDefaults
    
    var cursorKey: String {
        return "io.rover.RoverSync.campaignsCursor"
    }
    
    init(context: NSManagedObjectContext, userDefaults: UserDefaults) {
        self.context = context
        self.userDefaults = userDefaults
    }
    
    func nextRequest(cursor: String?) -> SyncRequest {
        let orderBy: [String: Any] = [
            "field": "UPDATED_AT",
            "direction": "ASC"
        ]
        
        var values: [String: Any] = [
            "first": 10, // TODO: sane page size?
            "orderBy": orderBy
        ]
        
        if let cursor = cursor {
            values["after"] = cursor
        }
        
        return SyncRequest(query: SyncQuery.campaigns, values: values)
    }
    
    func insertObject(from node: Campaign) {
        
        // TODO: this is where the DTO to model transform will happen.  Perhaps
        // factor it out into extension method.
        
        // ANDREW START HERE AND MATCH TRIGGER TO CHOOSE TO CREATE AUTOMATEDCAMPAIGN OR SCHEDULEDCAMPAIGN ETC.

    }
}

struct CampaignsSyncResponse: Decodable {
    struct Data: Decodable {
        struct Campaigns: Decodable {
            var nodes: [Campaign]
            var pageInfo: PageInfo
        }
        var campaigns: Campaigns
    }
    
    var data: Data
}

extension CampaignsSyncResponse: PagingResponse {
    var nodes: [Campaign]? {
        return data.campaigns.nodes
    }
    
    var pageInfo: PageInfo {
        return data.campaigns.pageInfo
    }
}
