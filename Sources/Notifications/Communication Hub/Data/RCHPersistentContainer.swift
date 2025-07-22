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
final class RCHPersistentContainer: NSPersistentContainer, @unchecked Sendable {

    /// Observe this bool to discover when initial restore has completed.
    ///
    /// WIll never revert back to false.
    @Published var loaded: Bool = false

    init(storage: Storage) {
        os_log("Initializing Core Data CommunicationPersistentContainer in storage mode: %{public}@", log: .communicationHub, type: .debug, storage.rawValue)
        // First try to directly access the .mom file inside the .momd directory
        let model: NSManagedObjectModel
        
        if let momdURL = Bundle.module.url(forResource: "RoverCommHubModel", withExtension: "momd"),
           let momURL = momdURL.appendingPathComponent("RoverCommHubModel.mom", isDirectory: false) as URL?,
           FileManager.default.fileExists(atPath: momURL.path) {
            os_log("Loading Core Datamodel from .mom file at: %{public}@", log: .communicationHub, type: .debug, momURL.path)

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
            os_log("Successfully loaded Core Data model, now loading persistent stores...", log: .communicationHub, type: .debug)
            configureWithSqlite()
        case .inMemory:
            os_log("Successfully loaded Core Data model, now configuring as in-memory...", log: .communicationHub, type: .debug)
            configureAsInMemory()
        }

        viewContext.automaticallyMergesChangesFromParent = true
    }

    private func configureWithSqlite() {
        loadPersistentStores { description, error in
            defer {
                self.loaded = true
            }

            if let error = error {
                os_log("Error loading Core Data persistent store: %{public}@", log: .communicationHub, type: .error, error.localizedDescription)

                // Get the URL from the description
                if let url = description.url {
                    do {
                        let coordinator = self.persistentStoreCoordinator

                        // Destroy the persistent store
                        try coordinator.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
                        os_log("Successfully destroyed Core Data persistent store at: %{public}@", log: .communicationHub, type: .info, url.path)

                        // Recreate the persistent store
                        try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
                        os_log("Successfully recreated Core Data persistent store at: %{public}@", log: .communicationHub, type: .info, url.path)

                    } catch {
                        os_log("Failed to reset Core Data persistent store: %{public}@", log: .communicationHub, type: .error, error.localizedDescription)
                        fatalError("Unable to recover from Core Data store failure")
                    }
                } else {
                    fatalError("Failed to get URL from Core Data persistent store description")
                }
            } else {
                os_log("Successfully loaded Core Data Communication Hub persistent stores", log: .communicationHub, type: .info)
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
                self.loaded = true
            }
            
            if let error = error {
                fatalError("Failed to create in-memory persistent store: \(error)")
            }
        }
    }

    /// Drop the database and reset the persistent container. Note that will leave the store in a dropped state, and the app (and Rover SDK) should be restarted afterward.
    func reset() {
        guard let store = persistentStoreCoordinator.persistentStores.first,
              let url = store.url else {
            os_log("No persistent store found to reset", log: .communicationHub, type: .debug)
            return
        }
        
        do {
            try persistentStoreCoordinator.remove(store)
            try persistentStoreCoordinator.destroyPersistentStore(at: url, ofType: store.type, options: nil)
            os_log("Successfully reset persistent store at: %{public}@", log: .communicationHub, type: .info, url.path)
        } catch {
            os_log("Failed to reset persistent store: %{public}@", log: .communicationHub, type: .error, error.localizedDescription)
        }
    }

    enum Storage: String {
        /// Using Sqlite, normal operation.
        case persistent

        /// Using in-memory, meant for SwiftUI previews and other testing scenarios.
        case inMemory
    }
}

// MARK: - Badge Count Extension
extension RCHPersistentContainer {
    /// Computes the current badge count based on unread posts.
    ///
    /// Note: must be used on the main thread.
    func getBadgeCount() -> Int {
        let fetchRequest: NSFetchRequest<Post> = Post.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isRead == %@", NSNumber(value: false))

        do {
            return try self.viewContext.count(for: fetchRequest)
        } catch {
            os_log("Failed to count unread posts: %@", log: .communicationHub, type: .error, error.localizedDescription)
            return 0
        }
    }
}
