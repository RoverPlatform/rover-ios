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

import XCTest

@testable import RoverNotifications

final class RoverBadgeCountTests: XCTestCase {
    private var container: InboxPersistentContainer!

    override func setUp() async throws {
        try await super.setUp()
        container = InboxPersistentContainer(storage: .inMemory)
    }

    override func tearDown() async throws {
        container = nil
        try await super.tearDown()
    }

    func testGetBadgeCountIncludesUnreadPostsAndConversations() async {
        await MainActor.run {
            createPost(isRead: false)
            createPost(isRead: true)
            createConversation(isRead: false)
            createConversation(isRead: true)

            do {
                try container.viewContext.save()
            } catch {
                XCTFail("Failed to save test entities: \(error)")
            }
        }

        let badgeCount = await MainActor.run { container.getBadgeCount() }
        XCTAssertEqual(badgeCount, 2)
    }

    func testGetBadgeCountIncludesUnreadConversationsWhenNoUnreadPosts() async {
        await MainActor.run {
            createPost(isRead: true)
            createConversation(isRead: false)
            createConversation(isRead: false)
            createConversation(isRead: true)

            do {
                try container.viewContext.save()
            } catch {
                XCTFail("Failed to save test entities: \(error)")
            }
        }

        let badgeCount = await MainActor.run { container.getBadgeCount() }
        XCTAssertEqual(badgeCount, 2)
    }

    @MainActor
    private func createPost(isRead: Bool) {
        let post = Post(context: container.viewContext)
        post.id = UUID()
        post.subject = "Post \(UUID().uuidString)"
        post.previewText = "Preview \(UUID().uuidString)"
        post.receivedAt = Date()
        post.url = URL(string: "https://example.com/\(UUID().uuidString)")!
        post.isRead = isRead
    }

    @MainActor
    private func createConversation(isRead: Bool) {
        let conversation = Conversation(context: container.viewContext)
        conversation.id = UUID()
        conversation.createdAt = Date()
        conversation.updatedAt = Date()
        conversation.subject = "Conversation \(UUID().uuidString)"
        let incomingReplyAt = Date()
        conversation.lastIncomingReplyAt = incomingReplyAt
        conversation.lastReadAt = isRead ? incomingReplyAt : nil
    }
}
