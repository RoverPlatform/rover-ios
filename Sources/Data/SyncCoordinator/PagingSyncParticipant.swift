//
//  PagingSyncParticipant.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-09.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation
import os

public protocol PagingSyncParticipant: SyncParticipant {
    associatedtype Response: PagingResponse
    
    var context: NSManagedObjectContext { get }
    var cursorKey: String { get }
    var userDefaults: UserDefaults { get }
    
    func insertObject(from node: Response.Node)
    func nextRequest(cursor: String?) -> SyncRequest
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
    
    public func initialRequest() -> SyncRequest? {
        return nextRequest(cursor: self.cursor)
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
            os_log("Failed to decode response: %@", log: .sync, type: .error, error.localizedDescription)
            return nil
        }
    }
    
    public func insertObjects(from nodes: [Response.Node]) -> Bool {
        guard !nodes.isEmpty else {
            return true
        }
        
        os_log("Inserting %d objects", log: .sync, type: .debug, nodes.count)
        
        #if swift(>=4.2)
        if #available(iOS 12.0, *) {
            os_signpost(.begin, log: .sync, name: "insertObjects", "count=%d", nodes.count)
        }
        #endif
        
        var saveError: Error?
        context.performAndWait { [context] in
            for node in nodes {
                insertObject(from: node)
            }
            
            do {
                try context.save()
                context.reset()
            } catch {
                saveError = error
                context.rollback()
            }
        }
        
        if let error = saveError {
            if let multipleErrors = (error as NSError).userInfo[NSDetailedErrorsKey] as? [Error] {
                multipleErrors.forEach {
                    os_log("Failed to insert objects: %@", log: .sync, type: .error, $0.localizedDescription)
                }
            } else {
                os_log("Failed to insert objects: %@", log: .sync, type: .error, error.localizedDescription)
            }
            
            return false
        }
        
        os_log("Successfully inserted %d objects", log: .sync, type: .debug, nodes.count)
        
        #if swift(>=4.2)
        if #available(iOS 12.0, *) {
            os_signpost(.end, log: .sync, name: "insertObjects", "count=%d", nodes.count)
        }
        #endif
        
        return true
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
            return .newData(nextRequest: nil)
        }
        
        let nextRequest = self.nextRequest(cursor: endCursor)
        return .newData(nextRequest: nextRequest)
    }
}
