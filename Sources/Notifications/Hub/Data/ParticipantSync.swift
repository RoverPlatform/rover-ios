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

actor ParticipantSync: SyncStandaloneParticipant, HubSyncCancellable {
    private let persistentContainer: InboxPersistentContainer
    private let hubSyncCoordinator: HubSyncCoordinator
    private var activeSyncTask: Task<Bool, Never>?

    init(persistentContainer: InboxPersistentContainer, hubSyncCoordinator: HubSyncCoordinator) {
        self.persistentContainer = persistentContainer
        self.hubSyncCoordinator = hubSyncCoordinator
    }

    func sync() async -> Bool {
        if let existingTask = activeSyncTask {
            os_log(
                .debug,
                log: .hub,
                "ParticipantSync requested but already running, will wait for that sync to complete"
            )
            return await existingTask.value
        }

        let syncTask = Task { await performActualSync() }
        activeSyncTask = syncTask
        defer { activeSyncTask = nil }
        return await syncTask.value
    }

    func cancelAllTasks() async {
        let syncTask = activeSyncTask
        syncTask?.cancel()
        if let syncTask { _ = await syncTask.value }
        activeSyncTask = nil
    }

    private func performActualSync() async -> Bool {
        guard await persistentContainer.waitUntilLoaded() else {
            os_log(.error, log: .hub, "Hub persistent container not available, aborting participant sync")
            return false
        }

        let response = await hubSyncCoordinator.getParticipants()

        switch response.result {
        case .success(let syncResponse):
            os_log(
                .debug,
                log: .hub,
                "ParticipantSync completed, %d participants retrieved",
                syncResponse.participants.count
            )
            do {
                try await MainActor.run {
                    try persistentContainer.stageParticipants(syncResponse.participants)
                    try persistentContainer.saveIfGenerationUnchanged(response.generationNumber)
                }
                return true
            } catch is StaleGenerationError {
                os_log(.debug, log: .hub, "ParticipantSync save skipped — store was reset during sync")
                return false
            } catch is CancellationError {
                os_log(.debug, log: .hub, "ParticipantSync save skipped — task was cancelled")
                return false
            } catch {
                await MainActor.run { persistentContainer.viewContext.rollback() }
                os_log(
                    .error,
                    log: .hub,
                    "ParticipantSync failed to save participants: %@",
                    error.localizedDescription
                )
                return false
            }
        case .failure(let error):
            if error is StaleGenerationError || error is CancellationError {
                os_log(.debug, log: .hub, "ParticipantSync skipped — store was reset or task cancelled during sync")
            } else {
                os_log(.error, log: .hub, "ParticipantSync failed to sync participants: %@", error.localizedDescription)
            }
            return false
        }
    }
}
