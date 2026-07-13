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
import XCTest

@testable import RoverNotifications

final class ReplyQueuePersistenceTests: InboxPersistentContainerTestCase {
    func testInsertOptimisticReplyStoresQueuedMetadata() async {
        let conversationID = UUID()

        await MainActor.run {
            let conversation = Conversation(context: self.container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = Date()
            conversation.updatedAt = Date()
            assertViewContextSave("Failed to save conversation fixture")

            _ = self.container.insertOptimisticReply(
                conversationID: conversationID,
                text: "Hello",
                externalID: "ext-1"
            )
            assertViewContextSave("Failed to persist optimistic reply fixture")
            self.container.viewContext.reset()
        }

        let reply = await MainActor.run { () -> Reply? in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "externalID == %@", "ext-1")
            req.fetchLimit = 1
            return try? self.container.viewContext.fetch(req).first
        }

        XCTAssertEqual(reply?.senderType, "fan")
        XCTAssertNil(reply?.participantID)
        XCTAssertEqual(reply?.syncState, ReplySyncState.queued.rawValue)
        XCTAssertEqual(reply?.externalID, "ext-1")
        XCTAssertEqual(reply?.persistedContentBlocks, [.text(text: "Hello")])
    }

    func testMarkReplySentUpdatesQueuedReplyState() async {
        let conversationID = UUID()
        let now = Date()

        await MainActor.run {
            let conversation = Conversation(context: self.container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = now
            conversation.updatedAt = now

            _ = self.container.insertOptimisticReply(
                conversationID: conversationID,
                text: "Queued",
                externalID: "ext-reconcile"
            )
            assertViewContextSave("Failed to save queued/server reply fixture")

            let request = Reply.fetchRequest()
            request.predicate = NSPredicate(format: "externalID == %@", "ext-reconcile")
            request.fetchLimit = 1
            if let queuedReply = (try? self.container.viewContext.fetch(request))?.first {
                queuedReply.retryCount = 2
                queuedReply.nextRetryAt = now.addingTimeInterval(30)
                queuedReply.lastSendError = "network"
            }

            self.container.markReplySent(externalID: "ext-reconcile")
            assertViewContextSave("Failed to save reply sent-state update")
        }

        let result = await MainActor.run { () -> Reply? in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "externalID == %@", "ext-reconcile")
            req.fetchLimit = 1
            return try? self.container.viewContext.fetch(req).first
        }

        XCTAssertEqual(result?.syncState, ReplySyncState.sent.rawValue)
        XCTAssertEqual(result?.externalID, "ext-reconcile")
        XCTAssertEqual(result?.retryCount, 0)
        XCTAssertNil(result?.nextRetryAt)
        XCTAssertNil(result?.lastSendError)
        XCTAssertEqual(result?.persistedContentBlocks, [.text(text: "Queued")])
    }

    func testFetchQueuedRepliesReturnsAllQueuedIncludingInBackoff() async throws {
        let conversationID = UUID()
        let now = Date()

        try await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = conversationID
            conv.createdAt = now
            conv.updatedAt = now

            // Eligible: nextRetryAt in the past
            let eligible = try XCTUnwrap(
                container.insertOptimisticReply(
                    conversationID: conversationID,
                    text: "Eligible",
                    externalID: "ext-eligible"
                )
            )
            eligible.nextRetryAt = now.addingTimeInterval(-1)

            // In backoff: nextRetryAt in the future
            let inBackoff = try XCTUnwrap(
                container.insertOptimisticReply(
                    conversationID: conversationID,
                    text: "In backoff",
                    externalID: "ext-backoff"
                )
            )
            inBackoff.nextRetryAt = now.addingTimeInterval(30)

            assertViewContextSave("Failed to save replies for backoff test")
        }

        let replies = await MainActor.run {
            container.fetchQueuedReplies(conversationID: conversationID)
        }

        XCTAssertEqual(
            replies.count,
            2,
            "fetchQueuedReplies should return all queued replies regardless of nextRetryAt"
        )
    }

    func testFetchQueuedRepliesReturnsInCreatedAtOrder() async throws {
        let conversationID = UUID()
        let now = Date()

        try await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = conversationID
            conv.createdAt = now
            conv.updatedAt = now

            let older = try XCTUnwrap(
                container.insertOptimisticReply(
                    conversationID: conversationID,
                    text: "Older",
                    externalID: "ext-older"
                )
            )
            older.createdAt = now.addingTimeInterval(-5)
            older.nextRetryAt = now.addingTimeInterval(-1)

            let newer = try XCTUnwrap(
                container.insertOptimisticReply(
                    conversationID: conversationID,
                    text: "Newer",
                    externalID: "ext-newer"
                )
            )
            newer.createdAt = now.addingTimeInterval(-2)
            newer.nextRetryAt = now.addingTimeInterval(-1)

            assertViewContextSave("Failed to save replies for ordering test")
        }

        let externalIDs = await MainActor.run {
            container.fetchQueuedReplies(conversationID: conversationID).compactMap { $0.externalID }
        }

        XCTAssertEqual(externalIDs, ["ext-older", "ext-newer"])
    }

    func testFetchConversationIDsWithQueuedReplies() async throws {
        let convA = UUID()
        let convB = UUID()
        let convC = UUID()
        let now = Date()

        await MainActor.run {
            for id in [convA, convB, convC] {
                let conv = Conversation(context: container.viewContext)
                conv.id = id
                conv.createdAt = now
                conv.updatedAt = now
            }

            // Give convA an earlier createdAt so the FIFO sort order is deterministic.
            let replyA = container.insertOptimisticReply(
                conversationID: convA,
                text: "A reply",
                externalID: "ext-a"
            )
            replyA?.createdAt = Date(timeIntervalSince1970: 1_000)

            let replyB = container.insertOptimisticReply(
                conversationID: convB,
                text: "B reply",
                externalID: "ext-b"
            )
            replyB?.createdAt = Date(timeIntervalSince1970: 2_000)
            // convC gets no queued reply

            assertViewContextSave("Failed to save conversations for IDs test")
        }

        let ids = await MainActor.run {
            container.fetchConversationIDsWithQueuedReplies()
        }

        XCTAssertEqual(ids, [convA, convB])
        XCTAssertFalse(ids.contains(convC))
    }

    func testFetchConversationIDsExcludesNonQueuedReplies() async throws {
        let conversationID = UUID()
        let now = Date()

        await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = conversationID
            conv.createdAt = now
            conv.updatedAt = now

            // Insert a reply and mark it sent
            let reply = container.insertOptimisticReply(
                conversationID: conversationID,
                text: "Sent",
                externalID: "ext-sent"
            )
            reply?.syncState = ReplySyncState.sent.rawValue
            assertViewContextSave("Failed to save sent reply fixture")
        }

        let ids = await MainActor.run {
            container.fetchConversationIDsWithQueuedReplies()
        }

        XCTAssertTrue(ids.isEmpty, "Sent reply should not appear in queued conversation IDs")
    }

    func testMarkReplySentIsNoOpForUnknownExternalID() async {
        await MainActor.run {
            self.container.markReplySent(externalID: "ext-missing")
            assertViewContextSave("Failed to save unknown-externalID mark sent result")
        }

        let replyCount = await MainActor.run { () -> Int in
            let req = Reply.fetchRequest()
            return (try? self.container.viewContext.count(for: req)) ?? -1
        }

        XCTAssertEqual(replyCount, 0)
    }

    func testSweepExpiredQueuedRepliesMarksExpiredAsFailed() async throws {
        let conversationID = UUID()
        let now = Date()
        let generation = await MainActor.run { container.conversationStoreGeneration }

        try await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = conversationID
            conv.createdAt = now
            conv.updatedAt = now

            // Expired: createdAt well outside the 120s window
            let expired = try XCTUnwrap(
                container.insertOptimisticReply(
                    conversationID: conversationID,
                    text: "Expired",
                    externalID: "ext-expired"
                )
            )
            expired.createdAt = now.addingTimeInterval(-130)

            // Fresh: within the window — must not be swept
            _ = try XCTUnwrap(
                container.insertOptimisticReply(
                    conversationID: conversationID,
                    text: "Fresh",
                    externalID: "ext-fresh"
                )
            )

            assertViewContextSave("Failed to save replies for sweep test")
        }

        let cutoff = now.addingTimeInterval(-120)
        let sweptCount = try await MainActor.run {
            try container.sweepExpiredQueuedReplies(before: cutoff, generation: generation)
        }

        XCTAssertEqual(sweptCount, 1)

        let states = await MainActor.run { () -> [String: String] in
            let req = Reply.fetchRequest()
            let replies = (try? container.viewContext.fetch(req)) ?? []
            return Dictionary(
                uniqueKeysWithValues: replies.compactMap { r in
                    guard let id = r.externalID, let state = r.syncState else { return nil }
                    return (id, state)
                }
            )
        }

        XCTAssertEqual(states["ext-expired"], ReplySyncState.failed.rawValue)
        XCTAssertEqual(states["ext-fresh"], ReplySyncState.queued.rawValue)
    }

    func testSweepExpiredQueuedRepliesIgnoresNonQueuedReplies() async throws {
        let conversationID = UUID()
        let now = Date()
        let generation = await MainActor.run { container.conversationStoreGeneration }

        try await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = conversationID
            conv.createdAt = now
            conv.updatedAt = now

            // Already sent — must not be touched by the sweep
            let sent = try XCTUnwrap(
                container.insertOptimisticReply(
                    conversationID: conversationID,
                    text: "Sent",
                    externalID: "ext-sent"
                )
            )
            sent.createdAt = now.addingTimeInterval(-130)
            sent.syncState = ReplySyncState.sent.rawValue

            assertViewContextSave("Failed to save sent reply fixture")
        }

        let cutoff = now.addingTimeInterval(-120)
        let sweptCount = try await MainActor.run {
            try container.sweepExpiredQueuedReplies(before: cutoff, generation: generation)
        }

        XCTAssertEqual(sweptCount, 0)
    }

    func testFetchSoonestQueuedReplyRetryAtReturnsNilWhenNoRepliesInBackoff() async throws {
        let conversationID = UUID()
        let now = Date()
        try await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = conversationID
            conv.createdAt = now
            conv.updatedAt = now
            _ = try XCTUnwrap(
                container.insertOptimisticReply(
                    conversationID: conversationID,
                    text: "Ready to send",
                    externalID: "ext-ready"
                )
            )
            assertViewContextSave("Failed to save reply")
        }

        let result = await MainActor.run { container.fetchSoonestQueuedReplyRetryAt() }
        XCTAssertNil(result, "A head with nextRetryAt == nil should not produce a timer date")
    }

    func testFetchSoonestQueuedReplyRetryAtReturnsHeadNextRetryAt() async throws {
        let conversationID = UUID()
        let now = Date()
        let expectedRetryAt = now.addingTimeInterval(30)
        try await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = conversationID
            conv.createdAt = now
            conv.updatedAt = now
            let reply = try XCTUnwrap(
                container.insertOptimisticReply(
                    conversationID: conversationID,
                    text: "In backoff",
                    externalID: "ext-backoff"
                )
            )
            reply.nextRetryAt = expectedRetryAt
            assertViewContextSave("Failed to save reply")
        }

        let result = await MainActor.run { container.fetchSoonestQueuedReplyRetryAt() }
        let unwrapped = try XCTUnwrap(result, "Expected a non-nil retry date")
        XCTAssertEqual(
            unwrapped.timeIntervalSinceReferenceDate,
            expectedRetryAt.timeIntervalSinceReferenceDate,
            accuracy: 0.001
        )
    }

    func testFetchSoonestQueuedReplyRetryAtIgnoresBlockedSuccessors() async throws {
        // HOL: the head is in backoff at t+30; a successor has nextRetryAt = t+5.
        // The successor is HOL-blocked, so the timer should fire at t+30, not t+5.
        let conversationID = UUID()
        let now = Date()
        let headRetryAt = now.addingTimeInterval(30)
        let successorRetryAt = now.addingTimeInterval(5)
        try await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = conversationID
            conv.createdAt = now
            conv.updatedAt = now

            let head = try XCTUnwrap(
                container.insertOptimisticReply(
                    conversationID: conversationID,
                    text: "Head in backoff",
                    externalID: "ext-head"
                )
            )
            head.createdAt = now.addingTimeInterval(-10)
            head.nextRetryAt = headRetryAt

            let successor = try XCTUnwrap(
                container.insertOptimisticReply(
                    conversationID: conversationID,
                    text: "Blocked successor",
                    externalID: "ext-successor"
                )
            )
            successor.createdAt = now.addingTimeInterval(-5)
            successor.nextRetryAt = successorRetryAt

            assertViewContextSave("Failed to save replies")
        }

        let result = await MainActor.run { container.fetchSoonestQueuedReplyRetryAt() }
        let unwrapped = try XCTUnwrap(result, "Expected a non-nil retry date")
        XCTAssertEqual(
            unwrapped.timeIntervalSinceReferenceDate,
            headRetryAt.timeIntervalSinceReferenceDate,
            accuracy: 0.001,
            "Timer should fire at the head's nextRetryAt, not the blocked successor's earlier nextRetryAt"
        )
    }

    func testFetchSoonestQueuedReplyRetryAtReturnsSoonestAcrossConversations() async throws {
        let now = Date()
        let convA = UUID()
        let convB = UUID()
        let soonerRetryAt = now.addingTimeInterval(10)
        let laterRetryAt = now.addingTimeInterval(30)

        try await MainActor.run {
            for (convID, retryAt, externalID, text) in [
                (convA, soonerRetryAt, "ext-a", "Conv A"),
                (convB, laterRetryAt, "ext-b", "Conv B")
            ] {
                let conv = Conversation(context: container.viewContext)
                conv.id = convID
                conv.createdAt = now
                conv.updatedAt = now
                let reply = try XCTUnwrap(
                    container.insertOptimisticReply(
                        conversationID: convID,
                        text: text,
                        externalID: externalID
                    )
                )
                reply.nextRetryAt = retryAt
            }
            assertViewContextSave("Failed to save replies")
        }

        let result = await MainActor.run { container.fetchSoonestQueuedReplyRetryAt() }
        let unwrapped = try XCTUnwrap(result, "Expected a non-nil retry date")
        XCTAssertEqual(
            unwrapped.timeIntervalSinceReferenceDate,
            soonerRetryAt.timeIntervalSinceReferenceDate,
            accuracy: 0.001,
            "Should return the minimum nextRetryAt across conversation heads"
        )
    }
}
