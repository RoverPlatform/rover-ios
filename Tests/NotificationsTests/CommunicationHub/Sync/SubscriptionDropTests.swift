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

final class SubscriptionDropTests: InboxPersistentContainerTestCase {

    // MARK: - dropAllSubscriptions

    func testDropAllSubscriptionsRemovesEntities() async {
        await MainActor.run {
            let subscription = Subscription(context: container.viewContext)
            subscription.id = "sub-1"
            subscription.name = "Test Subscription"
            subscription.status = "published"
            subscription.optIn = true

            assertViewContextSave("seed subscription")
        }

        await MainActor.run { container.dropAllSubscriptions() }

        await MainActor.run {
            XCTAssertEqual(try? container.viewContext.count(for: Subscription.fetchRequest()), 0)
        }
    }

    func testDropAllSubscriptionsLeavesPostsIntact() async {
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

            assertViewContextSave("seed subscription + post")
        }

        await MainActor.run { container.dropAllSubscriptions() }

        await MainActor.run {
            XCTAssertEqual(
                try? container.viewContext.count(for: Post.fetchRequest()),
                1,
                "Posts should be untouched"
            )
        }
    }

    func testDropAllSubscriptionsLeavesConversationsIntact() async {
        await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = UUID()
            conv.createdAt = Date()
            conv.updatedAt = Date()

            let subscription = Subscription(context: container.viewContext)
            subscription.id = "sub-1"
            subscription.name = "Test Subscription"
            subscription.status = "published"
            subscription.optIn = true

            assertViewContextSave("seed conversation + subscription")
        }

        await MainActor.run { container.dropAllSubscriptions() }

        await MainActor.run {
            XCTAssertEqual(
                try? container.viewContext.count(for: Conversation.fetchRequest()),
                1,
                "Conversations should be untouched"
            )
            XCTAssertEqual(try? container.viewContext.count(for: Subscription.fetchRequest()), 0)
        }
    }

    // MARK: - Epoch Token

    func testDropAllSubscriptionsDoesNotBumpEpoch() async {
        let before = await MainActor.run { container.conversationStoreGeneration }
        await MainActor.run { container.dropAllSubscriptions() }
        let after = await MainActor.run { container.conversationStoreGeneration }
        XCTAssertEqual(after, before, "dropAllSubscriptions() must not bump the shared epoch on its own")
    }

    func testDropAllSubscriptionsIsIdempotent() async {
        await MainActor.run {
            container.dropAllSubscriptions()
            container.dropAllSubscriptions()
        }
        await MainActor.run {
            XCTAssertEqual(try? container.viewContext.count(for: Subscription.fetchRequest()), 0)
        }
    }
}
