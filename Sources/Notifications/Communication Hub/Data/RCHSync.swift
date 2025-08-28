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
actor RCHSync: ObservableObject, SyncStandaloneParticipant {
    private let persistentContainer: RCHPersistentContainer
    private let httpClient: HTTPClient

    // Track the current sync task, so we can coalesce multiple sync requests.
    private var activeSyncTask: Task<Bool, Never>?

    init(persistentContainer: RCHPersistentContainer, httpClient: HTTPClient) {
        self.persistentContainer = persistentContainer
        self.httpClient = httpClient
    }

    func sync() async -> Bool {
        // If there's already a sync in progress, wait for it to complete
        if let existingTask = activeSyncTask {
            os_log(
                .debug, log: .communicationHub,
                "Sync requested but already running, will wait for that sync to complete")
            return await existingTask.value
        }

        // Create and store sync task atomically to prevent race conditions.
        // Subsequent sync requests will wait for this task rather than starting new ones.
        let syncTask = Task { await performActualSync() }
        activeSyncTask = syncTask
        
        return await syncTask.value
    }
    
    private func performActualSync() async -> Bool {
        defer {
            // Always clear activeSyncTask when the task completes, regardless of how it finished
            // (success, failure, or cancellation). This ensures that future sync requests can
            // start fresh and aren't blocked by a stale task reference. If we only cleared on
            // success (!isCancelled), cancelled tasks would remain in activeSyncTask and prevent
            // subsequent sync operations from proceeding.
            activeSyncTask = nil
        }

        // Wait for persistence to finish loading before proceeding with sync
        let state = await MainActor.run { persistentContainer.state }
        if state != .loaded {
            os_log(
                .debug, log: .communicationHub,
                "Sync waiting for persistence (Core Data) to finish initialization")

            // Wait for the loaded state before proceeding
            waitLoop: for await state in await MainActor.run(body: { persistentContainer.$state.values }) {
                switch state {
                case .loading:
                    // continue to wait.
                    continue waitLoop
                case .failed:
                    os_log("Communication Hub persistent container not available, aborting sync")
                    return false
                case .loaded:
                    os_log(.debug, log: .communicationHub, "Persistence loading completed, now can sync")
                    break waitLoop
                }
            }
        }

        os_log(.debug, log: .communicationHub, "Sync started")

        // First sync subscriptions
        let subscriptionsResponse = await httpClient.getSubscriptions()

        switch subscriptionsResponse {
        case .success(let response):
            await MainActor.run {
                persistentContainer.upsertSubscriptions(response.subscriptions)
                os_log(
                    .debug, log: .communicationHub, "Synced %d subscriptions", response.subscriptions.count)
            }
        case .failure(let error):
            os_log(
                "Failed to sync subscriptions: %@", log: .communicationHub, type: .error,
                error.localizedDescription)
            // Continue with posts sync even if subscriptions fail
        }

        // Get the cursor from Core Data
        let currentCursor = await MainActor.run { persistentContainer.getPostsCursor() }

        let postsResponse = await httpClient.getPosts(from: currentCursor)

        switch postsResponse {
        case .success(let response):
            if currentCursor == nil {
                os_log(
                    .debug, log: .communicationHub,
                    "Sync completed, \(response.posts.count) initial posts retrieved")
            } else {
                os_log(
                    .debug, log: .communicationHub,
                    "Sync completed, \(response.posts.count) new posts retrieved")
            }

            if !response.posts.isEmpty {
                // Update Core Data with the new posts
                await self.updateCoreData(with: response.posts, nextCursor: response.nextCursor)
            }

            return !response.posts.isEmpty
        case .failure(let error):
            os_log(
                "Failed to sync posts: %@", log: .communicationHub, type: .error,
                error.localizedDescription)
            return false
        }
    }

    @MainActor
    private func updateCoreData(with posts: [PostItem], nextCursor: String?) {
        // Create or update posts in Core Data
        for postItem in posts {
            self.persistentContainer.createOrUpdatePost(from: postItem)
        }

        // Save the new cursor
        self.persistentContainer.updatePostsCursor(nextCursor)

        // Save changes
        do {
            try self.persistentContainer.viewContext.save()
        } catch {
            os_log(
                "Failed to save Core Data context: %@", log: .communicationHub, type: .error,
                error.localizedDescription)
        }
    }
}

// MARK: - DTOs for API Communication

struct PostsSyncResponse: Codable {
    let posts: [PostItem]
    let nextCursor: String?
    let hasMore: Bool
}

struct SubscriptionsSyncResponse: Codable {
    let subscriptions: [SubscriptionItem]
}


extension HTTPClient {
    func getSubscriptions() async -> Result<SubscriptionsSyncResponse, Error> {
        let endpoint = self.engageEndpoint.appendingPathComponent("subscriptions")

        let request = downloadRequest(url: endpoint)

        os_log(.debug, log: .communicationHub, "Retrieving subscriptions")

        let result = await download(with: request)

        let jsonData: Data
        switch result {
        case .success(let data, _):
            os_log(.debug, log: .communicationHub, "Successfully retrieved subscriptions")
            jsonData = data
        case .error(let error, _):
            os_log(
                .error, log: .communicationHub, "Failed to fetch subscriptions from %@: %@",
                endpoint.absoluteString, error?.debugDescription ?? "unknown reason")
            return .failure(SyncError(message: error?.localizedDescription ?? "unknown reason"))
        }

        do {
            let decoder = JSONDecoder.default
            let response = try decoder.decode(SubscriptionsSyncResponse.self, from: jsonData)
            return .success(response)
        } catch {
            let responseBodyString = String(data: jsonData, encoding: .utf8) ?? "none"
            os_log(
                .error, log: .communicationHub,
                "Failed to decode subscriptions response: %@, response body: %@", error.debugDescription,
                responseBodyString)
            return .failure(SyncError(message: error.localizedDescription))
        }
    }

    /// Recurse, retrieving subsequent sync pages, until we have all the posts.
    func getPosts(from cursor: String?) async -> Result<PostsSyncResponse, Error> {
        /// Recursively retrieve all pages of posts, accumulating results
        func getPostsRecursive(from cursor: String?, accumulatedPosts: [PostItem]) async -> Result<PostsSyncResponse, Error> {
            let pageResponse = await getPostsPage(cursor: cursor)
            
            switch pageResponse {
            case .success(let response):
                let newAccumulatedPosts = accumulatedPosts + response.posts
                
                if response.hasMore {
                    // Continue recursively accumulating posts from subsequent pages
                    return await getPostsRecursive(from: response.nextCursor, accumulatedPosts: newAccumulatedPosts)
                } else {
                    // Return all accumulated posts from all pages
                    return .success(PostsSyncResponse(
                        posts: newAccumulatedPosts,
                        nextCursor: response.nextCursor,
                        hasMore: false
                    ))
                }
                
            case .failure(let error):
                return .failure(error)
            }
        }
        
        // Start the recursive accumulation with empty array
        return await getPostsRecursive(from: cursor, accumulatedPosts: [])
    }

    fileprivate func getPostsPage(cursor: String? = nil) async -> Result<PostsSyncResponse, Error> {
        // endpoint currently has /graphql added, remove it here to obtain the root and use v3 instead.
        let endpoint = self.engageEndpoint.appendingPathComponent("posts")

        var urlComponents = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!

        let deviceIdentifier = await getDeviceIdentifier()
        urlComponents.queryItems = [URLQueryItem(name: "deviceIdentifier", value: deviceIdentifier)]

        if let cursor = cursor {
            urlComponents.queryItems?.append(URLQueryItem(name: "cursor", value: cursor))
        }

        let url = urlComponents.url!
        let request = downloadRequest(url: url)

        os_log(
            .debug, log: .communicationHub, "Retrieving a page of posts with cursor: \(cursor ?? "nil")")

        let result = await download(with: request)

        let jsonData: Data
        switch result {
        case .success(let data, _):
            os_log(.debug, log: .communicationHub, "Successfully retrieved a page of posts")
            jsonData = data
        case .error(let error, _):
            os_log(
                .error, log: .communicationHub, "Failed to fetch posts page from %@: %@",
                url.absoluteString, error?.debugDescription ?? "unknown reason")
            return .failure(SyncError(message: error?.localizedDescription ?? "unknown reason"))
        }

        do {
            let decoder = JSONDecoder.default
            let response = try decoder.decode(PostsSyncResponse.self, from: jsonData)

            return .success(response)
        } catch {
            let responseBodyString = String(data: jsonData, encoding: .utf8) ?? "none"
            os_log(
                .error, log: .communicationHub, "Failed to decode posts response: %@, response body: %@",
                error.debugDescription, responseBodyString)
            return .failure(SyncError(message: error.localizedDescription))
        }
    }

    @MainActor
    private func getDeviceIdentifier() -> String {
        return UIDevice.current.identifierForVendor?.uuidString ?? ""
    }
}

private struct SyncError: Error {
    let message: String
}
