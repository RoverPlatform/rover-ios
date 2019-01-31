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
    
    func insertObject(from node: CampaignNode) {
        Campaign.insert(from: node, into: self.context)
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

extension Campaign {
    
    static func insert(from campaignNode: CampaignNode, into managedObjectContext: NSManagedObjectContext) {
        let campaign: Campaign
        switch campaignNode.trigger {
        case is ScheduledCampaignTrigger:
            campaign = ScheduledCampaign.insert(into: managedObjectContext)
        case is AutomatedCampaignTrigger:
            campaign = AutomatedCampaign.insert(into: managedObjectContext)
        default:
            fatalError("Some other type somehow appeared for CampaignTrigger")
        }
    }
}

extension CampaignsSyncResponse: PagingResponse {
    var nodes: [CampaignNode]? {
        return data.campaigns.nodes
    }
    
    var pageInfo: PageInfo {
        return data.campaigns.pageInfo
    }
}
