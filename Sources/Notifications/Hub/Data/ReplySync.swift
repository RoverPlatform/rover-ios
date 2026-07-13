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

// Per-conversation coalescing task handles are tracked for forward and backwards syncs.
// ConversationDetailView manages task lifecycles directly via @State task handles that
// are cancelled on disappear. The forward poll interval (5 s) makes overlapping forward
// fetches unlikely, and syncBackwards is user-gesture-driven rather than automated.
actor ReplySync: SyncStandaloneParticipant, ReplySending, HubSyncCancellable {
    private struct QueuedReplySnapshot {
        let conversationID: UUID
        let externalID: String
        let content: [ContentBlock]
        let retryCount: Int16
        let createdAt: Date

        init?(reply: Reply) {
            let content = reply.persistedContentBlocks
            guard
                let conversationID = reply.conversation?.id,
                let externalID = reply.externalID,
                let createdAt = reply.createdAt,
                !content.isEmpty
            else {
                return nil
            }

            self.conversationID = conversationID
            self.externalID = externalID
            self.content = content
            self.retryCount = reply.retryCount
            self.createdAt = createdAt
        }
    }

    private static let replyRetryWindow: TimeInterval = 120

    private let persistentContainer: InboxPersistentContainer
    private let hubSyncCoordinator: HubSyncCoordinator
    private var activeFlushTask: Task<Bool, Never>?
    private var activeForwardTasks: [UUID: Task<Void, Never>] = [:]
    private var activeBackwardsTasks: [UUID: Task<Void, Never>] = [:]
    private var activeSendTasks: [UUID: Task<Bool, Never>] = [:]
    /// Conversations where `sendReply` inserted a reply while a flush task was already
    /// running. The running task re-runs `flushQueuedReplies` after its current pass.
    private var pendingFlushConversationIDs: Set<UUID> = []
    private var inFlightExternalIDs: Set<String> = []
    /// Single in-memory timer that re-triggers the flush at the soonest `nextRetryAt`
    /// across per-conversation heads. Re-armed after each complete flush sequence.
    private var retryTimerTask: Task<Void, Never>?
    /// Set to true for the duration of `cancelAllTasks()` to suppress re-arming the
    /// retry timer from flush tasks that finish while cancellation is in progress.
    private var isCancellingTasks: Bool = false

    init(persistentContainer: InboxPersistentContainer, hubSyncCoordinator: HubSyncCoordinator) {
        self.persistentContainer = persistentContainer
        self.hubSyncCoordinator = hubSyncCoordinator
    }

    func sync() async -> Bool {
        if let existing = activeFlushTask {
            return await existing.value
        }

        let task = Task { await flushQueuedReplies(conversationID: nil) }
        defer { activeFlushTask = nil }
        activeFlushTask = task
        let result = await task.value
        // Guard against re-arming during cancelAllTasks(). Note: Task.isCancelled is NOT
        // sufficient here — cancelAllTasks() cancels the child activeFlushTask, not the
        // outer task executing sync(), so Task.isCancelled on this frame can be false even
        // while cancellation is in progress. isCancellingTasks is the correct gate.
        if !isCancellingTasks {
            await rearmRetryTimer()
        }
        return result
    }

    func cancelAllTasks() async {
        // Raise the suppression flag before cancelling tasks. Flush tasks that finish
        // while being awaited below will check this flag and skip rearmRetryTimer().
        isCancellingTasks = true
        defer { isCancellingTasks = false }
        retryTimerTask?.cancel()
        retryTimerTask = nil
        let flushTask = activeFlushTask
        let forwardTasks = Array(activeForwardTasks.values)
        let backwardsTasks = Array(activeBackwardsTasks.values)
        let sendTasks = Array(activeSendTasks.values)
        flushTask?.cancel()
        for task in forwardTasks { task.cancel() }
        for task in backwardsTasks { task.cancel() }
        for task in sendTasks { task.cancel() }
        await withTaskGroup(of: Void.self) { group in
            if let flushTask { group.addTask { _ = await flushTask.value } }
            for task in forwardTasks { group.addTask { await task.value } }
            for task in backwardsTasks { group.addTask { await task.value } }
            for task in sendTasks { group.addTask { _ = await task.value } }
        }
        activeFlushTask = nil
        activeForwardTasks.removeAll()
        activeBackwardsTasks.removeAll()
        // Drain tasks added to activeSendTasks during the withTaskGroup suspension: a concurrent
        // sendReply can write a new entry between the initial snapshot and here. Each await is a
        // suspension point so we loop until stable.
        while !activeSendTasks.isEmpty {
            let remaining = Array(activeSendTasks.values)
            activeSendTasks.removeAll()
            for task in remaining {
                task.cancel()
                _ = await task.value
            }
        }
        pendingFlushConversationIDs.removeAll()
        inFlightExternalIDs.removeAll()
    }

    private func rearmRetryTimer() async {
        retryTimerTask?.cancel()
        retryTimerTask = nil

        let soonest = await MainActor.run { persistentContainer.fetchSoonestQueuedReplyRetryAt() }
        guard let soonest else { return }

        let delaySeconds = max(0, soonest.timeIntervalSinceNow)
        retryTimerTask = Task {
            let delayNanoseconds = UInt64(delaySeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            _ = await self.sync()
        }
    }

    func flushQueuedReplies(conversationID: UUID?) async -> Bool {
        let generation = await MainActor.run { persistentContainer.conversationStoreGeneration }

        // Deadline sweep: fail queued replies that exceeded the retry window without a send attempt.
        // Runs before any send selection so expired replies never reach the network path, and
        // process-death recovery works correctly on cold-start sync.
        let cutoff = Date().addingTimeInterval(-Self.replyRetryWindow)
        let expiredCount = await MainActor.run { () -> Int? in
            do {
                return try persistentContainer.sweepExpiredQueuedReplies(
                    before: cutoff,
                    generation: generation
                )
            } catch {
                persistentContainer.viewContext.rollback()
                return nil
            }
        }
        guard let expiredCount else {
            return false
        }
        if expiredCount > 0 {
            os_log(
                "Marked %{public}d expired queued replies as failed.",
                log: .hub,
                type: .info,
                expiredCount
            )
        }

        if let conversationID {
            return await flushConversation(conversationID: conversationID, generation: generation)
        }

        var allSucceeded = true
        let conversationIDs = await MainActor.run {
            persistentContainer.fetchConversationIDsWithQueuedReplies()
        }
        for convID in conversationIDs {
            guard !Task.isCancelled else { break }
            let currentGeneration = await MainActor.run { persistentContainer.conversationStoreGeneration }
            guard currentGeneration == generation else { break }
            let succeeded = await flushConversation(conversationID: convID, generation: generation)
            allSucceeded = allSucceeded && succeeded
        }
        return allSucceeded
    }

    private func flushConversation(conversationID: UUID, generation: Int) async -> Bool {
        var allSucceeded = true

        // Re-fetching after each batch ensures that replies inserted after this
        // flush's initial snapshot (e.g. by a concurrent sendReply) are picked
        // up in a subsequent iteration rather than being stranded.
        while true {
            guard !Task.isCancelled else { break }
            let currentGeneration = await MainActor.run { persistentContainer.conversationStoreGeneration }
            guard currentGeneration == generation else { break }

            // Capture in-flight set before crossing to MainActor so the HOL check
            // can block on in-flight replies without a cross-actor round-trip per reply.
            let currentInFlight = inFlightExternalIDs
            let now = Date()

            let (snapshots, invalidCount) = await MainActor.run { () -> ([QueuedReplySnapshot], Int) in
                let replies = persistentContainer.fetchQueuedReplies(conversationID: conversationID)
                var result: [QueuedReplySnapshot] = []
                var invalid = 0
                for reply in replies {
                    // Validate before HOL blocking: an invalid row will never be sendable so it
                    // must not be treated as a HOL blocker regardless of its nextRetryAt value.
                    guard let snapshot = QueuedReplySnapshot(reply: reply) else {
                        reply.syncState = ReplySyncState.failed.rawValue
                        reply.nextRetryAt = nil
                        reply.lastSendError = "Reply data invalid: required fields missing"
                        invalid += 1
                        continue
                    }
                    // HOL blocking: stop at the first valid reply that is in backoff or in-flight.
                    if let nextRetryAt = reply.nextRetryAt, nextRetryAt > now { break }
                    if currentInFlight.contains(snapshot.externalID) { break }
                    result.append(snapshot)
                }
                if invalid > 0 {
                    do {
                        try persistentContainer.saveIfGenerationUnchanged(generation)
                    } catch {
                        persistentContainer.viewContext.rollback()
                        return ([], invalid)
                    }
                }
                return (result, invalid)
            }

            if invalidCount > 0 {
                os_log(
                    // %{public}d is intentional: reply counts are not PII.
                    "Failed to build %{public}d queued reply snapshots; marked invalid rows failed.",
                    log: .hub,
                    type: .error,
                    invalidCount
                )
                allSucceeded = false
            }

            guard !snapshots.isEmpty else { break }

            var startedAny = false
            for snapshot in snapshots {
                guard !Task.isCancelled else { break }
                let currentGeneration = await MainActor.run { persistentContainer.conversationStoreGeneration }
                guard currentGeneration == generation else { break }
                // HOL: if a concurrent flush started sending this reply between our snapshot
                // and now, stop — do not send any later (newer) replies in this pass.
                guard beginSending(externalID: snapshot.externalID) else { break }
                startedAny = true
                defer { finishSending(externalID: snapshot.externalID) }
                let didSend = await sendQueuedReply(snapshot)
                allSucceeded = allSucceeded && didSend
                if !didSend { break }
            }

            // If nothing was started (every snapshot was in-flight at send time), exit.
            // The flush that owns those in-flight replies will loop around after each
            // send and pick up any replies that arrived after its initial snapshot.
            guard startedAny else { break }
        }

        return allSucceeded
    }
}

// MARK: - Reply Page Sync

extension ReplySync {
    func syncForward(conversationID: UUID) async {
        if let existing = activeForwardTasks[conversationID] {
            await existing.value
            return
        }
        let task = Task {
            await self.performForwardSync(conversationID: conversationID)
        }
        activeForwardTasks[conversationID] = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        activeForwardTasks[conversationID] = nil
    }

    private func performForwardSync(conversationID: UUID) async {
        let cursor = await MainActor.run(
            resultType: String?.self,
            body: { self.persistentContainer.getReplySyncStatus(for: conversationID)?.cursor }
        )
        let response = await hubSyncCoordinator.getRepliesPage(
            conversationID: conversationID,
            cursor: .forward(cursor)
        )
        await handleReplyResponse(response, conversationID: conversationID)
    }

    func syncBackwards(conversationID: UUID) async {
        if let existing = activeBackwardsTasks[conversationID] {
            await existing.value
            return
        }
        let task = Task {
            await self.performBackwardsSync(conversationID: conversationID)
        }
        activeBackwardsTasks[conversationID] = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        activeBackwardsTasks[conversationID] = nil
    }

    private func performBackwardsSync(conversationID: UUID) async {
        let syncStatus = await MainActor.run { persistentContainer.getReplySyncStatus(for: conversationID) }
        guard let backwardsCursor = syncStatus?.backwardsCursor,
            syncStatus?.historyComplete == false
        else {
            return
        }
        let response = await hubSyncCoordinator.getRepliesPage(
            conversationID: conversationID,
            cursor: .backward(backwardsCursor)
        )
        await handleReplyResponse(response, conversationID: conversationID, isBackwards: true)
    }

    func markConversationRead(
        conversationID: UUID,
        lastReadReplyID: UUID? = nil
    ) async -> Result<MarkConversationReadResponse, Error> {
        await hubSyncCoordinator.markConversationRead(
            conversationID: conversationID,
            lastReadReplyID: lastReadReplyID
        ).result
    }

    private func handleReplyResponse(
        _ response: HubSyncResponse<RepliesSyncResponse>,
        conversationID: UUID,
        isBackwards: Bool = false
    ) async {
        switch response.result {
        case .success(let page):
            await MainActor.run {
                guard let conversation = persistentContainer.fetchConversation(id: conversationID) else {
                    os_log(
                        "Reply sync page dropped: conversation %{private}@ not found locally",
                        log: .hub,
                        type: .error,
                        conversationID.uuidString
                    )
                    return
                }
                let existingSyncStatus = persistentContainer.getReplySyncStatus(for: conversationID)
                let existingForwardCursor = existingSyncStatus?.cursor
                let existingBackwardsCursor = existingSyncStatus?.backwardsCursor
                let newHistoryComplete = isBackwards ? !page.hasMore : (existingSyncStatus?.historyComplete ?? false)
                // On forward sync, preserve a more-advanced backward cursor already written by a
                // prior backward sync; only adopt the server-supplied nextBefore when no cursor
                // is stored yet. On backward sync, always advance the backward cursor with the
                // server-supplied value.
                let newBackwardsCursor =
                    isBackwards
                    ? (page.nextBefore ?? existingBackwardsCursor)
                    : (existingBackwardsCursor ?? page.nextBefore)
                do {
                    for reply in page.replies {
                        try persistentContainer.stageReply(reply, into: conversation)
                    }
                    try persistentContainer.stageReplySyncStatus(
                        for: conversationID,
                        cursor: isBackwards ? existingForwardCursor : page.nextCursor,
                        backwardsCursor: newBackwardsCursor,
                        historyComplete: newHistoryComplete
                    )
                    try persistentContainer.saveIfGenerationUnchanged(response.generationNumber)
                } catch is StaleGenerationError {
                    os_log(
                        .debug,
                        log: .hub,
                        "Skipping reply sync page for conversation %{private}@ — store was reset during sync",
                        conversationID.uuidString
                    )
                } catch is CancellationError {
                    os_log(
                        .debug,
                        log: .hub,
                        "Skipping reply sync page for conversation %{private}@ — task was cancelled",
                        conversationID.uuidString
                    )
                } catch {
                    os_log(
                        "Failed to save reply sync page for conversation %{private}@: %{private}@",
                        log: .hub,
                        type: .error,
                        conversationID.uuidString,
                        error.localizedDescription
                    )
                    persistentContainer.viewContext.rollback()
                }
            }
        case .failure(let error):
            if error is StaleGenerationError || error is CancellationError {
                os_log(
                    .debug,
                    log: .hub,
                    "Reply sync skipped for conversation %{private}@ — store was reset or task cancelled",
                    conversationID.uuidString
                )
            } else {
                os_log("Reply sync failed: %{private}@", log: .hub, type: .error, error.localizedDescription)
            }
        }
    }
}

// MARK: - Send Path

extension ReplySync {
    // Note: sendReply inserts the optimistic reply immediately, then spawns a flush task
    // for the conversation via flushQueuedReplies(conversationID:). This routes fresh sends
    // through the same ordered path used for retries.
    @discardableResult
    func sendReply(conversationID: UUID, text: String) async -> Task<Bool, Never>? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let externalID = UUID().uuidString
        let insertedReply = await MainActor.run { () -> Bool in
            guard
                persistentContainer.insertOptimisticReply(
                    conversationID: conversationID,
                    text: trimmed,
                    externalID: externalID
                ) != nil
            else {
                return false
            }

            let now = Date()
            persistentContainer.stageConversationPreviewOptimistically(
                conversationID: conversationID,
                text: trimmed,
                at: now
            )
            do {
                try persistentContainer.viewContext.save()
                return true
            } catch {
                os_log(
                    "Failed to save optimistic reply insert: %{private}@",
                    log: .hub,
                    type: .error,
                    error.localizedDescription
                )
                persistentContainer.viewContext.rollback()
                return false
            }
        }
        guard insertedReply else {
            return nil
        }

        if let existing = activeSendTasks[conversationID] {
            // Signal the running flush to re-run after its current pass so it picks
            // up the reply we just inserted.
            pendingFlushConversationIDs.insert(conversationID)
            return existing
        }
        let flushTask: Task<Bool, Never> = Task {
            defer { activeSendTasks.removeValue(forKey: conversationID) }
            var result = await flushQueuedReplies(conversationID: conversationID)
            // Re-run if a concurrent sendReply signalled while we were flushing.
            // Task.isCancelled guard ensures 410-triggered cancellation exits immediately.
            while !Task.isCancelled, pendingFlushConversationIDs.remove(conversationID) != nil {
                let rerunResult = await flushQueuedReplies(conversationID: conversationID)
                result = result && rerunResult
            }
            // Task.isCancelled is correct here (unlike in sync()): cancelAllTasks() cancels
            // this exact task, so Task.isCancelled is reliably true when cancellation is in
            // progress. isCancellingTasks is a belt-and-suspenders fallback.
            if !Task.isCancelled && !isCancellingTasks {
                await rearmRetryTimer()
            }
            return result
        }
        activeSendTasks[conversationID] = flushTask
        return flushTask
    }

    private func sendQueuedReply(_ queuedReply: QueuedReplySnapshot) async -> Bool {
        let response = await hubSyncCoordinator.sendReply(
            conversationID: queuedReply.conversationID,
            content: queuedReply.content,
            externalID: queuedReply.externalID
        )

        switch response.result {
        case .success:
            let didPersist = await MainActor.run {
                persistentContainer.markReplySent(externalID: queuedReply.externalID)
                do {
                    try persistentContainer.saveIfGenerationUnchanged(response.generationNumber)
                    return true
                } catch {
                    persistentContainer.viewContext.rollback()
                    return false
                }
            }
            guard didPersist else {
                os_log(.debug, log: .hub, "Queued reply send not persisted — store was reset during send")
                return false
            }
            return true
        case .failure(let error):
            guard !(error is StaleGenerationError || error is CancellationError) else {
                os_log(.debug, log: .hub, "Queued reply send skipped — store was reset or task cancelled")
                return false
            }
            let (failureError, isRetryable) = classifySendFailure(error)
            let now = Date()
            let deadline = queuedReply.createdAt.addingTimeInterval(Self.replyRetryWindow)
            // Also check that the *next* retry would land within the deadline. If not, mark
            // failed immediately rather than re-queuing with a nextRetryAt that is already
            // past the deadline — that would HOL-block the conversation until the backoff
            // timer fires, only to fail on the very next send attempt anyway.
            let nextRetryCount = Int16(min(Int(queuedReply.retryCount) + 1, Int(Int16.max)))
            let proposedNextRetryAt = now.addingTimeInterval(backoffDelay(for: nextRetryCount))
            let effectiveRetryable = isRetryable && now <= deadline && proposedNextRetryAt <= deadline
            let didQueuePersist = await queueFailedReply(
                externalID: queuedReply.externalID,
                currentRetryCount: queuedReply.retryCount,
                error: failureError,
                retryable: effectiveRetryable,
                generationNumber: response.generationNumber
            )
            guard didQueuePersist else {
                os_log(
                    "Failed to persist queued-reply failure state (%{private}@): %{private}@",
                    log: .hub,
                    type: .error,
                    queuedReply.externalID,
                    failureError.localizedDescription
                )
                return false
            }
            os_log(
                "Queued reply send failed (%{private}@, retryable=%{public}@): %{private}@",
                log: .hub,
                type: .error,
                queuedReply.externalID,
                effectiveRetryable.description,
                failureError.localizedDescription
            )
            return false
        }
    }

    private func classifySendFailure(_ error: Error) -> (error: Error, isRetryable: Bool) {
        guard let sendReplyError = error as? SendReplyError else {
            return (error, true)
        }

        return (sendReplyError.underlyingError, sendReplyError.isRetryable)
    }

    private func queueFailedReply(
        externalID: String,
        currentRetryCount: Int16,
        error: Error,
        retryable: Bool,
        generationNumber: Int
    ) async -> Bool {
        let nextRetryCount = Int16(min(Int(currentRetryCount) + 1, Int(Int16.max)))
        let nextRetryAt = Date().addingTimeInterval(backoffDelay(for: nextRetryCount))
        return await MainActor.run {
            if retryable {
                persistentContainer.stageReplyQueued(
                    externalID: externalID,
                    error: error.localizedDescription,
                    retryCount: nextRetryCount,
                    nextRetryAt: nextRetryAt
                )
            } else {
                persistentContainer.markReplyFailed(
                    externalID: externalID,
                    error: error.localizedDescription,
                    retryCount: nextRetryCount
                )
            }
            do {
                try persistentContainer.saveIfGenerationUnchanged(generationNumber)
                return true
            } catch {
                os_log(
                    .debug,
                    log: .hub,
                    "Skipped persisting reply failure state — store was reset or task cancelled"
                )
                persistentContainer.viewContext.rollback()
                return false
            }
        }
    }

    private func beginSending(externalID: String) -> Bool {
        inFlightExternalIDs.insert(externalID).inserted
    }

    private func finishSending(externalID: String) {
        inFlightExternalIDs.remove(externalID)
    }

    /// Returns the exponential backoff delay in seconds for a given retry count.
    ///
    /// `retryCount` is clamped to `[1, 5]` before computing `2^n`, capped at 30 s.
    nonisolated func backoffDelay(for retryCount: Int16) -> TimeInterval {
        let clampedRetryCount = max(1, min(Int(retryCount), 5))
        return min(pow(2.0, Double(clampedRetryCount)), 30.0)
    }
}

// MARK: - ReplySending forwarding wrapper

extension ReplySync {
    func markConversationRead(conversationID: UUID) async -> Result<MarkConversationReadResponse, Error> {
        await markConversationRead(conversationID: conversationID, lastReadReplyID: nil)
    }

    func markConversationReadLocally(conversationID: UUID, lastReadReplyID: UUID) async {
        await persistentContainer.markConversationAsRead(
            conversationID: conversationID,
            lastReadReplyID: lastReadReplyID
        )
    }
}
