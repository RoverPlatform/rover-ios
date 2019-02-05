//
//  SyncClient.swift
//  RoverSync
//
//  Created by Sean Rucker on 2018-09-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol SyncClient {
    func task(with variables: [String: Any], completionHandler: @escaping (HTTPResult) -> Void) -> URLSessionTask
}

private let fragments = [
    "geofenceFields",
    "beaconFields",
    "campaignFields"
]

// ALSO ANDREW FIGURE OUY WHY ITS COMPLAINING ABOUT QUERY FIELDS AND FRAGMENTS BY COMPARING WITH A REQUEST FROM THE V30
private let query = """
    query Sync($geofencesFirst: Int, $geofencesAfter: String, $geofencesOrderby: GeofenceOrder, $beaconsFirst: Int, $beaconsAfter: String, $beaconsOrderby: BeaconOrder, $campaignsFirst: Int, $campaignsAfter: String, $campaignsOrderby: CampaignOrder) {
        geofences(first: $geofencesFirst, after: $geofencesAfter, orderBy: $geofencesOrderby) {
            nodes {
                ...geofenceFields
            }
            pageInfo {
                endCursor
                hasNextPage
            }
        }

        beacons(first: $beaconsFirst, after: $beaconsAfter, orderBy: $beaconsOrderby) {
            nodes {
                ...beaconFields
            }
            pageInfo {
                endCursor
                hasNextPage
            }
        }

        campaigns(first: $campaignsFirst, after: $campaignsAfter, orderBy: $campaignsOrderby) {
            nodes {
                ...campaignFields
            }
            pageInfo {
                endCursor
                hasNextPage
            }
        }
    }
"""

extension SyncClient {
    public func queryItems(variables: [String: Any]) -> [URLQueryItem] {
        let variableAttributes = Attributes(rawValue: variables)
        
        let condensed = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "query", value: condensed)
        ]
        
        let encoder = JSONEncoder.default
        if let encoded = try? encoder.encode(variableAttributes) {
            let value = String(data: encoded, encoding: .utf8)
            let queryItem = URLQueryItem(name: "variables", value: value)
            queryItems.append(queryItem)
        }
        
        if !fragments.isEmpty {
            if let encoded = try? encoder.encode(fragments) {
                let value = String(data: encoded, encoding: .utf8)
                let queryItem = URLQueryItem(name: "fragments", value: value)
                queryItems.append(queryItem)
            }
        }
        
        return queryItems
    }
}

extension HTTPClient: SyncClient {
    public func task(with variables: [String: Any], completionHandler: @escaping (HTTPResult) -> Void) -> URLSessionTask {
        let queryItems = self.queryItems(variables: variables)
        let urlRequest = self.downloadRequest(queryItems: queryItems)
        return self.downloadTask(with: urlRequest, completionHandler: completionHandler)
    }
}
