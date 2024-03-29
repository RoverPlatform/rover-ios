// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

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
            os_log("Failed to decode response: %@", log: .sync, type: .error, error.logDescription)
            return nil
        }
    }
    
    public func insertObjects(from nodes: [Response.Node]) -> Bool {
        guard !nodes.isEmpty else {
            return true
        }
        
        os_log("Inserting %d objects", log: .sync, type: .debug, nodes.count)
        
        if #available(iOS 12.0, *) {
            os_signpost(.begin, log: .sync, name: "insertObjects", "count=%d", nodes.count)
        }
        
        if (context.persistentStoreCoordinator?.persistentStores.count).map({ $0 == 0 }) ?? true {
            os_log("Rover's Core Data persistent store not configured, unable to insert objects.", type: .error)
            return false
        }
    
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
                    os_log("Failed to insert objects: %@", log: .sync, type: .error, $0.logDescription)
                }
            } else {
                os_log("Failed to insert objects: %@", log: .sync, type: .error, error.logDescription)
            }
            
            return false
        }
        
        os_log("Successfully inserted %d objects", log: .sync, type: .debug, nodes.count)
        
        if #available(iOS 12.0, *) {
            os_signpost(.end, log: .sync, name: "insertObjects", "count=%d", nodes.count)
        }
        
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
