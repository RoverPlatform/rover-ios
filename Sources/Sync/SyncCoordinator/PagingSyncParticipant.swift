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

public protocol SyncStorage {
    associatedtype Node
    
    func insertObjects(from nodes: [Node]) -> Bool
}

public protocol CoreDataStorable {
    func store(context: NSManagedObjectContext)
}

public struct CoreDataSyncStorage<T: CoreDataStorable>: SyncStorage {
    public typealias Node = T
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    public func insertObjects(from nodes: [T]) -> Bool {
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
                node.store(context: context)
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
}

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
