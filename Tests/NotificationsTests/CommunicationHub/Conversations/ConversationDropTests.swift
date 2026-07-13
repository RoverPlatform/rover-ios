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

final class ConversationDropTests: InboxPersistentContainerTestCase {

    // MARK: - dropAllConversations

    func testDropAllConversationsRemovesEntities() async {
        let convID = UUID()
        await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = convID
            conv.createdAt = Date()
            conv.updatedAt = Date()

            let reply = Reply(context: container.viewContext)
            reply.id = UUID()
            reply.createdAt = Date()
            reply.senderType = "participant"
            reply.participantID = "p1"
            reply.syncState = "confirmed"
            reply.conversation = conv

            let block = ReplyContentBlock(context: container.viewContext)
            block.type = "text"
            block.text = "hello"
            block.sortOrder = 0
            block.reply = reply

            let participant = Participant(context: container.viewContext)
            participant.id = "p1"
            participant.name = "Alice"
            participant.updatedAt = Date()

            let convStatus = SyncStatus(context: container.viewContext)
            convStatus.roverEntity = "conversations"
            convStatus.cursor = "fwd-cursor"

            let replyStatus = SyncStatus(context: container.viewContext)
            replyStatus.roverEntity = "replies:\(convID.uuidString)"
            replyStatus.cursor = "reply-cursor"

            assertViewContextSave("seed")
        }

        await MainActor.run { container.dropAllConversations() }

        await MainActor.run {
            XCTAssertEqual(try? container.viewContext.count(for: Conversation.fetchRequest()), 0)
            XCTAssertEqual(try? container.viewContext.count(for: Reply.fetchRequest()), 0)
            XCTAssertEqual(try? container.viewContext.count(for: ReplyContentBlock.fetchRequest()), 0)
            XCTAssertEqual(try? container.viewContext.count(for: Participant.fetchRequest()), 0)
            let statusReq = SyncStatus.fetchRequest()
            statusReq.predicate = NSPredicate(
                format: "roverEntity == %@ OR roverEntity BEGINSWITH %@",
                "conversations",
                "replies:"
            )
            XCTAssertEqual(
                try? container.viewContext.count(for: statusReq),
                0,
                "Conversation and reply sync status records should be gone"
            )
        }
    }

    func testDropAllConversationsLeavesPostsUntouched() async {
        await MainActor.run {
            let post = Post(context: container.viewContext)
            post.id = UUID()
            post.receivedAt = Date()
            post.isRead = false
            post.subject = "Test Post"
            post.previewText = "Test preview"
            post.url = URL(string: "https://example.com/post")!

            let postStatus = SyncStatus(context: container.viewContext)
            postStatus.roverEntity = "posts"
            postStatus.cursor = "posts-cursor"

            assertViewContextSave("seed posts")
        }

        await MainActor.run { container.dropAllConversations() }

        await MainActor.run {
            XCTAssertEqual(try? container.viewContext.count(for: Post.fetchRequest()), 1)
            let req = SyncStatus.fetchRequest()
            req.predicate = NSPredicate(format: "roverEntity == %@", "posts")
            XCTAssertEqual(try? container.viewContext.count(for: req), 1, "Posts sync status should be untouched")
        }
    }

    func testDropAllConversationsIsIdempotent() async {
        await MainActor.run {
            container.dropAllConversations()
            container.dropAllConversations()
        }
        await MainActor.run {
            XCTAssertEqual(try? container.viewContext.count(for: Conversation.fetchRequest()), 0)
        }
    }

    // MARK: - Epoch Token

    /// `dropAllConversations()` does not bump the epoch itself. The bump happens first, via
    /// `bumpConversationStoreGeneration()`, called by `HubSyncCoordinator`'s reset task before
    /// cancellation and before any domain is dropped ("epoch-first invalidation").
    func testDropAllConversationsDoesNotBumpEpoch() async {
        let before = await MainActor.run { container.conversationStoreGeneration }
        await MainActor.run { container.dropAllConversations() }
        let after = await MainActor.run { container.conversationStoreGeneration }
        XCTAssertEqual(after, before, "dropAllConversations() must not bump the shared epoch on its own")
    }

    func testBumpConversationStoreGenerationIncrementsEpoch() async {
        let before = await MainActor.run { container.conversationStoreGeneration }
        await MainActor.run { container.bumpConversationStoreGeneration() }
        let after = await MainActor.run { container.conversationStoreGeneration }
        XCTAssertEqual(after, before + 1)
    }

}
