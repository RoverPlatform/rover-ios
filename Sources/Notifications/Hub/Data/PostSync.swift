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
import RoverData
import UIKit
import os.log

/// Responsible for syncing posts & chat items from the Rover cloud.
actor PostSync: ObservableObject, SyncStandaloneParticipant, HubSyncCancellable {
    private let persistentContainer: InboxPersistentContainer
    private let hubSyncCoordinator: HubSyncCoordinator

    // Track the current sync task, so we can coalesce multiple sync requests.
    private var activeSyncTask: Task<Bool, Never>?

    init(persistentContainer: InboxPersistentContainer, hubSyncCoordinator: HubSyncCoordinator) {
        self.persistentContainer = persistentContainer
        self.hubSyncCoordinator = hubSyncCoordinator
    }

    // MARK: - HubSyncCancellable

    func cancelAllTasks() async {
        let task = activeSyncTask
        activeSyncTask = nil
        task?.cancel()
        _ = await task?.value
    }

    func sync() async -> Bool {
        if let existingTask = activeSyncTask {
            os_log(
                .debug,
                log: .hub,
                "Sync requested but already running, will wait for that sync to complete"
            )
            return await existingTask.value
        }

        let syncTask = Task { await performActualSync() }
        activeSyncTask = syncTask
        defer { activeSyncTask = nil }
        return await syncTask.value
    }

    private func performActualSync() async -> Bool {
        guard await persistentContainer.waitUntilLoaded() else {
            os_log("Hub persistent container not available, aborting sync")
            return false
        }

        os_log(.debug, log: .hub, "Sync started")

        // Get the cursor from Core Data
        let currentCursor = await MainActor.run { persistentContainer.getPostsCursor() }

        let response = await hubSyncCoordinator.getPosts(from: currentCursor)

        switch response.result {
        case .success(let syncResponse):
            if currentCursor == nil {
                os_log(
                    .debug,
                    log: .hub,
                    "Sync completed, \(syncResponse.posts.count) initial posts retrieved"
                )
            } else {
                os_log(
                    .debug,
                    log: .hub,
                    "Sync completed, \(syncResponse.posts.count) new posts retrieved"
                )
            }

            let didPersist = await self.updateCoreData(
                with: syncResponse.posts,
                subscriptions: syncResponse.included?.subscriptions ?? [],
                nextCursor: syncResponse.nextCursor,
                expectedGeneration: response.generationNumber
            )

            return didPersist && !syncResponse.posts.isEmpty
        case .failure(let error):
            if error is StaleGenerationError || error is CancellationError {
                os_log(.debug, log: .hub, "Sync skipped — store was reset or task cancelled during sync")
            } else {
                os_log(
                    "Failed to sync posts: %@",
                    log: .hub,
                    type: .error,
                    error.localizedDescription
                )
            }
            return false
        }
    }

    @MainActor
    private func updateCoreData(
        with posts: [PostItem],
        subscriptions: [SubscriptionItem],
        nextCursor: String?,
        expectedGeneration: Int
    ) -> Bool {
        do {
            try self.persistentContainer.stageSubscriptions(subscriptions)
            for postItem in posts {
                self.persistentContainer.createOrUpdatePost(from: postItem)
            }
            try self.persistentContainer.updatePostsSyncStatus(cursor: nextCursor)
            try self.persistentContainer.saveIfGenerationUnchanged(expectedGeneration)
            return true
        } catch is StaleGenerationError {
            os_log(.debug, log: .hub, "Skipping posts sync save — store was reset during sync")
            return false
        } catch is CancellationError {
            os_log(.debug, log: .hub, "Skipping posts sync save — task was cancelled")
            return false
        } catch {
            os_log(
                "Failed to save Core Data context: %@",
                log: .hub,
                type: .error,
                error.localizedDescription
            )
            self.persistentContainer.viewContext.rollback()
            return false
        }
    }
}

// MARK: - DTOs for API

struct PostsSyncResponse: Codable {
    let posts: [PostItem]
    let included: IncludedData?
    let nextCursor: String?
    let hasMore: Bool

    struct IncludedData: Codable {
        static let includeKey = "subscriptions"
        let subscriptions: [SubscriptionItem]
    }
}

extension HTTPClient {
    /// Recurse, retrieving subsequent sync pages, until we have all the posts.
    func getPosts(from cursor: String?) async -> Result<PostsSyncResponse, Error> {
        /// Recursively retrieve all pages of posts, accumulating results
        func getPostsRecursive(
            from cursor: String?,
            accumulatedPosts: [PostItem],
            accumulatedSubscriptions: [SubscriptionItem]
        ) async -> Result<PostsSyncResponse, Error> {
            let pageResponse = await getPostsPage(cursor: cursor)

            switch pageResponse {
            case .success(let response):
                let newAccumulatedPosts = accumulatedPosts + response.posts
                let newAccumulatedSubscriptions =
                    accumulatedSubscriptions + (response.included?.subscriptions ?? [])

                if response.hasMore {
                    return await getPostsRecursive(
                        from: response.nextCursor,
                        accumulatedPosts: newAccumulatedPosts,
                        accumulatedSubscriptions: newAccumulatedSubscriptions
                    )
                } else {
                    var seenIDs = Set<String>()
                    let uniqueSubscriptions = newAccumulatedSubscriptions.filter {
                        seenIDs.insert($0.id).inserted
                    }
                    return .success(
                        PostsSyncResponse(
                            posts: newAccumulatedPosts,
                            included: PostsSyncResponse.IncludedData(
                                subscriptions: uniqueSubscriptions
                            ),
                            nextCursor: response.nextCursor,
                            hasMore: false
                        )
                    )
                }

            case .failure(let error):
                return .failure(error)
            }
        }

        return await getPostsRecursive(
            from: cursor,
            accumulatedPosts: [],
            accumulatedSubscriptions: []
        )
    }

    func getPostsPage(cursor: String? = nil) async -> Result<PostsSyncResponse, Error> {
        // endpoint currently has /graphql added, remove it here to obtain the root and use v3 instead.
        let endpoint = engageEndpoint.appendingPathComponent("posts")

        var queryItems = [URLQueryItem(name: "include", value: PostsSyncResponse.IncludedData.includeKey)]
        if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }

        os_log(.debug, log: .hub, "Retrieving a page of posts with cursor: \(cursor ?? "nil")")

        return await authenticatedDownloadDecoding(
            PostsSyncResponse.self,
            url: endpoint,
            queryItems: queryItems,
            log: .hub,
            label: "posts page"
        )
    }

}
