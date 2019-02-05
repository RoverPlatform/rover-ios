//
//  PagingSyncParticipant.swift
//  RoverSync
//
//  Created by Sean Rucker on 2018-09-09.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation
import os

public protocol PagingSyncParticipant: SyncParticipant {
    associatedtype Response: PagingResponse
    
    associatedtype Storage: SyncStorage where Storage.Node == Response.Node
    
    var syncStorage: Storage { get }
    var cursorKey: String { get }
    var userDefaults: UserDefaults { get }
    
    func nextRequestVariables(cursor: String?) -> [String: Any]
}

extension PagingSyncParticipant {
    public var cursor: String? {
        get {
            return userDefaults.value(forKey: cursorKey) as? String
        }
        set {
            if let newValue = newValue {
                userDefaults.set(newValue, forKey: cursorKey)
            } else {
                userDefaults.removeObject(forKey: cursorKey)
            }
        }
    }
    
    public func initialRequestVariables() -> [String: Any]? {
        return nextRequestVariables(cursor: self.cursor)
    }
    
    public func saveResponse(_ data: Data) -> SyncResult {
        guard let response = decode(data) else {
            return .failed
        }
        
        guard let nodes = response.nodes else {
            return .noData
        }
        
        guard insertObjects(from: nodes) else {
            return .failed
        }
        
        updateCursor(from: response)
        return result(from: response)
    }
    
    public func decode(_ data: Data) -> Response? {
        do {
            return try JSONDecoder.default.decode(Response.self, from: data)
        } catch {
            os_log("Failed to decode response: %@", log: .sync, type: .error, String(describing: error))
            return nil
        }
    }
    
    public func insertObjects(from nodes: [Response.Node]) -> Bool {
        return self.syncStorage.insertObjects(from: nodes)
    }
    
    public func updateCursor(from response: Response) {
        if let endCursor = response.pageInfo.endCursor {
            self.cursor = endCursor
        }
    }
    
    public func result(from response: Response) -> SyncResult {
        guard let nodes = response.nodes, !nodes.isEmpty else {
            return .noData
        }
        
        let pageInfo = response.pageInfo
        guard pageInfo.hasNextPage, let endCursor = pageInfo.endCursor else {
            return .newData(nextRequestVariables: nil)
        }

        let nextRequestVariables = self.nextRequestVariables(cursor: endCursor)
        return .newData(nextRequestVariables: nextRequestVariables)
    }
}
