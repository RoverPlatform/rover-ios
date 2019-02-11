//
//  CoreDataSyncStorage.swift
//  RoverSync
//
//  Created by Andrew Clunis on 2019-02-05.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation
import os

/// Implement this protocol for Node structures returned from Core Data, so that CoreDataSyncStorage will know how to transform and insert them into Core Data.
protocol CoreDataStorable {
    func store(context: NSManagedObjectContext)
}

/// A SyncStorage implementation for sync participants that wish to store their payloads locally in Core Data.  Handles error handling and atomicity.
struct CoreDataSyncStorage<T: CoreDataStorable>: SyncStorage {
    typealias Node = T
    
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func insertObjects(from nodes: [T]) -> Bool {
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
