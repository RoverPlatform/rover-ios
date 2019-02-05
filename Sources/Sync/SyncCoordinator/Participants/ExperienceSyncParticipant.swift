//
//  ExperienceSyncParticipant.swift
//  RoverSync
//
//  Created by Andrew Clunis on 2019-02-04.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

class ExperienceSyncParticipant: PagingSyncParticipant {
    typealias Response = ExperienceSyncResponse

    let syncStorage: ExperienceStore

    let userDefaults: UserDefaults

    var cursorKey: String {
        return "io.rover.RoverSync.campaignsCursor"
    }

    init(
        experienceStore: ExperienceStore,
        userDefaults: UserDefaults
    ) {
        self.userDefaults = userDefaults
        self.syncStorage = experienceStore
    }

    func nextRequestVariables(cursor: String?) -> [String: Any] {
        let orderBy: [String: Any] = [
            "field": "UPDATED_AT",
            "direction": "ASC"
        ]

        var values: [String: Any] = [
            "experiencesFirst": 10, // TODO: sane page size?
            "experiencesOrderBy": orderBy
        ]

        if let cursor = cursor {
            values["experiencesAfter"] = cursor
        }

        return values
    }
}

struct ExperienceSyncResponse: Decodable {
    struct Data: Decodable {
        struct Campaigns: Decodable {
            var nodes: [Experience]
            var pageInfo: PageInfo
        }

        var experiences: Campaigns
    }

    var data: Data
}

extension ExperienceSyncResponse: PagingResponse {
    var nodes: [Experience]? {
        return data.experiences.nodes
    }

    var pageInfo: PageInfo {
        return data.experiences.pageInfo
    }
}

extension ExperienceStore: SyncStorage {
    public typealias Node = Experience
    
    public func insertObjects(from nodes: [Experience]) -> Bool {
        for experienceNode in nodes {
            if !self.insert(experience: experienceNode) {
                return false
            }
        }
        return true
    }
}
