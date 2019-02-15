//
//  CampaignSyncParticipant.swift
//  RoverSync
//
//  Created by Andrew Clunis on 2019-01-22.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation
import os.log

class CampaignSyncParticipant: PagingSyncParticipant {
    typealias Storage = CoreDataSyncStorage
    typealias Response = CampaignsSyncResponse
    
    let userDefaults: UserDefaults
    let syncStorage: Storage<CampaignNode>
    
    var cursorKey: String {
        return "io.rover.RoverSync.campaignsCursor"
    }
    
    init(syncStorage: Storage<CampaignNode>, userDefaults: UserDefaults) {
        self.syncStorage = syncStorage
        self.userDefaults = userDefaults
    }
    
    func nextRequestVariables(cursor: String?) -> [String: Any] {
        let orderBy: [String: Any] = [
            "field": "UPDATED_AT",
            "direction": "ASC"
        ]
        
        var values: [String: Any] = [
            "campaignsFirst": 10, // TODO: sane page size?
            "campaignsOrderBy": orderBy
        ]
        
        if let cursor = cursor {
            values["campaignsAfter"] = cursor
        }
        
        return values
    }
}

struct CampaignsSyncResponse: Decodable {
    struct Data: Decodable {
        struct Campaigns: Decodable {
            var nodes: [CampaignNode]
            var pageInfo: PageInfo
        }
        
        var campaigns: Campaigns
    }
    
    var data: Data
}

extension CampaignsSyncResponse: PagingResponse {
    var nodes: [CampaignNode]? {
        return data.campaigns.nodes
    }
    
    var pageInfo: PageInfo {
        return data.campaigns.pageInfo
    }
}

extension CampaignNode: CoreDataStorable {
    func store(context: NSManagedObjectContext) {
        let campaign: Campaign
        switch self.trigger {
        case is ScheduledCampaignTrigger:
            campaign = ScheduledCampaign.insert(into: context)
        case is AutomatedCampaignTrigger:
            // ANDREW START HERE
            campaign = AutomatedCampaign.insert(into: context)
        default:
            fatalError("Some other type somehow appeared for CampaignTrigger")
        }
    }
}
