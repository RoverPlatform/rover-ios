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
import os.log

extension InboxPersistentContainer {

    // MARK: - Reply SyncStatus

    @MainActor
    func getReplySyncStatus(for conversationID: UUID) -> SyncStatus? {
        let request = SyncStatus.fetchRequest()
        request.predicate = NSPredicate(format: "roverEntity == %@", "replies:\(conversationID.uuidString)")
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }

    @MainActor
    func stageReplySyncStatus(
        for conversationID: UUID,
        cursor: String?,
        backwardsCursor: String?,
        historyComplete: Bool
    ) throws {
        let key = "replies:\(conversationID.uuidString)"
        let request = SyncStatus.fetchRequest()
        request.predicate = NSPredicate(format: "roverEntity == %@", key)
        request.fetchLimit = 1

        let existing = try viewContext.fetch(request).first
        let syncStatus =
            existing
            ?? {
                let s = SyncStatus(context: viewContext)
                s.roverEntity = key
                return s
            }()
        syncStatus.cursor = cursor
        syncStatus.backwardsCursor = backwardsCursor
        syncStatus.historyComplete = historyComplete
    }

    // MARK: - Reply Upsert

    @MainActor
    func stageReply(_ item: ReplyItem, into conversation: Conversation) throws {
        var reply: Reply?

        if let externalID = item.externalID {
            let externalIDRequest = Reply.fetchRequest()
            externalIDRequest.predicate = NSPredicate(format: "externalID == %@", externalID)
            externalIDRequest.fetchLimit = 1
            reply = try viewContext.fetch(externalIDRequest).first
        }

        if reply == nil {
            let idRequest = Reply.fetchRequest()
            idRequest.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
            idRequest.fetchLimit = 1
            reply = try viewContext.fetch(idRequest).first
        }

        let target = reply ?? Reply(context: viewContext)
        target.id = item.id
        target.senderType = item.senderType.rawValue
        target.participantID = item.participantID
        target.createdAt = item.createdAt
        target.conversation = conversation
        replaceContentBlocks(for: target, with: item.content)
        target.externalID = nil
        target.syncState = ReplySyncState.confirmed.rawValue
        target.retryCount = 0
        target.nextRetryAt = nil
        target.lastSendError = nil
    }

    @MainActor
    func insertOptimisticReply(conversationID: UUID, text: String, externalID: String) -> Reply? {
        guard let conversation = fetchConversation(id: conversationID) else {
            return nil
        }

        let reply = Reply(context: viewContext)
        reply.id = UUID()
        reply.externalID = externalID
        reply.senderType = ReplySenderType.fan.rawValue
        reply.participantID = nil
        reply.createdAt = Date()
        reply.conversation = conversation
        reply.syncState = ReplySyncState.queued.rawValue
        reply.retryCount = 0
        reply.nextRetryAt = nil
        reply.lastSendError = nil
        replaceContentBlocks(for: reply, with: [.text(text: text)])
        return reply
    }

    @MainActor
    func stageReplyQueued(externalID: String, error: String?, retryCount: Int16, nextRetryAt: Date?) {
        guard let reply = fetchReplyByExternalID(externalID) else { return }
        reply.syncState = ReplySyncState.queued.rawValue
        reply.retryCount = retryCount
        reply.nextRetryAt = nextRetryAt
        reply.lastSendError = error
    }

    @MainActor
    func markReplySent(externalID: String) {
        guard let reply = fetchReplyByExternalID(externalID) else { return }
        reply.syncState = ReplySyncState.sent.rawValue
        reply.retryCount = 0
        reply.nextRetryAt = nil
        reply.lastSendError = nil
    }

    @MainActor
    func markReplyFailed(externalID: String, error: String?, retryCount: Int16) {
        guard let reply = fetchReplyByExternalID(externalID) else { return }
        reply.syncState = ReplySyncState.failed.rawValue
        reply.retryCount = retryCount
        reply.nextRetryAt = nil
        reply.lastSendError = error
    }

    @MainActor
    private func fetchReplyByExternalID(_ externalID: String) -> Reply? {
        let request = Reply.fetchRequest()
        request.predicate = NSPredicate(format: "externalID == %@", externalID)
        request.fetchLimit = 1
        do {
            return try viewContext.fetch(request).first
        } catch {
            os_log(
                "Failed to fetch reply by externalID %{private}@: %{private}@",
                log: .hub,
                type: .error,
                externalID,
                error.localizedDescription
            )
            return nil
        }
    }

    @MainActor
    func fetchQueuedReplies(conversationID: UUID) -> [Reply] {
        let request = Reply.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            queuedReplyPredicate(),
            NSPredicate(format: "conversation.id == %@", conversationID as CVarArg)
        ])
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        request.fetchLimit = 50
        return (try? viewContext.fetch(request)) ?? []
    }

    @MainActor
    func fetchConversationIDsWithQueuedReplies() -> [UUID] {
        let request = Reply.fetchRequest()
        request.predicate = queuedReplyPredicate()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        let replies = (try? viewContext.fetch(request)) ?? []
        // Deduplicate while preserving order: the first occurrence of each conversation ID
        // corresponds to its oldest queued reply, giving a FIFO flush order across conversations.
        var seen = Set<UUID>()
        return replies.compactMap { reply in
            guard let id = reply.conversation?.id, seen.insert(id).inserted else {
                return nil
            }
            return id
        }
    }

    /// Marks all queued replies whose `createdAt` is before `cutoff` as failed without
    /// attempting to send them. Returns the number of replies swept.
    @MainActor
    @discardableResult
    func sweepExpiredQueuedReplies(before cutoff: Date, generation: Int) throws -> Int {
        let request = Reply.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            queuedReplyPredicate(),
            NSPredicate(format: "createdAt < %@", cutoff as NSDate)
        ])
        let expired = try viewContext.fetch(request)
        for reply in expired {
            reply.syncState = ReplySyncState.failed.rawValue
            reply.nextRetryAt = nil
            reply.lastSendError = "Reply timed out: no successful send within the retry window"
        }
        if !expired.isEmpty {
            try saveIfGenerationUnchanged(generation)
        }
        return expired.count
    }

    /// Returns the soonest `nextRetryAt` across the head (oldest queued reply) of each
    /// conversation. Returns `nil` when no queued reply is in backoff.
    ///
    /// Only per-conversation heads are considered: HOL blocking means a reply's successors
    /// cannot be sent before it, so their `nextRetryAt` values are irrelevant for scheduling.
    /// Examining all queued replies would cause a busy-loop — freshly-queued heads with
    /// `nextRetryAt == nil` would pull the wake time to "now".
    @MainActor
    func fetchSoonestQueuedReplyRetryAt() -> Date? {
        let request = Reply.fetchRequest()
        request.predicate = queuedReplyPredicate()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        let replies = (try? viewContext.fetch(request)) ?? []

        var seenConversations = Set<UUID>()
        var soonest: Date? = nil
        for reply in replies {
            guard let convID = reply.conversation?.id, seenConversations.insert(convID).inserted else {
                continue
            }
            guard let nextRetryAt = reply.nextRetryAt else { continue }
            if soonest == nil || nextRetryAt < soonest! {
                soonest = nextRetryAt
            }
        }
        return soonest
    }

    private func queuedReplyPredicate() -> NSPredicate {
        NSPredicate(format: "syncState == %@", ReplySyncState.queued.rawValue)
    }

    @MainActor
    func fetchConversation(id: UUID) -> Conversation? {
        let request = Conversation.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }

    func fetchLatestReply(conversationID: UUID) -> Reply? {
        let request = Reply.fetchRequest()
        request.predicate = NSPredicate(format: "conversation.id == %@", conversationID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }

    @MainActor
    private func replaceContentBlocks(for reply: Reply, with contentBlocks: [ContentBlock]) {
        if let existingBlocks = reply.contentBlocks?.allObjects as? [ReplyContentBlock] {
            for block in existingBlocks {
                viewContext.delete(block)
            }
        }

        for (index, block) in contentBlocks.enumerated() {
            let persistedBlock = ReplyContentBlock(context: viewContext)
            persistedBlock.sortOrder = Int16(index)
            switch block {
            case .text(let text):
                persistedBlock.type = "text"
                persistedBlock.text = text
                persistedBlock.url = nil
                persistedBlock.rawJSON = nil
            case .image(let url):
                persistedBlock.type = "image"
                persistedBlock.text = nil
                persistedBlock.url = url
                persistedBlock.rawJSON = nil
            case .unknown(let rawJSON):
                persistedBlock.type = "unknown"
                persistedBlock.text = nil
                persistedBlock.url = nil
                persistedBlock.rawJSON = rawJSON
            }
            persistedBlock.reply = reply
        }
    }

    @MainActor
    func fetchLatestConfirmedReply(conversationID: UUID) -> Reply? {
        let request = Reply.fetchRequest()
        request.predicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [
                NSPredicate(format: "conversation.id == %@", conversationID as CVarArg),
                NSPredicate(format: "syncState == %@", ReplySyncState.confirmed.rawValue)
            ])
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }
}
