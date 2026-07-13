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

    // MARK: - Conversation Fetch

    static func fetchConversations() -> NSFetchRequest<Conversation> {
        let request = Conversation.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "lastReplyAt", ascending: false)]
        return request
    }

    // MARK: - Conversation SyncStatus

    @MainActor
    func getConversationsSyncStatus() -> SyncStatus? {
        return try? viewContext.fetch(syncStatusRequest(for: .conversations)).first
    }

    @MainActor
    func stageConversationsSyncStatus(cursor: String?, backwardsCursor: String?, historyComplete: Bool) throws {
        let existing = try viewContext.fetch(syncStatusRequest(for: .conversations)).first
        let syncStatus =
            existing
            ?? {
                let s = SyncStatus(context: viewContext)
                s.roverEntity = SyncEntity.conversations.rawValue
                return s
            }()
        syncStatus.cursor = cursor
        syncStatus.backwardsCursor = backwardsCursor
        syncStatus.historyComplete = historyComplete
    }

    @MainActor
    func latestConversationActivityDate() -> Date? {
        let lastReplyRequest = Conversation.fetchRequest()
        lastReplyRequest.predicate = NSPredicate(format: "lastReplyAt != nil")
        lastReplyRequest.sortDescriptors = [NSSortDescriptor(key: "lastReplyAt", ascending: false)]
        lastReplyRequest.fetchLimit = 1
        let lastReplyAt = (try? viewContext.fetch(lastReplyRequest).first)?.lastReplyAt

        let createdAtRequest = Conversation.fetchRequest()
        createdAtRequest.predicate = NSPredicate(format: "lastReplyAt == nil AND createdAt != nil")
        createdAtRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        createdAtRequest.fetchLimit = 1
        let createdAt = (try? viewContext.fetch(createdAtRequest).first)?.createdAt

        guard let lastReplyAt else {
            return createdAt
        }
        guard let createdAt else {
            return lastReplyAt
        }
        return max(lastReplyAt, createdAt)
    }

    // MARK: - Upsert

    /// Stages all conversations in a batch, filtering `allParticipants` down to each conversation's
    /// own participant set before persisting. Does not save the context.
    @MainActor
    func stageConversations(_ items: [ConversationItem], allParticipants: [ParticipantItem]) throws {
        for item in items {
            let participants = allParticipants.filter { item.participantIDs.contains($0.id) }
            try stageConversation(item, participants: participants)
        }
    }

    @MainActor
    @discardableResult
    func stageConversation(_ item: ConversationItem, participants: [ParticipantItem]) throws -> Conversation {
        let request = Conversation.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
        request.fetchLimit = 1

        let existing = try viewContext.fetch(request).first
        let conv = existing ?? Conversation(context: viewContext)
        conv.id = item.id

        // Only allow newer conversation payloads to replace metadata, and keep
        // timeline fields monotonic so delayed pushes/sync responses cannot roll
        // back ordering or badge state derived from reply timestamps.
        let shouldApplyMetadata = shouldApplyConversationMetadata(
            existingUpdatedAt: conv.updatedAt,
            incomingUpdatedAt: item.updatedAt
        )

        conv.lastReplyAt = mergeLatestDate(existing: conv.lastReplyAt, incoming: item.lastReplyAt)
        conv.lastIncomingReplyAt = mergeLatestDate(
            existing: conv.lastIncomingReplyAt,
            incoming: item.lastIncomingReplyAt
        )
        conv.updatedAt = mergeLatestDate(existing: conv.updatedAt, incoming: item.updatedAt)
        conv.createdAt = mergeEarliestDate(existing: conv.createdAt, incoming: item.createdAt)

        if shouldApplyMetadata {
            conv.subject = item.subject
            conv.lastReplyPreview = item.lastReplyPreview
            conv.lastIncomingParticipantID = item.lastIncomingParticipantID
        }

        mergeIncomingReadState(
            conversation: conv,
            incomingLastReadAt: item.lastReadAt,
            incomingLastReadReplyID: item.lastReadReplyID
        )

        try upsertParticipants(participants, for: conv)
        return conv
    }

    private func shouldApplyConversationMetadata(existingUpdatedAt: Date?, incomingUpdatedAt: Date) -> Bool {
        guard let existingUpdatedAt else {
            return true
        }

        return incomingUpdatedAt > existingUpdatedAt
    }

    private func mergeLatestDate(existing: Date?, incoming: Date?) -> Date? {
        guard let incoming else {
            return existing
        }
        guard let existing else {
            return incoming
        }

        return max(existing, incoming)
    }

    private func mergeEarliestDate(existing: Date?, incoming: Date) -> Date {
        guard let existing else {
            return incoming
        }

        return min(existing, incoming)
    }

    private func mergeIncomingReadState(
        conversation: Conversation,
        incomingLastReadAt: Date?,
        incomingLastReadReplyID: UUID?
    ) {
        guard let incomingLastReadAt else {
            return
        }

        if let existingLastReadAt = conversation.lastReadAt, incomingLastReadAt <= existingLastReadAt {
            return
        }

        conversation.lastReadAt = incomingLastReadAt
        conversation.lastReadReplyID = incomingLastReadReplyID
    }

    @MainActor
    private func upsertParticipants(_ items: [ParticipantItem], for conversation: Conversation) throws {
        guard !items.isEmpty else {
            return
        }

        let participants = try stageParticipants(items)
        let conversationParticipants = conversation.mutableSetValue(forKey: "participants")
        conversationParticipants.addObjects(from: participants)
    }

    @MainActor
    @discardableResult
    func stageParticipants(_ items: [ParticipantItem]) throws -> [Participant] {
        let participantIDs = items.map(\.id)
        let request = Participant.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", participantIDs)

        let existingParticipants = try viewContext.fetch(request)
        var existingByID: [String: Participant] = [:]
        for participant in existingParticipants {
            guard let id = participant.id else {
                continue
            }
            existingByID[id] = participant
        }

        var participants: [Participant] = []
        for item in items {
            let participant = existingByID[item.id] ?? Participant(context: viewContext)
            participant.id = item.id
            participant.name = item.name
            participant.avatarURL = item.avatarURL
            participant.bio = item.bio
            participant.updatedAt = item.updatedAt
            participants.append(participant)
        }
        return participants
    }

    // MARK: - Read State

    @MainActor
    func markConversationAsRead(conversationID: UUID, lastReadReplyID: UUID?, lastReadAt: Date? = nil) {

        guard let conversation = fetchConversation(id: conversationID) else {
            os_log(
                "Failed to mark conversation read: conversation not found (%{private}@)",
                log: .hub,
                type: .error,
                conversationID.uuidString
            )
            return
        }

        guard let lastReadReplyID else {
            // Server returned null lastReadReplyID (conversation had no replies).
            // Update only lastReadAt, preserving the existing lastReadReplyID.
            let resolvedReadAt = lastReadAt ?? Date()
            if let existingLastReadAt = conversation.lastReadAt, resolvedReadAt <= existingLastReadAt {
                return
            }
            conversation.lastReadAt = resolvedReadAt
            try? viewContext.save()
            return
        }

        let request = Reply.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", lastReadReplyID as CVarArg)
        request.fetchLimit = 1

        do {
            guard let reply = try viewContext.fetch(request).first else {
                os_log(
                    "Failed to mark conversation read: reply not found (%{private}@)",
                    log: .hub,
                    type: .error,
                    lastReadReplyID.uuidString
                )
                return
            }

            guard reply.conversation?.id == conversationID else {
                os_log(
                    "Failed to mark conversation read: reply %{private}@ does not belong to conversation %{private}@",
                    log: .hub,
                    type: .error,
                    lastReadReplyID.uuidString,
                    conversationID.uuidString
                )
                return
            }

            let resolvedReadAt = lastReadAt ?? reply.createdAt ?? Date()
            if let existingLastReadAt = conversation.lastReadAt {
                // Mark-read updates can race (for example, open-sync + polling).
                // Never allow an older read timestamp to roll back a newer one.
                if resolvedReadAt < existingLastReadAt {
                    return
                }

                // If timestamps tie, keep writes deterministic to avoid churn from
                // duplicate/late arrivals with the same read-at moment.
                if resolvedReadAt == existingLastReadAt,
                    let existingLastReadReplyID = conversation.lastReadReplyID,
                    lastReadReplyID.uuidString <= existingLastReadReplyID.uuidString
                {
                    return
                }
            }

            conversation.lastReadReplyID = lastReadReplyID
            conversation.lastReadAt = resolvedReadAt

            try viewContext.save()
        } catch {
            os_log(
                "Failed to mark conversation as read: %{private}@",
                log: .hub,
                type: .error,
                error.localizedDescription
            )
        }
    }

    /// Stages an optimistic conversation preview update without saving.
    ///
    /// The caller is responsible for saving the view context after calling this method.
    /// This is intentional: the preview update must be committed atomically with the
    /// corresponding `insertOptimisticReply` call so that a failed reply insert does
    /// not leave a dangling preview update in the store.
    @MainActor
    func stageConversationPreviewOptimistically(conversationID: UUID, text: String, at: Date) {
        guard let conversation = fetchConversation(id: conversationID) else {
            return
        }
        conversation.lastReplyPreview = text
        conversation.lastReplyAt = at
        conversation.updatedAt = at
    }

    /// Surgically drops all conversation data: Conversation (cascades Reply and
    /// ReplyContentBlock), Participant, and all SyncStatus records for
    /// "conversations" and any "replies:{uuid}" keys. Leaves Post and post sync
    /// data untouched. Does not bump `conversationStoreGeneration` itself — the shared epoch is
    /// bumped once, first, by `bumpConversationStoreGeneration()`, which `HubSyncCoordinator`'s
    /// reset task always calls before cancellation and before this method. Must be called on the
    /// main actor.
    @MainActor
    func dropAllConversations() {
        // Delete all conversations; cascade rules handle Reply + ReplyContentBlock.
        let conversations = (try? viewContext.fetch(Conversation.fetchRequest())) ?? []
        conversations.forEach { viewContext.delete($0) }

        // Participant.conversations uses Nullify — must be deleted separately.
        let participants = (try? viewContext.fetch(Participant.fetchRequest())) ?? []
        participants.forEach { viewContext.delete($0) }

        // Delete the conversations forward/backward cursor.
        if let convStatus = try? viewContext.fetch(syncStatusRequest(for: .conversations)).first {
            viewContext.delete(convStatus)
        }

        // Delete all per-conversation reply cursors (key pattern "replies:{uuid}").
        let replyStatusRequest = SyncStatus.fetchRequest()
        replyStatusRequest.predicate = NSPredicate(format: "roverEntity BEGINSWITH %@", "replies:")
        let replyStatuses = (try? viewContext.fetch(replyStatusRequest)) ?? []
        replyStatuses.forEach { viewContext.delete($0) }

        do {
            try viewContext.save()
        } catch {
            os_log(
                "Failed to drop all conversations: %{private}@",
                log: .hub,
                type: .error,
                error.localizedDescription
            )
            viewContext.rollback()
        }
    }

}
