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

import Foundation
import CoreData
import os
import Combine
import os.log
final class InboxPersistentContainer: NSPersistentContainer, @unchecked Sendable {

    /// Observe this state to discover when initial restore has completed.
    @Published var state: State = .loading

    init(storage: Storage) {
        os_log("Initializing Core Data PersistentContainer in storage mode: %{public}@", log: .hub, type: .debug, storage.rawValue)
        // First try to directly access the .mom file inside the .momd directory
        let model: NSManagedObjectModel
        
        if let momdURL = Bundle.module.url(forResource: "RoverCommHubModel", withExtension: "momd"),
           let momURL = momdURL.appendingPathComponent("RoverCommHubModel.mom", isDirectory: false) as URL?,
           FileManager.default.fileExists(atPath: momURL.path) {
            os_log("Loading Core Datamodel from .mom file at: %{public}@", log: .hub, type: .debug, momURL.path)

            if let loadedModel = NSManagedObjectModel(contentsOf: momURL) {
                model = loadedModel
            } else {
                fatalError("Failed to load Core Data model from existing .mom file at path: \(momURL.path)")
            }
        } else {
            fatalError("Failed to find or load Core Data model. Make sure the model file is properly included in the bundle.")
        }

    
        super.init(name: "RoverCommHubModel", managedObjectModel: model)

        switch storage {
        case .persistent:
            os_log("Successfully loaded Core Data model, now loading persistent stores...", log: .hub, type: .debug)
            configureWithSqlite()
        case .inMemory:
            os_log("Successfully loaded Core Data model, now configuring as in-memory...", log: .hub, type: .debug)
            configureAsInMemory()
        }

        viewContext.automaticallyMergesChangesFromParent = true
    }

    private func configureWithSqlite() {
        loadPersistentStoresWithRetry(isRetry: false)
    }
    
    private func loadPersistentStoresWithRetry(isRetry: Bool) {
        loadPersistentStores { description, error in
            if let error = error {
                os_log("Error loading Core Data persistent store%{public}@: %{public}@", log: .hub, type: .error, isRetry ? " (retry)" : "", error.localizedDescription)
                
                // If this was already a retry attempt, fall back to in-memory storage
                guard !isRetry else {
                    os_log("Retry attempt failed, falling back to in-memory storage", log: .hub, type: .error)
                    self.fallbackToInMemoryStorage()
                    return
                }
                
                // Get the URL from the description in order to attempt dropping and recreating the DB.
                guard let storeURL = description.url else {
                    os_log("loadPersistentStores() error state occurred, but unable to obtain store URLs to attempt dropping DB, falling back to in-memory storage", log: .hub, type: .error)
                    self.fallbackToInMemoryStorage()
                    return
                }
                
                do {
                    let coordinator = self.persistentStoreCoordinator
                    
                    // Destroy the persistent store
                    try coordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
                    os_log("Successfully destroyed Core Data persistent store at: %{public}@", log: .hub, type: .info, storeURL.path)
                    
                    // Attempt to load the persistent stores one more time
                    os_log("Attempting to retry loading persistent stores after recreation", log: .hub, type: .info)
                    self.loadPersistentStoresWithRetry(isRetry: true)
                    
                } catch {
                    os_log("Failed to reset Core Data persistent store: %{public}@", log: .hub, type: .error, error.localizedDescription)
                    os_log("Falling back to in-memory storage after failed store recreation", log: .hub, type: .error)
                    self.fallbackToInMemoryStorage()
                    
                }
                
            } else {
                os_log("Successfully loaded Core Data Hub persistent stores%{public}@", log: .hub, type: .info, isRetry ? " (after retry)" : "")
                self.state = .loaded
            }
        }
    }

    private func configureAsInMemory() {
        // Configure the persistent store to be in-memory
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        self.persistentStoreDescriptions = [description]

        self.loadPersistentStores { description, error in
            defer {
                self.state = .loaded
            }
            
            if let error = error {
                fatalError("Failed to create in-memory persistent store: \(error)")
            }
        }
    }
    
    private func fallbackToInMemoryStorage() {
        os_log("Configuring fallback to in-memory storage due to persistent store failures", log: .hub, type: .info)
        
        // Clean up any existing persistent stores
        let coordinator = self.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            do {
                try coordinator.remove(store)
            } catch {
                os_log("Failed to remove existing persistent store during fallback: %{public}@", log: .hub, type: .error, error.localizedDescription)
            }
        }
        
        // Configure for in-memory storage
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        self.persistentStoreDescriptions = [description]
        
        // Load the in-memory store
        self.loadPersistentStores { description, error in
            if let error = error {
                os_log("Critical error: Failed to create in-memory fallback store: %{public}@", log: .hub, type: .fault, error.localizedDescription)
                self.state = .failed
            } else {
                os_log("Successfully configured in-memory fallback storage", log: .hub, type: .info)
                self.state = .loaded
            }
        }
    }

    /// Drop the database and reset the persistent container. Note that will leave the store in a dropped state, and the app (and Rover SDK) should be restarted afterward.
    func reset() {
        guard let store = persistentStoreCoordinator.persistentStores.first,
              let url = store.url else {
            os_log("No persistent store found to reset", log: .hub, type: .debug)
            return
        }
        
        do {
            try persistentStoreCoordinator.remove(store)
            try persistentStoreCoordinator.destroyPersistentStore(at: url, ofType: store.type, options: nil)
            os_log("Successfully reset persistent store at: %{public}@", log: .hub, type: .info, url.path)
        } catch {
            os_log("Failed to reset persistent store: %{public}@", log: .hub, type: .error, error.localizedDescription)
        }
    }

    enum Storage: String {
        /// Using Sqlite, normal operation.
        case persistent

        /// Using in-memory, meant for SwiftUI previews and other testing scenarios.
        case inMemory
    }

    enum State: String {
        case loading
        case loaded
        case failed
    }
}


// MARK: - Badge Count Extension
extension InboxPersistentContainer {
    /// Computes the current badge count based on unread posts.
    ///
    /// Note: must be used on the main thread.
    func getBadgeCount() -> Int {
        let fetchRequest: NSFetchRequest<Post> = Post.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isRead == %@", NSNumber(value: false))

        do {
            return try self.viewContext.count(for: fetchRequest)
        } catch {
            os_log("Failed to count unread posts: %@", log: .hub, type: .error, error.localizedDescription)
            return 0
        }
    }
}
