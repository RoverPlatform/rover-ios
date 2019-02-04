//
//  ExperienceSyncParticipant.swift
//  RoverSync
//
//  Created by Andrew Clunis on 2019-02-04.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
//
//class ExperienceSyncParticipant: PagingSyncParticipant {
//    typealias Response = ExperienceSyncResponse
//
//    private let experienceStore: ExperienceStore
//
//    let userDefaults: UserDefaults
//
//    var cursorKey: String {
//        return "io.rover.RoverSync.campaignsCursor"
//    }
//
//    init(
//        experienceStore: ExperienceStore,
//        userDefaults: UserDefaults
//    ) {
//        self.userDefaults = userDefaults
//    }
//
//    func nextRequest(cursor: String?) -> SyncRequest {
//        let orderBy: [String: Any] = [
//            "field": "UPDATED_AT",
//            "direction": "ASC"
//        ]
//
//        var values: [String: Any] = [
//            "first": 10, // TODO: sane page size?
//            "orderBy": orderBy
//        ]
//
//        if let cursor = cursor {
//            values["after"] = cursor
//        }
//
//        return SyncRequest(query: SyncQuery.campaigns, values: values)
//    }
//
//    func insertObject(from node: Experience) {
//        // TODO
//    }
//
//}
//
//struct ExperienceSyncResponse: Decodable {
//    struct Data: Decodable {
//        struct Campaigns: Decodable {
//            var nodes: [Experience]
//            var pageInfo: PageInfo
//        }
//
//        var experiences: Campaigns
//    }
//
//    var data: Data
//}
//
//extension ExperienceSyncResponse: PagingResponse {
//    var nodes: [Experience]? {
//        return data.experiences.nodes
//    }
//
//    var pageInfo: PageInfo {
//        return data.experiences.pageInfo
//    }
//}
