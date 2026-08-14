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

@testable import RoverData
@testable import RoverNotifications

/// Covers `InboxPersistentContainer.getBadgeCount(seenAfter:)`: posts and conversations are
/// counted by the same rule — unread *and* activity after the inbox seen watermark.
final class RoverBadgeCountTests: XCTestCase {
    private var container: InboxPersistentContainer!

    /// Fixed reference watermark. Items are seeded relative to it so no test depends on wall clock.
    private let watermark = Date(timeIntervalSince1970: 1_700_000_000)

    private var beforeWatermark: Date { watermark.addingTimeInterval(-3600) }
    private var afterWatermark: Date { watermark.addingTimeInterval(3600) }

    override func setUp() async throws {
        try await super.setUp()
        container = InboxPersistentContainer(storage: .inMemory)
    }

    override func tearDown() async throws {
        container = nil
        try await super.tearDown()
    }

    // MARK: - Posts counted by watermark and read state

    func testPostsReceivedBeforeWatermarkAreNotCountedRegardlessOfReadState() async {
        await seed {
            createPost(receivedAt: beforeWatermark, isRead: false)
            createPost(receivedAt: beforeWatermark, isRead: true)
        }

        let badgeCount = await badgeCount()
        XCTAssertEqual(badgeCount, 0, "Posts predating the watermark must not badge, even when unread")
    }

    func testUnreadPostsReceivedAfterWatermarkAreCounted() async {
        await seed {
            createPost(receivedAt: afterWatermark, isRead: false)
            createPost(receivedAt: afterWatermark, isRead: false)
        }

        let badgeCount = await badgeCount()
        XCTAssertEqual(badgeCount, 2, "Unread posts delivered after the watermark must badge")
    }

    func testReadPostsReceivedAfterWatermarkAreNotCounted() async {
        await seed {
            createPost(receivedAt: afterWatermark, isRead: true)
        }

        let badgeCount = await badgeCount()
        XCTAssertEqual(
            badgeCount,
            0,
            "A post read from the detail screen — a push tap or deep link never shows the inbox — must stop badging"
        )
    }

    /// End-to-end deep-link scenario: the badge drops by exactly the one post the user opened, and
    /// the other keeps badging because nothing moved the watermark.
    func testReadingOneOfTwoNewPostsLeavesTheOtherBadging() async throws {
        let openedID = try await MainActor.run { () throws -> UUID in
            let opened = createPost(receivedAt: afterWatermark, isRead: false)
            createPost(receivedAt: afterWatermark, isRead: false)
            try container.viewContext.save()
            return try XCTUnwrap(opened.id)
        }

        let beforeReading = await badgeCount()
        XCTAssertEqual(beforeReading, 2)

        // Stands in for `PostDetailView.markPostAsRead()`, which both of its load paths call.
        try await MainActor.run {
            let opened = try XCTUnwrap(container.fetchPostByID(uuid: openedID))
            container.markPostAsRead(opened)
        }

        let afterReading = await badgeCount()
        XCTAssertEqual(afterReading, 1, "Reading the opened post decrements the badge by one, and only one")
    }

    func testPostReceivedExactlyAtWatermarkIsNotCounted() async {
        await seed {
            createPost(receivedAt: watermark, isRead: false)
        }

        let badgeCount = await badgeCount()
        XCTAssertEqual(badgeCount, 0, "The watermark comparison is strictly greater-than")
    }

    func testOnlyPostsAfterWatermarkAreCountedInAMixedHistory() async {
        await seed {
            createPost(receivedAt: beforeWatermark, isRead: false)
            createPost(receivedAt: beforeWatermark, isRead: false)
            createPost(receivedAt: beforeWatermark, isRead: false)
            createPost(receivedAt: afterWatermark, isRead: false)
        }

        let badgeCount = await badgeCount()
        XCTAssertEqual(badgeCount, 1)
    }

    // MARK: - Conversations counted by watermark and read state

    func testUnreadConversationsWithActivityAfterWatermarkAreCounted() async {
        await seed {
            createConversation(isRead: false, activityAt: afterWatermark)
            createConversation(isRead: false, activityAt: afterWatermark)
            createConversation(isRead: true, activityAt: afterWatermark)
        }

        let badgeCount = await badgeCount()
        XCTAssertEqual(badgeCount, 2, "Read conversations must not badge, even past the watermark")
    }

    func testUnreadConversationsWithActivityBeforeWatermarkAreNotCounted() async {
        await seed {
            createConversation(isRead: false, activityAt: beforeWatermark)
        }

        let badgeCount = await badgeCount()
        XCTAssertEqual(
            badgeCount,
            0,
            "Conversations badge by the same watermark rule as posts — a visit to the inbox must clear them"
        )
    }

    func testConversationWithOnlyAnIncomingReplyTimestampStillBadgesPastTheWatermark() async {
        // A payload merge can leave the newest activity recorded only on `lastIncomingReplyAt`,
        // with `lastReplyAt` absent; the direction-specific timestamp is sufficient to badge.
        await seed {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = UUID()
            conversation.createdAt = afterWatermark
            conversation.updatedAt = afterWatermark
            conversation.subject = "Incoming-only conversation"
            conversation.lastIncomingReplyAt = afterWatermark
            conversation.lastReplyAt = nil
            conversation.lastReadAt = nil
        }

        let badgeCount = await badgeCount()
        XCTAssertEqual(badgeCount, 1)
    }

    func testOptimisticOutgoingReplyDoesNotBadgeOrAdvanceSeenWatermark() async {
        let suiteName = "io.rover.test.badge.optimistic.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let seenWatermark = InboxSeenWatermark(
            userDefaults: userDefaults,
            storageKey: "\(suiteName).watermark"
        )
        let initialWatermark = seenWatermark.lastSeenAt
        let conversationID = UUID()
        let previousIncomingAt = initialWatermark.addingTimeInterval(-60)

        await seed {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = conversationID
            conversation.createdAt = previousIncomingAt
            conversation.updatedAt = previousIncomingAt
            conversation.lastReplyAt = previousIncomingAt
            conversation.lastIncomingReplyAt = previousIncomingAt
            conversation.lastReadAt = nil
        }
        let countBeforeSending = await badgeCount(seenAfter: initialWatermark)
        XCTAssertEqual(countBeforeSending, 0)

        let outgoingAt = initialWatermark.addingTimeInterval(3600)
        await seed {
            XCTAssertNotNil(
                container.insertOptimisticReply(
                    conversationID: conversationID,
                    text: "Optimistic outbound reply",
                    externalID: UUID().uuidString
                )
            )
            container.stageConversationPreviewOptimistically(
                conversationID: conversationID,
                text: "Optimistic outbound reply",
                at: outgoingAt
            )
        }

        let countAfterSending = await badgeCount(seenAfter: initialWatermark)
        XCTAssertEqual(countAfterSending, 0)
        let badgeActivityAt = await MainActor.run {
            container.fetchConversation(id: conversationID)?.badgeActivityAt
        }
        seenWatermark.markSeen(upTo: badgeActivityAt)
        XCTAssertEqual(
            seenWatermark.lastSeenAt,
            initialWatermark,
            "An optimistic outbound reply must not advance the inbox seen watermark"
        )

        let incomingAt = outgoingAt.addingTimeInterval(60)
        await seed {
            let conversation = container.fetchConversation(id: conversationID)
            conversation?.lastReplyAt = incomingAt
            conversation?.lastIncomingReplyAt = incomingAt
        }
        let countAfterIncomingReply = await badgeCount(seenAfter: initialWatermark)
        XCTAssertEqual(
            countAfterIncomingReply,
            1,
            "A later incoming unread reply must still contribute to the badge"
        )
    }

    // MARK: - Mixed sum

    func testBadgeCountSumsNewPostsAndNewConversations() async {
        await seed {
            createPost(receivedAt: afterWatermark, isRead: false)
            createPost(receivedAt: afterWatermark, isRead: false)
            createPost(receivedAt: afterWatermark, isRead: true)
            createPost(receivedAt: beforeWatermark, isRead: false)
            createConversation(isRead: false, activityAt: afterWatermark)
            createConversation(isRead: false, activityAt: beforeWatermark)
            createConversation(isRead: true, activityAt: afterWatermark)
        }

        let badgeCount = await badgeCount()
        XCTAssertEqual(badgeCount, 3, "2 unread new posts + 1 unread new conversation")
    }

    func testEmptyStoreCountsZero() async {
        let badgeCount = await badgeCount()
        XCTAssertEqual(badgeCount, 0)
    }

    // MARK: - Inbox configuration

    @MainActor
    func testEnabledInboxPublishesBadgeForUnseenItem() async {
        let dependencies = makeBadgeDependencies(isInboxEnabled: true)
        let receivedAt = dependencies.seenWatermark.lastSeenAt.addingTimeInterval(3600)

        await seed {
            createPost(receivedAt: receivedAt, isRead: false)
        }

        let badge = RoverBadge(
            persistentContainer: container,
            seenWatermark: dependencies.seenWatermark,
            configManager: dependencies.configManager,
            updateAppBadge: false
        )

        let published = await waitUntil { badge.newBadge == "1" }
        XCTAssertTrue(published, "An enabled inbox must publish its unseen-item badge")
    }

    @MainActor
    func testInboxConfigChangesSuppressAndRestoreBadgeWithoutAdvancingWatermark() async {
        let dependencies = makeBadgeDependencies(isInboxEnabled: false)
        let initialWatermark = dependencies.seenWatermark.lastSeenAt

        await seed {
            createPost(receivedAt: initialWatermark.addingTimeInterval(3600), isRead: false)
        }

        let badge = RoverBadge(
            persistentContainer: container,
            seenWatermark: dependencies.seenWatermark,
            configManager: dependencies.configManager,
            updateAppBadge: false
        )
        XCTAssertNil(badge.newBadge, "A disabled inbox must suppress stored unseen items")

        dependencies.configManager.updateFromBackend(
            RoverConfig(hub: RoverConfig.Hub(isInboxEnabled: true))
        )
        let restored = await waitUntil { badge.newBadge == "1" }
        XCTAssertTrue(restored, "Re-enabling the inbox must restore the stored unseen backlog")

        dependencies.configManager.updateFromBackend(
            RoverConfig(hub: RoverConfig.Hub(isInboxEnabled: false))
        )
        let cleared = await waitUntil { badge.newBadge == nil }
        XCTAssertTrue(cleared, "Disabling the inbox must immediately clear a published badge")
        XCTAssertEqual(
            dependencies.seenWatermark.lastSeenAt,
            initialWatermark,
            "Disabling the inbox must not absorb unseen items into the watermark"
        )

        dependencies.configManager.updateFromBackend(
            RoverConfig(hub: RoverConfig.Hub(isInboxEnabled: true))
        )
        let restoredAgain = await waitUntil { badge.newBadge == "1" }
        XCTAssertTrue(restoredAgain, "The unchanged watermark must allow the backlog to badge again")
    }

    // MARK: - Display cap

    func testBadgeTextIsNilForZeroOrNegativeCounts() {
        XCTAssertNil(RoverBadge.badgeText(for: 0))
        XCTAssertNil(RoverBadge.badgeText(for: -1))
    }

    func testBadgeTextIsTheNumberUpToNine() {
        XCTAssertEqual(RoverBadge.badgeText(for: 1), "1")
        XCTAssertEqual(RoverBadge.badgeText(for: 8), "8")
        XCTAssertEqual(RoverBadge.badgeText(for: 9), "9")
    }

    func testBadgeTextIsNinePlusAtTenAndBeyond() {
        XCTAssertEqual(RoverBadge.badgeText(for: 10), "9+")
        XCTAssertEqual(RoverBadge.badgeText(for: 157), "9+")
    }

    func testAppBadgeCountIsClampedToNine() {
        XCTAssertEqual(RoverBadge.appBadgeCount(for: 0), 0)
        XCTAssertEqual(RoverBadge.appBadgeCount(for: 5), 5)
        XCTAssertEqual(RoverBadge.appBadgeCount(for: 9), 9)
        XCTAssertEqual(RoverBadge.appBadgeCount(for: 10), 9)
        XCTAssertEqual(RoverBadge.appBadgeCount(for: 157), 9)
    }

    func testAppBadgeCountNeverGoesNegative() {
        XCTAssertEqual(RoverBadge.appBadgeCount(for: -3), 0)
    }

    func testTenNewPostsRenderAsNinePlus() async {
        await seed {
            for offset in 1...10 {
                createPost(receivedAt: watermark.addingTimeInterval(TimeInterval(offset)), isRead: false)
            }
        }

        let badgeCount = await badgeCount()
        XCTAssertEqual(badgeCount, 10)
        XCTAssertEqual(RoverBadge.badgeText(for: badgeCount), "9+")
    }

    func testNineNewPostsRenderAsNine() async {
        await seed {
            for offset in 1...9 {
                createPost(receivedAt: watermark.addingTimeInterval(TimeInterval(offset)), isRead: false)
            }
        }

        let badgeCount = await badgeCount()
        XCTAssertEqual(badgeCount, 9)
        XCTAssertEqual(RoverBadge.badgeText(for: badgeCount), "9")
    }

    // MARK: - Helpers

    private func badgeCount() async -> Int {
        await badgeCount(seenAfter: watermark)
    }

    private func badgeCount(seenAfter: Date) async -> Int {
        await MainActor.run { container.getBadgeCount(seenAfter: seenAfter) }
    }

    @MainActor
    private func makeBadgeDependencies(
        isInboxEnabled: Bool
    ) -> (
        configManager: ConfigManager, seenWatermark: InboxSeenWatermark
    ) {
        let suiteName = "io.rover.test.badge.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)

        let configManager = ConfigManager(userDefaults: userDefaults)
        configManager.updateFromBackend(
            RoverConfig(hub: RoverConfig.Hub(isInboxEnabled: isInboxEnabled))
        )
        let seenWatermark = InboxSeenWatermark(
            userDefaults: userDefaults,
            storageKey: "\(suiteName).watermark"
        )
        return (configManager, seenWatermark)
    }

    /// Runs `body` on the main actor and saves the context.
    private func seed(_ body: @MainActor () -> Void) async {
        await MainActor.run {
            body()
            do {
                try container.viewContext.save()
            } catch {
                XCTFail("Failed to save test entities: \(error)")
            }
        }
    }

    @MainActor
    @discardableResult
    private func createPost(receivedAt: Date, isRead: Bool) -> Post {
        let post = Post(context: container.viewContext)
        post.id = UUID()
        post.subject = "Post \(UUID().uuidString)"
        post.previewText = "Preview \(UUID().uuidString)"
        post.receivedAt = receivedAt
        post.url = URL(string: "https://example.com/\(UUID().uuidString)")!
        post.isRead = isRead
        return post
    }

    @MainActor
    private func createConversation(isRead: Bool, activityAt: Date) {
        let conversation = Conversation(context: container.viewContext)
        conversation.id = UUID()
        conversation.createdAt = activityAt
        conversation.updatedAt = activityAt
        conversation.subject = "Conversation \(UUID().uuidString)"
        conversation.lastReplyAt = activityAt
        conversation.lastIncomingReplyAt = activityAt
        conversation.lastReadAt = isRead ? activityAt : nil
    }
}
