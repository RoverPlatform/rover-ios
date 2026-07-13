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

import Combine
import CoreData
import Foundation
import os.log

final class InboxPersistentContainer: NSPersistentContainer, @unchecked Sendable {

    /// Observe this state to discover when initial restore has completed.
    @Published var state: State = .loading

    /// Epoch token that increments each time `bumpConversationStoreGeneration()` is called.
    /// Sync operations capture this value before a network await and verify it
    /// hasn't changed before writing to the store — preventing stale responses
    /// from repopulating data after a drop. Access on the main actor only.
    @MainActor var conversationStoreGeneration: Int = 0

    init(storage: Storage) {
        os_log(
            "Initializing Core Data PersistentContainer in storage mode: %{private}@",
            log: .hub,
            type: .debug,
            storage.rawValue
        )
        // Load the versioned model from the .momd bundle
        guard let momdURL = Bundle.module.url(forResource: "RoverCommHubModel", withExtension: "momd") else {
            fatalError("Failed to find RoverCommHubModel.momd in bundle.")
        }
        guard let loadedModel = NSManagedObjectModel(contentsOf: momdURL) else {
            fatalError("Failed to load Core Data model from \(momdURL.path)")
        }
        os_log(
            "Loading Core Data model from versioned bundle at: %{private}@",
            log: .hub,
            type: .debug,
            momdURL.path
        )

        super.init(name: "RoverCommHubModel", managedObjectModel: loadedModel)

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

    #if DEBUG
        static func compiledModelURL(named modelName: String) -> URL? {
            guard let momdURL = versionedModelBundleURL() else {
                return nil
            }
            let modelURL = momdURL.appendingPathComponent("\(modelName).mom", isDirectory: false)
            guard FileManager.default.fileExists(atPath: modelURL.path) else {
                return nil
            }
            return modelURL
        }

        static func versionedModelBundleURL() -> URL? {
            Bundle.module.url(forResource: "RoverCommHubModel", withExtension: "momd")
        }
    #endif

    private func configureWithSqlite() {
        if let description = persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        loadPersistentStoresWithRetry(isRetry: false)
    }

    private func loadPersistentStoresWithRetry(isRetry: Bool) {
        loadPersistentStores { description, error in
            if let error = error {
                os_log(
                    "Error loading Core Data persistent store%{private}@: %{private}@",
                    log: .hub,
                    type: .error,
                    isRetry ? " (retry)" : "",
                    error.localizedDescription
                )

                // If this was already a retry attempt, fall back to in-memory storage
                guard !isRetry else {
                    os_log("Retry attempt failed, falling back to in-memory storage", log: .hub, type: .error)
                    self.fallbackToInMemoryStorage()
                    return
                }

                // Get the URL from the description in order to attempt dropping and recreating the DB.
                guard let storeURL = description.url else {
                    os_log(
                        "loadPersistentStores() error state occurred, but unable to obtain store URLs to attempt dropping DB, falling back to in-memory storage",
                        log: .hub,
                        type: .error
                    )
                    self.fallbackToInMemoryStorage()
                    return
                }

                do {
                    let coordinator = self.persistentStoreCoordinator

                    // Destroy the persistent store
                    try coordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
                    os_log(
                        "Successfully destroyed Core Data persistent store at: %{private}@",
                        log: .hub,
                        type: .info,
                        storeURL.path
                    )

                    // Attempt to load the persistent stores one more time
                    os_log("Attempting to retry loading persistent stores after recreation", log: .hub, type: .info)
                    self.loadPersistentStoresWithRetry(isRetry: true)

                } catch {
                    os_log(
                        "Failed to reset Core Data persistent store: %{private}@",
                        log: .hub,
                        type: .error,
                        error.localizedDescription
                    )
                    os_log("Falling back to in-memory storage after failed store recreation", log: .hub, type: .error)
                    self.fallbackToInMemoryStorage()

                }

            } else {
                os_log(
                    "Successfully loaded Core Data Hub persistent stores%{private}@",
                    log: .hub,
                    type: .info,
                    isRetry ? " (after retry)" : ""
                )
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
                os_log(
                    "Failed to remove existing persistent store during fallback: %{private}@",
                    log: .hub,
                    type: .error,
                    error.localizedDescription
                )
            }
        }

        // Configure for in-memory storage
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        self.persistentStoreDescriptions = [description]

        // Load the in-memory store
        self.loadPersistentStores { description, error in
            if let error = error {
                os_log(
                    "Critical error: Failed to create in-memory fallback store: %{private}@",
                    log: .hub,
                    type: .fault,
                    error.localizedDescription
                )
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
            let url = store.url
        else {
            os_log("No persistent store found to reset", log: .hub, type: .debug)
            return
        }

        do {
            try persistentStoreCoordinator.remove(store)
            try persistentStoreCoordinator.destroyPersistentStore(at: url, ofType: store.type, options: nil)
            os_log("Successfully reset persistent store at: %{private}@", log: .hub, type: .info, url.path)
        } catch {
            os_log("Failed to reset persistent store: %{private}@", log: .hub, type: .error, error.localizedDescription)
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

// MARK: - SyncEntity
extension InboxPersistentContainer {
    enum SyncEntity: String {
        case posts = "posts"
        case conversations = "conversations"
    }
}

// MARK: - SyncStatus Helper
extension InboxPersistentContainer {
    /// Returns a fetch request pre-configured to retrieve the SyncStatus record for the given entity.
    func syncStatusRequest(for entity: SyncEntity) -> NSFetchRequest<SyncStatus> {
        let request = SyncStatus.fetchRequest()
        request.predicate = NSPredicate(format: "roverEntity == %@", entity.rawValue)
        request.fetchLimit = 1
        return request
    }
}

// MARK: - Initialization Wait

extension InboxPersistentContainer {
    /// Waits until the container reaches `.loaded`, returning `false` on failure or cancellation.
    ///
    /// Bridges `$state` into an `AsyncStream` so the wait exits immediately when the calling
    /// Task is cancelled. `@Published.values` returns an `AsyncPublisher` that does not cooperate
    /// with Swift Task cancellation — it blocks until the next state emission — so values are
    /// forwarded through an `AsyncStream` whose continuation can be finished from the cancellation
    /// handler.
    func waitUntilLoaded() async -> Bool {
        let (stream, continuation) = AsyncStream.makeStream(of: State.self)

        let cancellable = await MainActor.run {
            self.$state.sink { continuation.yield($0) }
        }
        continuation.onTermination = { _ in cancellable.cancel() }

        return await withTaskCancellationHandler {
            for await state in stream {
                switch state {
                case .loading:
                    continue
                case .failed:
                    return false
                case .loaded:
                    return true
                }
            }
            return false
        } onCancel: {
            continuation.finish()
        }
    }
}

// MARK: - Conversation Domain

struct StaleGenerationError: Error {}

extension InboxPersistentContainer {
    /// Bumps `conversationStoreGeneration`, invalidating any pending generation-guarded save.
    ///
    /// Called first by `HubSyncCoordinator`'s reset task — before cancellation or any domain is
    /// dropped — so correctness comes from the epoch check rather than from perfect cancellation
    /// timing ("epoch-first invalidation"). This is the single source of truth for the bump;
    /// the domain drops (`dropAllConversations()` and friends) do not bump it themselves.
    @MainActor
    func bumpConversationStoreGeneration() {
        conversationStoreGeneration += 1
    }

    @MainActor
    func fetchAllConversationIDs() -> [UUID] {
        do {
            return try viewContext.fetch(Conversation.fetchRequest()).compactMap { $0.id }
        } catch {
            os_log(
                .error,
                log: .hub,
                "Failed to fetch conversation IDs: %{private}@",
                error.localizedDescription
            )
            return []
        }
    }

    /// Saves only if the store generation still matches `expectedGeneration` and the calling
    /// task has not been cancelled. Rolls back on either violation.
    ///
    /// Callers receive `expectedGeneration` from `HubSyncResponse.generationNumber` — the value
    /// was captured by `HubSyncCoordinator` before the network call, so any drop that occurred
    /// while the call was in-flight (incrementing `conversationStoreGeneration`) causes this
    /// method to roll back and throw.
    ///
    /// Both `StaleGenerationError` and `CancellationError` are **expected control-flow** during
    /// a 410 reset. Log them at `.debug`, never `.error`.
    @MainActor
    func saveIfGenerationUnchanged(_ expectedGeneration: Int) throws {
        do {
            guard conversationStoreGeneration == expectedGeneration else {
                throw StaleGenerationError()
            }
            guard !Task.isCancelled else {
                throw CancellationError()
            }
            try viewContext.save()
        } catch {
            viewContext.rollback()
            throw error
        }
    }
}

// MARK: - Badge Count Extension
extension InboxPersistentContainer {
    private static let unreadPostPredicate = NSPredicate(format: "isRead == %@", NSNumber(value: false))
    private static let unreadConversationPredicate = Conversation.unreadPredicate
    /// Computes the current badge count based on unread posts and conversations.
    ///
    /// Note: must be used on the main thread.
    func getBadgeCount() -> Int {
        let unreadPosts = countUnreadItems(Post.self, predicate: Self.unreadPostPredicate)
        let unreadConversations = countUnreadItems(Conversation.self, predicate: Self.unreadConversationPredicate)
        return unreadPosts + unreadConversations
    }

    private func countUnreadItems<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate) -> Int {
        let entityName = T.entity().name ?? String(describing: T.self)
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = predicate
        do {
            return try viewContext.count(for: request)
        } catch {
            os_log(
                "Failed to count unread %{private}@: %{private}@",
                log: .hub,
                type: .error,
                entityName,
                error.localizedDescription
            )
            return 0
        }
    }
}
