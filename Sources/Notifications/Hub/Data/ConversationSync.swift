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
import RoverData
import os.log

actor ConversationSync: SyncStandaloneParticipant, HubSyncCancellable {
    private let persistentContainer: InboxPersistentContainer
    private let hubSyncCoordinator: HubSyncCoordinator
    private var activeSyncTask: Task<Bool, Never>?
    private var activeForwardSyncTask: Task<Void, Never>?
    private var activeBackwardsSyncTask: Task<Void, Never>?

    init(persistentContainer: InboxPersistentContainer, hubSyncCoordinator: HubSyncCoordinator) {
        self.persistentContainer = persistentContainer
        self.hubSyncCoordinator = hubSyncCoordinator
    }

    // MARK: - HubSyncCancellable

    func cancelAllTasks() async {
        let syncTask = activeSyncTask
        let forwardTask = activeForwardSyncTask
        let backwardsTask = activeBackwardsSyncTask
        syncTask?.cancel()
        forwardTask?.cancel()
        backwardsTask?.cancel()
        await withTaskGroup(of: Void.self) { group in
            if let syncTask { group.addTask { _ = await syncTask.value } }
            if let forwardTask { group.addTask { await forwardTask.value } }
            if let backwardsTask { group.addTask { await backwardsTask.value } }
        }
        activeSyncTask = nil
        activeForwardSyncTask = nil
        activeBackwardsSyncTask = nil
    }

    // MARK: - Launch Sync (SyncStandaloneParticipant)

    func sync() async -> Bool {
        if let existing = activeSyncTask { return await existing.value }
        let task = Task { await self.performLaunchSync() }
        activeSyncTask = task
        defer { activeSyncTask = nil }
        return await task.value
    }

    private func performLaunchSync() async -> Bool {
        guard await persistentContainer.waitUntilLoaded() else {
            os_log("Hub persistent container not available, aborting conversation sync")
            return false
        }
        return await drainForwardPages()
    }

    // MARK: - Forward Poll (called by MessagesView)

    func syncForward() async {
        if let existingLaunch = activeSyncTask {
            // Launch sync is already advancing the cursor — wait for it to finish and return.
            // A separate forward fetch would be redundant since the cursor is up-to-date after
            // launch sync completes.
            os_log(
                .debug,
                log: .hub,
                "syncForward() called while launch sync is in flight — awaiting launch sync, no additional forward fetch needed"
            )
            _ = await existingLaunch.value
            return
        }
        if let existing = activeForwardSyncTask {
            await existing.value
            return
        }
        let task = Task { await self.performForwardSync() }
        activeForwardSyncTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        activeForwardSyncTask = nil
    }

    private func performForwardSync() async {
        await drainForwardPages()
    }

    // Drains all outstanding forward pages until the server signals no more remain.
    // Returns true if all pages were fetched and saved successfully, false if any fetch or save failed.
    @discardableResult
    private func drainForwardPages() async -> Bool {
        var cursor = await MainActor.run { persistentContainer.getConversationsSyncStatus()?.cursor }
        while true {
            guard !Task.isCancelled else { return false }
            switch await fetchAndUpsertForward(cursor: cursor) {
            case .morePages:
                cursor = await MainActor.run { persistentContainer.getConversationsSyncStatus()?.cursor }
            case .caughtUp:
                return true
            case .failed:
                return false
            }
        }
    }

    // MARK: - Backwards Backfill (called by MessagesView)

    func syncBackward() async {
        if let existingLaunch = activeSyncTask {
            // Launch sync only performs forward sync — backward sync still needs to run after
            // it completes. Unlike syncForward(), we do NOT return early here.
            _ = await existingLaunch.value
        }
        if let existing = activeBackwardsSyncTask {
            await existing.value
            return
        }
        let task = Task { await self.performSyncBackward() }
        activeBackwardsSyncTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        activeBackwardsSyncTask = nil
    }

    private func performSyncBackward() async {
        // The loop exits when the server returns hasMore: false, the task is cancelled,
        // or there is no backwardsCursor / historyComplete is already true. The server
        // is expected to always eventually return hasMore: false; there is no client-side
        // page cap because we control both sides of this API.
        while true {
            guard !Task.isCancelled else { return }

            let syncStatus = await MainActor.run {
                () -> (backwardsCursor: String?, historyComplete: Bool) in
                let syncStatus = persistentContainer.getConversationsSyncStatus()
                return (
                    backwardsCursor: syncStatus?.backwardsCursor,
                    historyComplete: syncStatus?.historyComplete ?? false
                )
            }

            guard let backwardsCursor = syncStatus.backwardsCursor,
                syncStatus.historyComplete == false
            else { return }

            switch await fetchAndUpsertBackward(backwardsCursor: backwardsCursor) {
            case .morePages:
                break
            case .caughtUp, .failed:
                return
            }
        }
    }

    private func fetchAndUpsertBackward(backwardsCursor: String) async -> PageFetchResult {
        let response = await hubSyncCoordinator.getConversationsPage(cursor: .backward(backwardsCursor))
        switch response.result {
        case .success(let fetchResult):
            switch fetchResult {
            case .page(let page):
                let saveSucceeded = await MainActor.run { () -> Bool in
                    do {
                        // Re-read the forward cursor at save time to preserve any forward-sync
                        // progress that may have occurred while this HTTP request was in-flight.
                        // Without this, a concurrent forward sync could have its cursor overwritten.
                        let latestForwardCursor = persistentContainer.getConversationsSyncStatus()?.cursor
                        try persistentContainer.stageConversations(
                            page.conversations,
                            allParticipants: page.included?.participants ?? []
                        )
                        try persistentContainer.stageConversationsSyncStatus(
                            cursor: latestForwardCursor,
                            backwardsCursor: page.nextBefore,
                            historyComplete: !page.hasMore
                        )
                        try persistentContainer.saveIfGenerationUnchanged(response.generationNumber)
                        return true
                    } catch is StaleGenerationError {
                        os_log(.debug, log: .hub, "Skipping backward conversation page — store was reset during sync")
                        return false
                    } catch is CancellationError {
                        os_log(.debug, log: .hub, "Skipping backward conversation page — task was cancelled")
                        return false
                    } catch {
                        os_log(
                            "Failed to save backwards conversation sync page: %{private}@",
                            log: .hub,
                            type: .error,
                            error.localizedDescription
                        )
                        persistentContainer.viewContext.rollback()
                        return false
                    }
                }
                guard saveSucceeded else { return .failed }
                return page.hasMore ? .morePages : .caughtUp
            case .notModified:
                return .caughtUp
            }
        case .failure(let error):
            if error is StaleGenerationError || error is CancellationError {
                os_log(.debug, log: .hub, "Backwards backfill skipped — store was reset or task cancelled")
            } else {
                os_log("Backwards backfill failed: %{private}@", log: .hub, type: .error, error.localizedDescription)
            }
            return .failed
        }
    }

    // MARK: - Private

    private enum PageFetchResult {
        case morePages
        case caughtUp
        case failed
    }

    // Fetches one page of conversations in the forward direction and persists the result.
    private func fetchAndUpsertForward(cursor: String?) async -> PageFetchResult {
        let ifModifiedSince = await MainActor.run {
            cursor == nil ? persistentContainer.latestConversationActivityDate() : nil
        }
        let response = await hubSyncCoordinator.getConversationsPage(
            cursor: .forward(cursor),
            ifModifiedSince: ifModifiedSince
        )
        switch response.result {
        case .success(let fetchResult):
            switch fetchResult {
            case .page(let page):
                let saveSucceeded = await MainActor.run { () -> Bool in
                    let existingSyncStatus = persistentContainer.getConversationsSyncStatus()
                    let existingBackwardsCursor = existingSyncStatus?.backwardsCursor
                    // Forward sync intentionally preserves the existing historyComplete value.
                    // Only backward sync sets historyComplete = true (when page.hasMore == false),
                    // since only backward sync traverses historical records. On a fresh install
                    // where the first forward page has hasMore == false and no backward cursor,
                    // historyComplete remains false — backward sync is a no-op in that case
                    // since backwardsCursor will be nil.
                    let existingHistoryComplete = existingSyncStatus?.historyComplete ?? false
                    do {
                        try persistentContainer.stageConversations(
                            page.conversations,
                            allParticipants: page.included?.participants ?? []
                        )
                        try persistentContainer.stageConversationsSyncStatus(
                            cursor: page.nextCursor,
                            backwardsCursor: page.nextBefore ?? existingBackwardsCursor,
                            historyComplete: existingHistoryComplete
                        )
                        try persistentContainer.saveIfGenerationUnchanged(response.generationNumber)
                        return true
                    } catch is StaleGenerationError {
                        os_log(.debug, log: .hub, "Skipping forward conversation page — store was reset during sync")
                        return false
                    } catch is CancellationError {
                        os_log(.debug, log: .hub, "Skipping forward conversation page — task was cancelled")
                        return false
                    } catch {
                        os_log(
                            "Failed to save forward conversation sync page: %{private}@",
                            log: .hub,
                            type: .error,
                            error.localizedDescription
                        )
                        persistentContainer.viewContext.rollback()
                        return false
                    }
                }
                guard saveSucceeded else { return .failed }
                return page.hasMore ? .morePages : .caughtUp
            case .notModified:
                return .caughtUp
            }
        case .failure(let error):
            if error is StaleGenerationError || error is CancellationError {
                os_log(.debug, log: .hub, "Conversation forward sync skipped — store was reset or task cancelled")
            } else {
                os_log(
                    "Conversation forward sync failed: %{private}@",
                    log: .hub,
                    type: .error,
                    error.localizedDescription
                )
            }
            return .failed
        }
    }
}
