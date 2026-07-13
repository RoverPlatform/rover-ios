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
import XCTest

@testable import RoverNotifications

final class ConversationDetailOrchestrationTests: InboxPersistentContainerTestCase {
    actor SyncSpy: ConversationDetailSyncing {
        private var calls: [String] = []

        func flushQueuedReplies(conversationID: UUID?) async -> Bool {
            calls.append("flush")
            return true
        }

        func syncForward(conversationID: UUID) async {
            calls.append("syncForward")
        }

        func markConversationRead(
            conversationID: UUID,
            lastReadReplyID: UUID?
        ) async -> Result<MarkConversationReadResponse, Error> {
            calls.append("markRead")
            return .success(
                MarkConversationReadResponse(
                    conversationID: conversationID,
                    lastReadAt: Date(),
                    lastReadReplyID: lastReadReplyID ?? UUID()
                )
            )
        }

        func snapshotCalls() async -> [String] {
            calls
        }
    }

    func testOpenSequenceIsSyncOnlyFlushThenSyncForward() async {
        let conversationID = UUID()
        let replyID = UUID()
        let now = Date()

        await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = now
            conversation.updatedAt = now

            // A server-confirmed reply (externalID == nil) so fetchLatestConfirmedReply returns it.
            let reply = Reply(context: container.viewContext)
            reply.id = replyID
            reply.senderType = ReplySenderType.participant.rawValue
            reply.participantID = "p-1"
            reply.createdAt = now
            reply.syncState = ReplySyncState.confirmed.rawValue
            reply.externalID = nil
            reply.conversation = conversation
            attachTextBlock("Hello", to: reply)

            assertViewContextSave("Failed to seed conversation for open sequence test")
        }

        let sync = SyncSpy()
        let orchestrator = ConversationDetailOrchestrator(sync: sync, container: container)
        await orchestrator.onOpen(conversationID: conversationID)

        let calls = await sync.snapshotCalls()
        XCTAssertEqual(
            calls,
            ["flush", "syncForward"],
            "onOpen must be sync-only — mark-read fires from onReachedBottom, not onOpen"
        )
    }

    func testPollSequenceFlushesQueueBeforeSyncForward() async {
        let sync = SyncSpy()
        let orchestrator = ConversationDetailOrchestrator(sync: sync, container: container)

        // No replies seeded — markConversationAsRead exits early, so no markRead call.
        await orchestrator.onPoll(conversationID: UUID())

        let calls = await sync.snapshotCalls()
        XCTAssertEqual(calls, ["flush", "syncForward"])
    }

    func testPollSequenceDoesNotMarkReadEvenWhenRepliesExist() async {
        let conversationID = UUID()
        let replyID = UUID()
        let now = Date()

        await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = now
            conversation.updatedAt = now

            let reply = Reply(context: container.viewContext)
            reply.id = replyID
            reply.senderType = ReplySenderType.participant.rawValue
            reply.participantID = "p-1"
            reply.createdAt = now
            reply.syncState = ReplySyncState.confirmed.rawValue
            reply.externalID = nil
            reply.conversation = conversation
            attachTextBlock("Hello", to: reply)

            assertViewContextSave("Failed to seed conversation for poll mark-read test")
        }

        let sync = SyncSpy()
        let orchestrator = ConversationDetailOrchestrator(sync: sync, container: container)
        await orchestrator.onPoll(conversationID: conversationID)

        let calls = await sync.snapshotCalls()
        XCTAssertEqual(
            calls,
            ["flush", "syncForward"],
            "Polling alone must not mark conversations as read — mark-read only fires when user reaches bottom"
        )
    }

    func testOnReachedBottomMarksReadWhenConfirmedReplyExists() async {
        let conversationID = UUID()
        let replyID = UUID()
        let now = Date()

        await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = now
            conversation.updatedAt = now

            let reply = Reply(context: container.viewContext)
            reply.id = replyID
            reply.senderType = ReplySenderType.participant.rawValue
            reply.participantID = "p-1"
            reply.createdAt = now
            reply.syncState = ReplySyncState.confirmed.rawValue
            reply.externalID = nil
            reply.conversation = conversation
            attachTextBlock("Hello", to: reply)

            assertViewContextSave("Failed to seed conversation for onReachedBottom test")
        }

        let sync = SyncSpy()
        let orchestrator = ConversationDetailOrchestrator(sync: sync, container: container)
        await orchestrator.onReachedBottom(conversationID: conversationID)

        let calls = await sync.snapshotCalls()
        XCTAssertEqual(calls, ["markRead"], "onReachedBottom must call markRead when a confirmed reply exists")
    }

    func testOnReachedBottomSkipsServerMarkReadWhenOnlyQueuedRepliesExist() async {
        let conversationID = UUID()
        let now = Date()

        await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = now
            conversation.updatedAt = now

            let reply = Reply(context: container.viewContext)
            reply.id = UUID()
            reply.senderType = ReplySenderType.fan.rawValue
            reply.participantID = nil
            reply.createdAt = now
            reply.syncState = ReplySyncState.queued.rawValue
            reply.externalID = "ext-queued"
            reply.conversation = conversation
            attachTextBlock("Queued", to: reply)

            assertViewContextSave("Failed to seed queued reply for onReachedBottom test")
        }

        let sync = SyncSpy()
        let orchestrator = ConversationDetailOrchestrator(sync: sync, container: container)
        await orchestrator.onReachedBottom(conversationID: conversationID)

        let calls = await sync.snapshotCalls()
        XCTAssertEqual(calls, [], "onReachedBottom must not call server markRead when only queued replies exist")
    }

    func testOnReachedBottomIsNoOpWhenNoRepliesExist() async {
        let conversationID = UUID()
        let now = Date()

        await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = now
            conversation.updatedAt = now
            assertViewContextSave("Failed to seed conversation for onReachedBottom no-op test")
        }

        let sync = SyncSpy()
        let orchestrator = ConversationDetailOrchestrator(sync: sync, container: container)
        await orchestrator.onReachedBottom(conversationID: conversationID)

        let calls = await sync.snapshotCalls()
        XCTAssertEqual(calls, [], "onReachedBottom must be a no-op when the conversation has no replies")
    }

    func testOpenThenReachedBottomProducesExactlyOneMarkRead() async {
        let conversationID = UUID()
        let replyID = UUID()
        let now = Date()

        await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = now
            conversation.updatedAt = now

            let reply = Reply(context: container.viewContext)
            reply.id = replyID
            reply.senderType = ReplySenderType.participant.rawValue
            reply.participantID = "p-1"
            reply.createdAt = now
            reply.syncState = ReplySyncState.confirmed.rawValue
            reply.externalID = nil
            reply.conversation = conversation
            attachTextBlock("Hello", to: reply)

            assertViewContextSave("Failed to seed conversation for two-phase test")
        }

        let sync = SyncSpy()
        let orchestrator = ConversationDetailOrchestrator(sync: sync, container: container)

        await orchestrator.onOpen(conversationID: conversationID)
        let callsAfterOpen = await sync.snapshotCalls()
        XCTAssertEqual(callsAfterOpen, ["flush", "syncForward"], "onOpen must not call markRead")

        await orchestrator.onReachedBottom(conversationID: conversationID)
        let callsAfterReached = await sync.snapshotCalls()
        XCTAssertEqual(
            callsAfterReached,
            ["flush", "syncForward", "markRead"],
            "markRead must fire exactly once, from onReachedBottom"
        )
    }

    func testReachedBottomAgainWithSameReplyStillCallsMarkRead() async {
        let conversationID = UUID()
        let replyID = UUID()
        let now = Date()

        await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = now
            conversation.updatedAt = now

            let reply = Reply(context: container.viewContext)
            reply.id = replyID
            reply.senderType = ReplySenderType.participant.rawValue
            reply.participantID = "p-1"
            reply.createdAt = now
            reply.syncState = ReplySyncState.confirmed.rawValue
            reply.externalID = nil
            reply.conversation = conversation
            attachTextBlock("Hello", to: reply)

            assertViewContextSave("Failed to seed conversation for idempotency test")
        }

        let sync = SyncSpy()
        let orchestrator = ConversationDetailOrchestrator(sync: sync, container: container)

        await orchestrator.onReachedBottom(conversationID: conversationID)
        await orchestrator.onReachedBottom(conversationID: conversationID)

        let calls = await sync.snapshotCalls()
        XCTAssertEqual(
            calls,
            ["markRead", "markRead"],
            "onReachedBottom is idempotent — calling twice sends markRead twice (server call is idempotent)"
        )
    }

    func testSyncConversationSkipsSyncForwardAfterFlushTriggeredDrop() async {
        let conversationID = UUID()

        // A SyncSpy that drops the store when flush is called.
        actor DroppingFlushSpy: ConversationDetailSyncing {
            var syncForwardCalled = false
            let container: InboxPersistentContainer

            init(container: InboxPersistentContainer) {
                self.container = container
            }

            func flushQueuedReplies(conversationID: UUID?) async -> Bool {
                // Simulate a 410 drop during flush. Bumping the epoch is what
                // `syncConversation`'s generation guard actually detects; the drop itself is
                // simulated alongside it for realism (see
                // `InboxPersistentContainer.bumpConversationStoreGeneration()`).
                await MainActor.run {
                    container.bumpConversationStoreGeneration()
                    container.dropAllConversations()
                }
                return false
            }

            func syncForward(conversationID: UUID) async {
                syncForwardCalled = true
            }

            func markConversationRead(
                conversationID: UUID,
                lastReadReplyID: UUID?
            ) async -> Result<MarkConversationReadResponse, Error> {
                .failure(URLError(.cancelled))
            }
        }

        let spy = DroppingFlushSpy(container: container)
        let orchestrator = ConversationDetailOrchestrator(sync: spy, container: container)
        await orchestrator.onOpen(conversationID: conversationID)

        let called = await spy.syncForwardCalled
        XCTAssertFalse(called, "syncForward must not be called after a flush-triggered drop")
    }
}
