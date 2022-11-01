//
//  SyncClient.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
#if !COCOAPODS
import RoverFoundation
#endif

public protocol SyncClient {
    func task(with syncRequests: [SyncRequest], completionHandler: @escaping (HTTPResult) -> Void) -> URLSessionTask
}

extension SyncClient {
    public func queryItems(syncRequests: [SyncRequest]) -> [URLQueryItem] {
        let query: String = {
            let expression: String = {
                let signatures = syncRequests.compactMap { $0.query.signature }
                
                if signatures.isEmpty {
                    return ""
                }
                
                let joined = signatures.joined(separator: ", ")
                return "(\(joined))"
            }()
            
            let body: String = {
                syncRequests.map { $0.query.definition }.joined(separator: "\n")
            }()
            
            return """
                query Sync\(expression) {
                    \(body)
                }
                """
        }()
        
        let fragmentsUnsorted: [String]? = {
            let fragments = syncRequests.map { Set($0.query.fragments) }.reduce(Set<String>()) { $0.union($1) }
            return Array(fragments)
        }()
        
        let fragments = fragmentsUnsorted?.sorted()
        
        let variablesDict: [String: Any] = {
            syncRequests.reduce([String: Any]()) { result, request in
                request.variables.rawValue.reduce(result) { result, element in
                    var nextResult = result
                    nextResult["\(request.query.name)\(element.key.capitalized)"] = element.value
                    return nextResult
                }
            }
        }()
        
        let variables = Attributes(rawValue: variablesDict)
        
        let condensed = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "query", value: condensed)
        ]
        
        let encoder = JSONEncoder.default
        if let encoded = try? encoder.encode(variables) {
            let value = String(data: encoded, encoding: .utf8)
            let queryItem = URLQueryItem(name: "variables", value: value)
            queryItems.append(queryItem)
        }
        
        if let fragments = fragments, let encoded = try? encoder.encode(fragments) {
            let value = String(data: encoded, encoding: .utf8)
            let queryItem = URLQueryItem(name: "fragments", value: value)
            queryItems.append(queryItem)
        }
        
        return queryItems
    }
}

extension HTTPClient: SyncClient {
    public func task(with syncRequests: [SyncRequest], completionHandler: @escaping (HTTPResult) -> Void) -> URLSessionTask {
        let queryItems = self.queryItems(syncRequests: syncRequests)
        let urlRequest = self.downloadRequest(queryItems: queryItems)
        return self.downloadTask(with: urlRequest, completionHandler: completionHandler)
    }
}
