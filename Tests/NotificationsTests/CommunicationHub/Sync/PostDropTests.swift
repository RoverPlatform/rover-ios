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

final class PostDropTests: InboxPersistentContainerTestCase {

    // MARK: - dropAllPosts

    func testDropAllPostsRemovesEntities() async {
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

        await MainActor.run { container.dropAllPosts() }

        await MainActor.run {
            XCTAssertEqual(try? container.viewContext.count(for: Post.fetchRequest()), 0)
            let req = SyncStatus.fetchRequest()
            req.predicate = NSPredicate(format: "roverEntity == %@", "posts")
            XCTAssertEqual(try? container.viewContext.count(for: req), 0, "Posts sync status should be gone")
        }
    }

    func testDropAllPostsLeavesSubscriptionsIntact() async {
        await MainActor.run {
            let subscription = Subscription(context: container.viewContext)
            subscription.id = "sub-1"
            subscription.name = "Test Subscription"
            subscription.status = "published"
            subscription.optIn = true

            let post = Post(context: container.viewContext)
            post.id = UUID()
            post.receivedAt = Date()
            post.isRead = false
            post.subject = "Test Post"
            post.previewText = "Test preview"
            post.url = URL(string: "https://example.com/post")!
            post.subscription = subscription

            assertViewContextSave("seed posts + subscription")
        }

        await MainActor.run { container.dropAllPosts() }

        await MainActor.run {
            XCTAssertEqual(
                try? container.viewContext.count(for: Subscription.fetchRequest()),
                1,
                "Subscriptions should be untouched"
            )
        }
    }

    func testDropAllPostsLeavesConversationsIntact() async {
        await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = UUID()
            conv.createdAt = Date()
            conv.updatedAt = Date()

            let post = Post(context: container.viewContext)
            post.id = UUID()
            post.receivedAt = Date()
            post.isRead = false
            post.subject = "Test Post"
            post.previewText = "Test preview"
            post.url = URL(string: "https://example.com/post")!

            assertViewContextSave("seed post + conversation")
        }

        await MainActor.run { container.dropAllPosts() }

        await MainActor.run {
            XCTAssertEqual(
                try? container.viewContext.count(for: Conversation.fetchRequest()),
                1,
                "Conversations should be untouched"
            )
            XCTAssertEqual(try? container.viewContext.count(for: Post.fetchRequest()), 0)
        }
    }

    // MARK: - Epoch Token

    func testDropAllPostsDoesNotBumpEpoch() async {
        let before = await MainActor.run { container.conversationStoreGeneration }
        await MainActor.run { container.dropAllPosts() }
        let after = await MainActor.run { container.conversationStoreGeneration }
        XCTAssertEqual(after, before, "dropAllPosts() must not bump the shared epoch on its own")
    }

    func testDropAllPostsIsIdempotent() async {
        await MainActor.run {
            container.dropAllPosts()
            container.dropAllPosts()
        }
        await MainActor.run {
            XCTAssertEqual(try? container.viewContext.count(for: Post.fetchRequest()), 0)
        }
    }
}
