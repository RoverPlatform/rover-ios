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
import RoverData
import os.log

actor SubscriptionSync: SyncStandaloneParticipant, HubSyncCancellable {
    private let persistentContainer: InboxPersistentContainer
    private let hubSyncCoordinator: HubSyncCoordinator
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
                "SubscriptionSync requested but already running, will wait for that sync to complete"
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
            os_log(.error, log: .hub, "Hub persistent container not available, aborting subscription sync")
            return false
        }

        let response = await hubSyncCoordinator.getSubscriptions()

        switch response.result {
        case .success(let syncResponse):
            os_log(
                .debug,
                log: .hub,
                "SubscriptionSync completed, %d subscriptions retrieved",
                syncResponse.subscriptions.count
            )

            return await self.updateCoreData(
                with: syncResponse.subscriptions,
                expectedGeneration: response.generationNumber
            )
        case .failure(let error):
            if error is StaleGenerationError || error is CancellationError {
                os_log(.debug, log: .hub, "SubscriptionSync skipped — store was reset or task cancelled during sync")
            } else {
                os_log(
                    .error,
                    log: .hub,
                    "SubscriptionSync failed to sync subscriptions: %@",
                    error.localizedDescription
                )
            }
            return false
        }
    }

    @MainActor
    private func updateCoreData(
        with subscriptions: [SubscriptionItem],
        expectedGeneration: Int
    ) -> Bool {
        do {
            try self.persistentContainer.stageSubscriptions(subscriptions)
            try self.persistentContainer.saveIfGenerationUnchanged(expectedGeneration)
            return true
        } catch is StaleGenerationError {
            os_log(.debug, log: .hub, "Skipping subscription sync save — store was reset during sync")
            return false
        } catch is CancellationError {
            os_log(.debug, log: .hub, "Skipping subscription sync save — task was cancelled")
            return false
        } catch {
            os_log(
                "SubscriptionSync failed to save subscriptions: %@",
                log: .hub,
                type: .error,
                error.localizedDescription
            )
            self.persistentContainer.viewContext.rollback()
            return false
        }
    }
}

struct SubscriptionsSyncResponse: Codable {
    let subscriptions: [SubscriptionItem]
}

extension HTTPClient {
    func getSubscriptions() async -> Result<SubscriptionsSyncResponse, Error> {
        let endpoint = engageEndpoint.appendingPathComponent("subscriptions")
        return await authenticatedDownloadDecoding(
            SubscriptionsSyncResponse.self,
            url: endpoint,
            log: .hub,
            label: "subscriptions"
        )
    }
}
