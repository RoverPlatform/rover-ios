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
import RoverFoundation
import XCTest

@testable import RoverNotifications

final class ConversationEntityTests: InboxPersistentContainerTestCase {
    func testCreateConversation() async {
        let id = UUID()
        let now = Date()

        await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = id
            conv.subject = "Hello"
            conv.createdAt = now
            conv.updatedAt = now
            conv.lastIncomingReplyAt = now
            conv.lastReadAt = nil
            assertViewContextSave("Failed to save conversation")
        }

        let fetched = await MainActor.run { () -> Conversation? in
            let req = Conversation.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            req.fetchLimit = 1
            return try? container.viewContext.fetch(req).first
        }

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.subject, "Hello")
        XCTAssertEqual(fetched?.isRead, false)
    }

    func testIsReadFallsBackToLastReplyAtWhenIncomingReplyAtMissing() async {
        let id = UUID()
        let lastReplyAt = Date()

        await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = id
            conversation.createdAt = lastReplyAt.addingTimeInterval(-60)
            conversation.updatedAt = lastReplyAt
            conversation.lastReplyAt = lastReplyAt
            conversation.lastIncomingReplyAt = nil
            conversation.lastReadAt = nil
            assertViewContextSave("Failed to seed fallback unread read-state data")
        }

        let fetched = await MainActor.run { () -> Conversation? in
            let req = Conversation.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            req.fetchLimit = 1
            return try? container.viewContext.fetch(req).first
        }

        XCTAssertEqual(fetched?.isRead, false)
    }

    func testIsReadFallsBackToLastReplyAtAndRespectsLastReadAt() async {
        let id = UUID()
        let lastReplyAt = Date()
        let lastReadAt = lastReplyAt.addingTimeInterval(30)

        await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = id
            conversation.createdAt = lastReplyAt.addingTimeInterval(-60)
            conversation.updatedAt = lastReplyAt
            conversation.lastReplyAt = lastReplyAt
            conversation.lastIncomingReplyAt = nil
            conversation.lastReadAt = lastReadAt
            assertViewContextSave("Failed to seed fallback read read-state data")
        }

        let fetched = await MainActor.run { () -> Conversation? in
            let req = Conversation.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            req.fetchLimit = 1
            return try? container.viewContext.fetch(req).first
        }

        XCTAssertEqual(fetched?.isRead, true)
    }

    func testCreateReplyLinkedToConversation() async {
        let convID = UUID()
        let replyID = UUID()

        await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = convID
            conv.createdAt = Date()
            conv.updatedAt = Date()

            let reply = Reply(context: container.viewContext)
            reply.id = replyID
            reply.senderType = ReplySenderType.participant.rawValue
            reply.participantID = "participant-1"
            reply.createdAt = Date()
            reply.conversation = conv

            let contentBlock = ReplyContentBlock(context: container.viewContext)
            contentBlock.type = "text"
            contentBlock.text = "Hello"
            contentBlock.sortOrder = 0
            contentBlock.reply = reply

            assertViewContextSave("Failed to save reply")
        }

        let fetchedReply = await MainActor.run { () -> Reply? in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", replyID as CVarArg)
            req.fetchLimit = 1
            return try? container.viewContext.fetch(req).first
        }

        XCTAssertNotNil(fetchedReply)
        XCTAssertEqual(fetchedReply?.senderType, "participant")
        XCTAssertEqual(fetchedReply?.participantID, "participant-1")
        XCTAssertEqual(fetchedReply?.conversation?.id, convID)
        XCTAssertEqual(fetchedReply?.contentBlocks?.count, 1)
    }

    func testCreateParticipantLinkedToConversation() async {
        let convID = UUID()

        await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = convID
            conv.createdAt = Date()
            conv.updatedAt = Date()

            let participant = Participant(context: container.viewContext)
            participant.id = "participant-1"
            participant.name = "Sam Rivera"
            participant.avatarURL = "https://cdn.example.com/sam.png"
            participant.bio = "Support Lead"
            participant.updatedAt = Date()
            conv.mutableSetValue(forKey: "participants").add(participant)
            assertViewContextSave("Failed to save participant relation")
        }

        let fetched = await MainActor.run { () -> Conversation? in
            let req = Conversation.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", convID as CVarArg)
            req.fetchLimit = 1
            return try? container.viewContext.fetch(req).first
        }

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.participants?.count, 1)
        let participant = fetched?.participants?.anyObject() as? Participant
        XCTAssertEqual(participant?.name, "Sam Rivera")
        XCTAssertEqual(participant?.id, "participant-1")
    }

    // MARK: - Badge Count Predicate Tests

    func testBadgeCountIncludesConversationWithOnlyLastReplyAt() async {
        // A conversation with only lastReplyAt (no lastIncomingReplyAt) and no lastReadAt
        // should be counted as unread in getBadgeCount(), matching Conversation.isRead.
        await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = UUID()
            conv.createdAt = Date()
            conv.updatedAt = Date()
            conv.lastReplyAt = Date()
            conv.lastIncomingReplyAt = nil
            conv.lastReadAt = nil
            assertViewContextSave("Failed to save conversation with lastReplyAt only")
        }

        let count = await MainActor.run { container.getBadgeCount() }
        XCTAssertEqual(count, 1, "getBadgeCount() should count a conversation that has only lastReplyAt as unread")
    }

    func testBadgeCountExcludesConversationWithNoReplies() async {
        // A conversation with neither lastReplyAt nor lastIncomingReplyAt has no activity to be
        // unread. Conversation.isRead returns true for this state; getBadgeCount() should agree.
        await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = UUID()
            conv.createdAt = Date()
            conv.updatedAt = Date()
            conv.lastReplyAt = nil
            conv.lastIncomingReplyAt = nil
            conv.lastReadAt = nil
            assertViewContextSave("Failed to save reply-less conversation")
        }

        let count = await MainActor.run { container.getBadgeCount() }
        XCTAssertEqual(count, 0, "getBadgeCount() should not count a conversation with no replies")
    }

    func testBadgeCountExcludesConversationReadViaLastReplyAt() async {
        // A conversation with lastReplyAt <= lastReadAt (no lastIncomingReplyAt) should NOT be counted.
        let replyAt = Date()
        let readAt = replyAt.addingTimeInterval(30)

        await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = UUID()
            conv.createdAt = replyAt.addingTimeInterval(-60)
            conv.updatedAt = replyAt
            conv.lastReplyAt = replyAt
            conv.lastIncomingReplyAt = nil
            conv.lastReadAt = readAt
            assertViewContextSave("Failed to save read conversation")
        }

        let count = await MainActor.run { container.getBadgeCount() }
        XCTAssertEqual(count, 0, "getBadgeCount() should not count a conversation whose lastReplyAt <= lastReadAt")
    }

    // MARK: - Upsert Contract Tests

    func testUpsertConversationDoesNotSaveContext() async throws {
        // stageConversation stages changes on the view context but intentionally does not save.
        // The caller is responsible for saving after batching multiple upserts.
        let item = TestDataGenerator.makeConversationItem(subject: "Test")

        let hasChangesAfterUpsert = try await MainActor.run {
            try container.stageConversation(item, participants: [])
            return container.viewContext.hasChanges
        }

        XCTAssertTrue(hasChangesAfterUpsert, "stageConversation should leave the context dirty without saving")
    }

    func testParticipantRemainsWhenConversationDeleted() async {
        let convID = UUID()

        await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = convID
            conv.createdAt = Date()
            conv.updatedAt = Date()

            let participant = Participant(context: container.viewContext)
            participant.id = "participant-1"
            participant.name = "Sam Rivera"
            participant.updatedAt = Date()
            conv.mutableSetValue(forKey: "participants").add(participant)
            assertViewContextSave("Failed to save participant relation")
        }

        await MainActor.run {
            let req = Conversation.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", convID as CVarArg)
            if let conv = try? container.viewContext.fetch(req).first {
                container.viewContext.delete(conv)
                assertViewContextSave("Failed to save conversation delete")
            }
        }

        let remainingParticipants = await MainActor.run { () -> Int in
            let req = Participant.fetchRequest()
            return (try? container.viewContext.count(for: req)) ?? -1
        }
        XCTAssertEqual(remainingParticipants, 1, "Participants should not be deleted when a conversation is deleted")
    }

    func testSharedParticipantStillLinkedAfterDeletingOneConversation() async {
        let firstConversationID = UUID()
        let secondConversationID = UUID()

        await MainActor.run {
            let firstConversation = Conversation(context: container.viewContext)
            firstConversation.id = firstConversationID
            firstConversation.createdAt = Date()
            firstConversation.updatedAt = Date()

            let secondConversation = Conversation(context: container.viewContext)
            secondConversation.id = secondConversationID
            secondConversation.createdAt = Date()
            secondConversation.updatedAt = Date()

            let participant = Participant(context: container.viewContext)
            participant.id = "participant-1"
            participant.name = "Sam Rivera"
            participant.updatedAt = Date()

            firstConversation.mutableSetValue(forKey: "participants").add(participant)
            secondConversation.mutableSetValue(forKey: "participants").add(participant)
            assertViewContextSave("Failed to save shared participant relation")
        }

        await MainActor.run {
            let request = Conversation.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", firstConversationID as CVarArg)
            if let firstConversation = try? container.viewContext.fetch(request).first {
                container.viewContext.delete(firstConversation)
                assertViewContextSave("Failed to save first conversation delete")
            }
        }

        let remainingParticipant = await MainActor.run { () -> Participant? in
            let request = Participant.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", "participant-1")
            request.fetchLimit = 1
            return try? container.viewContext.fetch(request).first
        }

        XCTAssertNotNil(remainingParticipant)

        let linkedConversationsCount = (remainingParticipant?.value(forKey: "conversations") as? NSSet)?.count ?? 0
        XCTAssertEqual(
            linkedConversationsCount,
            1,
            "Shared participant should stay linked to the remaining conversation"
        )
    }

    func testFetchLatestReplyReturnsNewestByCreatedAt() async {
        let conversationID = UUID()
        let olderReplyID = UUID()
        let newerReplyID = UUID()
        let now = Date()

        await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = now
            conversation.updatedAt = now

            let olderReply = Reply(context: container.viewContext)
            olderReply.id = olderReplyID
            olderReply.senderType = ReplySenderType.participant.rawValue
            olderReply.participantID = "p-1"
            olderReply.createdAt = now.addingTimeInterval(-60)
            olderReply.conversation = conversation
            attachTextBlock("First", to: olderReply)

            let newerReply = Reply(context: container.viewContext)
            newerReply.id = newerReplyID
            newerReply.senderType = ReplySenderType.fan.rawValue
            newerReply.participantID = "fan-1"
            newerReply.createdAt = now
            newerReply.conversation = conversation
            attachTextBlock("Second", to: newerReply)

            assertViewContextSave("Failed to seed replies for fetchLatestReply")
        }

        let latestReply = await MainActor.run {
            container.fetchLatestReply(conversationID: conversationID)
        }
        XCTAssertEqual(latestReply?.id, newerReplyID)
    }

    func testFetchLatestReplyReturnsNilWhenNoReplies() async {
        let conversationID = UUID()

        await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = Date()
            conversation.updatedAt = Date()
            assertViewContextSave("Failed to seed conversation without replies")
        }

        let latestReply = await MainActor.run {
            container.fetchLatestReply(conversationID: conversationID)
        }
        XCTAssertNil(latestReply)
    }

    func testFetchLatestConfirmedReplySkipsQueuedOptimisticReplies() async {
        let conversationID = UUID()
        let sentReplyID = UUID()
        let queuedReplyID = UUID()
        let now = Date()

        await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = now
            conversation.updatedAt = now

            let sentReply = Reply(context: container.viewContext)
            sentReply.id = sentReplyID
            sentReply.senderType = ReplySenderType.participant.rawValue
            sentReply.participantID = "p-1"
            sentReply.createdAt = now.addingTimeInterval(-30)
            sentReply.syncState = ReplySyncState.confirmed.rawValue
            sentReply.externalID = nil
            sentReply.conversation = conversation
            attachTextBlock("Server", to: sentReply)

            let queuedReply = Reply(context: container.viewContext)
            queuedReply.id = queuedReplyID
            queuedReply.senderType = ReplySenderType.fan.rawValue
            queuedReply.participantID = nil
            queuedReply.createdAt = now
            queuedReply.syncState = ReplySyncState.queued.rawValue
            queuedReply.externalID = "ext-queued"
            queuedReply.conversation = conversation
            attachTextBlock("Queued", to: queuedReply)

            assertViewContextSave("Failed to seed sent + queued replies")
        }

        let latestSentReply = await MainActor.run {
            container.fetchLatestConfirmedReply(conversationID: conversationID)
        }
        XCTAssertEqual(latestSentReply?.id, sentReplyID)
    }

    func testFetchLatestConfirmedReplyReturnsNilWhenOnlyQueuedRepliesExist() async {
        let conversationID = UUID()
        let now = Date()

        await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = now
            conversation.updatedAt = now

            let queuedReply = Reply(context: container.viewContext)
            queuedReply.id = UUID()
            queuedReply.senderType = ReplySenderType.fan.rawValue
            queuedReply.participantID = nil
            queuedReply.createdAt = now
            queuedReply.syncState = ReplySyncState.queued.rawValue
            queuedReply.externalID = "ext-only-queued"
            queuedReply.conversation = conversation
            attachTextBlock("Queued", to: queuedReply)

            assertViewContextSave("Failed to seed queued-only replies")
        }

        let latestSentReply = await MainActor.run {
            container.fetchLatestConfirmedReply(conversationID: conversationID)
        }
        XCTAssertNil(latestSentReply)
    }

    func testFetchLatestConfirmedReplyIgnoresSentReplies() async throws {
        let conversationID = UUID()

        try await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = Date()
            conversation.updatedAt = Date()

            let reply = Reply(context: container.viewContext)
            reply.id = UUID()
            reply.createdAt = Date()
            reply.senderType = ReplySenderType.participant.rawValue
            reply.externalID = nil
            reply.syncState = ReplySyncState.sent.rawValue  // 202 accepted, not yet synced back
            reply.conversation = conversation
            try container.viewContext.save()
        }

        let result = await MainActor.run {
            container.fetchLatestConfirmedReply(conversationID: conversationID)
        }
        XCTAssertNil(result, "fetchLatestConfirmedReply should not return .sent replies")
    }

    func testMarkConversationAsReadUpdatesReadState() async {
        let conversationID = UUID()
        let replyID = UUID()
        let replyAt = Date()

        await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.subject = "Support"
            conversation.createdAt = replyAt.addingTimeInterval(-3600)
            conversation.updatedAt = replyAt.addingTimeInterval(-3600)
            conversation.lastIncomingReplyAt = replyAt

            let reply = Reply(context: container.viewContext)
            reply.id = replyID
            reply.senderType = ReplySenderType.participant.rawValue
            reply.participantID = "p-1"
            reply.createdAt = replyAt
            reply.conversation = conversation
            attachTextBlock("Latest", to: reply)

            assertViewContextSave("Failed to seed read-state test data")
            container.markConversationAsRead(
                conversationID: conversationID,
                lastReadReplyID: replyID,
                lastReadAt: replyAt
            )
        }

        let conversation = await MainActor.run { container.fetchConversation(id: conversationID) }
        XCTAssertEqual(conversation?.isRead, true)
        XCTAssertEqual(conversation?.lastReadReplyID, replyID)
        XCTAssertEqual(conversation?.lastReadAt, replyAt)
    }

    func testMarkConversationAsReadDoesNotRollBackNewerReadState() async {
        let conversationID = UUID()
        let olderReplyID = UUID()
        let newerReplyID = UUID()
        let newerReadAt = Date()
        let olderReadAt = newerReadAt.addingTimeInterval(-30)

        await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = olderReadAt.addingTimeInterval(-3600)
            conversation.updatedAt = olderReadAt
            conversation.lastIncomingReplyAt = newerReadAt

            let olderReply = Reply(context: container.viewContext)
            olderReply.id = olderReplyID
            olderReply.senderType = ReplySenderType.participant.rawValue
            olderReply.participantID = "p-1"
            olderReply.createdAt = olderReadAt
            olderReply.conversation = conversation
            attachTextBlock("Older", to: olderReply)

            let newerReply = Reply(context: container.viewContext)
            newerReply.id = newerReplyID
            newerReply.senderType = ReplySenderType.participant.rawValue
            newerReply.participantID = "p-1"
            newerReply.createdAt = newerReadAt
            newerReply.conversation = conversation
            attachTextBlock("Newer", to: newerReply)

            assertViewContextSave("Failed to seed anti-regressive read-state test data")

            // Mark read with the newer reply first (simulates open-sync completing).
            container.markConversationAsRead(
                conversationID: conversationID,
                lastReadReplyID: newerReplyID,
                lastReadAt: newerReadAt
            )

            // Then attempt to mark read with an older reply (simulates a late/racing response).
            container.markConversationAsRead(
                conversationID: conversationID,
                lastReadReplyID: olderReplyID,
                lastReadAt: olderReadAt
            )
        }

        let conversation = await MainActor.run { container.fetchConversation(id: conversationID) }
        XCTAssertEqual(
            conversation?.lastReadReplyID,
            newerReplyID,
            "Older mark-read should not overwrite the newer lastReadReplyID"
        )
        XCTAssertEqual(
            conversation?.lastReadAt,
            newerReadAt,
            "Older lastReadAt should not roll back the newer lastReadAt"
        )
    }

    func testMarkConversationAsReadDefaultsLastReadAtToReplyCreatedAt() async {
        let conversationID = UUID()
        let replyID = UUID()
        let replyAt = Date()

        await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = replyAt.addingTimeInterval(-60)
            conversation.updatedAt = replyAt.addingTimeInterval(-60)
            conversation.lastIncomingReplyAt = replyAt

            let reply = Reply(context: container.viewContext)
            reply.id = replyID
            reply.senderType = ReplySenderType.participant.rawValue
            reply.participantID = "p-1"
            reply.createdAt = replyAt
            reply.conversation = conversation
            attachTextBlock("Hi", to: reply)

            assertViewContextSave("Failed to seed default lastReadAt test data")
            container.markConversationAsRead(
                conversationID: conversationID,
                lastReadReplyID: replyID,
                lastReadAt: nil
            )
        }

        let conversation = await MainActor.run { container.fetchConversation(id: conversationID) }
        XCTAssertEqual(conversation?.lastReadAt, replyAt)
        XCTAssertEqual(conversation?.isRead, true)
    }

    func testMarkConversationAsReadWithNilReplyIDUpdatesOnlyLastReadAt() async throws {
        // Arrange
        let conversationID = UUID()
        let existingReplyID = UUID()
        let lastReadAt = Date()

        await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = Date()
            conversation.updatedAt = Date()
            conversation.lastReadReplyID = existingReplyID
            assertViewContextSave("Failed to seed nil-replyID test data")
        }

        // Act — nil lastReadReplyID should not change the stored reply ID
        await MainActor.run {
            container.markConversationAsRead(
                conversationID: conversationID,
                lastReadReplyID: nil,
                lastReadAt: lastReadAt
            )
        }

        // Assert
        let updated = await MainActor.run { container.fetchConversation(id: conversationID) }
        XCTAssertEqual(updated?.lastReadAt, lastReadAt, "lastReadAt should be updated")
        XCTAssertEqual(
            updated?.lastReadReplyID,
            existingReplyID,
            "lastReadReplyID should not change when nil is passed"
        )
    }

    func testMarkConversationAsReadWithNilReplyIDDoesNotRollBackNewerLastReadAt() async throws {
        // Arrange
        let conversationID = UUID()
        let conversation = Conversation(context: container.viewContext)
        conversation.id = conversationID
        conversation.createdAt = Date()
        conversation.updatedAt = Date()
        let newerDate = Date()
        conversation.lastReadAt = newerDate

        await MainActor.run {
            self.assertViewContextSave("Failed to seed anti-regressive nil-replyID test data")
        }

        let olderDate = newerDate.addingTimeInterval(-30)

        // Act — older timestamp should not roll back lastReadAt
        await MainActor.run {
            self.container.markConversationAsRead(
                conversationID: conversationID,
                lastReadReplyID: nil,
                lastReadAt: olderDate
            )
        }

        // Assert
        let updated = await MainActor.run { container.fetchConversation(id: conversationID) }
        XCTAssertEqual(updated?.lastReadAt, newerDate, "lastReadAt must not be rolled back by an older timestamp")
    }

    func testStageReplyWithExternalIDMatchSetsConfirmedAndClearsExternalID() async throws {
        let conversationID = UUID()
        let externalID = "ext-123"
        let now = Date()

        try await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = now
            conversation.updatedAt = now

            // Seed an optimistic fan reply
            let optimistic = Reply(context: container.viewContext)
            optimistic.id = UUID()
            optimistic.senderType = ReplySenderType.fan.rawValue
            optimistic.externalID = externalID
            optimistic.syncState = ReplySyncState.sent.rawValue
            optimistic.createdAt = now
            optimistic.conversation = conversation
            try container.viewContext.save()
        }

        // Act: stage a server reply that matches by externalID
        let serverReply = ReplyItem(
            id: UUID(),
            conversationID: conversationID,
            senderType: .fan,
            participantID: nil,
            content: [.text(text: "Hello")],
            externalID: externalID,
            createdAt: now
        )
        try await MainActor.run {
            let conversation = container.fetchConversation(id: conversationID)!
            try container.stageReply(serverReply, into: conversation)
            try container.viewContext.save()
        }

        let result = await MainActor.run { () -> Reply? in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "conversation.id == %@", conversationID as CVarArg)
            req.fetchLimit = 1
            return try? container.viewContext.fetch(req).first
        }
        XCTAssertEqual(result?.syncState, ReplySyncState.confirmed.rawValue)
        XCTAssertNil(result?.externalID, "externalID must be cleared after server reconciliation")
    }

    func testStageReplyWithoutExternalIDSetsConfirmed() async throws {
        let conversationID = UUID()
        let now = Date()

        try await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = now
            conversation.updatedAt = now
            try container.viewContext.save()
        }

        // Act: stage a participant reply arriving from the server (no externalID)
        let participantReply = ReplyItem(
            id: UUID(),
            conversationID: conversationID,
            senderType: .participant,
            participantID: "p-1",
            content: [.text(text: "Hi there")],
            externalID: nil,
            createdAt: now
        )
        try await MainActor.run {
            let conversation = container.fetchConversation(id: conversationID)!
            try container.stageReply(participantReply, into: conversation)
            try container.viewContext.save()
        }

        let result = await MainActor.run { () -> Reply? in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "conversation.id == %@", conversationID as CVarArg)
            req.fetchLimit = 1
            return try? container.viewContext.fetch(req).first
        }
        XCTAssertEqual(result?.syncState, ReplySyncState.confirmed.rawValue)
    }

    func testConversationItemDecodesLastIncomingParticipantID() throws {
        let json = """
            {
                "id": "00000000-0000-0000-0000-000000000001",
                "participantIDs": [],
                "createdAt": "2026-01-01T00:00:00.000+00:00",
                "updatedAt": "2026-01-01T00:00:00.000+00:00",
                "lastIncomingParticipantID": "agent-42"
            }
            """.data(using: .utf8)!

        let item = try JSONDecoder.default.decode(ConversationItem.self, from: json)
        XCTAssertEqual(item.lastIncomingParticipantID, "agent-42")
    }

    func testConversationItemDecodesNilLastIncomingParticipantID() throws {
        let json = """
            {
                "id": "00000000-0000-0000-0000-000000000001",
                "participantIDs": [],
                "createdAt": "2026-01-01T00:00:00.000+00:00",
                "updatedAt": "2026-01-01T00:00:00.000+00:00"
            }
            """.data(using: .utf8)!

        let item = try JSONDecoder.default.decode(ConversationItem.self, from: json)
        XCTAssertNil(item.lastIncomingParticipantID)
    }

    func testConversationEntityPersistsLastIncomingParticipantID() async throws {
        let convID = UUID()

        try await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = convID
            conv.createdAt = Date()
            conv.updatedAt = Date()
            conv.lastIncomingParticipantID = "agent-42"
            try container.viewContext.save()
        }

        let fetched = await MainActor.run { container.fetchConversation(id: convID) }

        XCTAssertEqual(fetched?.lastIncomingParticipantID, "agent-42")
    }

    func testStageConversationSetsLastIncomingParticipantID() async throws {
        let convID = UUID()
        let now = Date()
        let item = TestDataGenerator.makeConversationItem(
            id: convID,
            lastIncomingParticipantID: "agent-42",
            createdAt: now,
            updatedAt: now
        )

        try await MainActor.run {
            try container.stageConversation(item, participants: [])
            try container.viewContext.save()
        }

        let fetched = await MainActor.run { container.fetchConversation(id: convID) }

        XCTAssertEqual(fetched?.lastIncomingParticipantID, "agent-42")
    }

    func testStageConversationDoesNotOverwriteLastIncomingParticipantIDWithOlderPayload() async throws {
        let convID = UUID()
        let t1 = Date()
        let t2 = t1.addingTimeInterval(60)

        // Stage the newer payload first (updatedAt = t2).
        let newerItem = TestDataGenerator.makeConversationItem(
            id: convID,
            lastIncomingParticipantID: "agent-new",
            createdAt: t1,
            updatedAt: t2
        )
        try await MainActor.run {
            try container.stageConversation(newerItem, participants: [])
            try container.viewContext.save()
        }

        // Stage a stale payload (updatedAt = t1) that carries an outdated participant ID.
        let olderItem = TestDataGenerator.makeConversationItem(
            id: convID,
            lastIncomingParticipantID: "agent-old",
            createdAt: t1,
            updatedAt: t1
        )
        try await MainActor.run {
            try container.stageConversation(olderItem, participants: [])
            try container.viewContext.save()
        }

        let fetched = await MainActor.run { container.fetchConversation(id: convID) }

        XCTAssertEqual(
            fetched?.lastIncomingParticipantID,
            "agent-new",
            "A stale payload must not overwrite lastIncomingParticipantID set by a newer payload"
        )
    }

}
