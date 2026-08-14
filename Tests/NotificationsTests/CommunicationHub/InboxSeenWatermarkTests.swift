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

import Combine
import RoverFoundation
import XCTest

@testable import RoverNotifications

final class InboxSeenWatermarkTests: XCTestCase {
    private static let suiteName = "io.rover.test.inboxSeenWatermark"

    private var userDefaults: UserDefaults!
    private var container: InboxPersistentContainer!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() async throws {
        try await super.setUp()
        UserDefaults(suiteName: Self.suiteName)?.removePersistentDomain(forName: Self.suiteName)
        userDefaults = UserDefaults(suiteName: Self.suiteName)!
        container = InboxPersistentContainer(storage: .inMemory)
    }

    override func tearDown() async throws {
        cancellables.removeAll()
        container = nil
        userDefaults = nil
        UserDefaults(suiteName: Self.suiteName)?.removePersistentDomain(forName: Self.suiteName)
        try await super.tearDown()
    }

    private func makeWatermark() -> InboxSeenWatermark {
        InboxSeenWatermark(userDefaults: userDefaults, storageKey: "io.rover.notifications.inboxLastSeenAt")
    }

    /// Builds a watermark that already holds `existing`, standing in for a device that has visited the
    /// inbox before — the only way the watermark carries an observed item timestamp rather than a
    /// seeded device one.
    private func makeWatermark(alreadySeenUpTo existing: Date) -> InboxSeenWatermark {
        let persisted = PersistedValue<Date>(
            storageKey: "io.rover.notifications.inboxLastSeenAt",
            userDefaults: userDefaults
        )
        persisted.value = existing
        return makeWatermark()
    }

    // MARK: - Fresh install

    func testFreshInstallSeedsTheWatermarkWithNow() {
        let before = Date()
        let watermark = makeWatermark()
        let after = Date()

        XCTAssertGreaterThanOrEqual(watermark.lastSeenAt, before)
        XCTAssertLessThanOrEqual(watermark.lastSeenAt, after)
    }

    func testFreshInstallPersistsTheSeededWatermark() {
        let seeded = makeWatermark().lastSeenAt

        XCTAssertNotNil(
            userDefaults.object(forKey: "io.rover.notifications.inboxLastSeenAt"),
            "Seeding must actually write through to UserDefaults"
        )

        // The gap makes a silent re-seed detectable: the watermark is persisted at RFC3339
        // millisecond resolution, so a re-seeded value would land measurably later.
        Thread.sleep(forTimeInterval: 0.05)

        // A second instance reading the same defaults must find the seeded value rather than
        // re-seeding, otherwise the watermark would silently advance on every launch.
        let reloaded = makeWatermark()
        XCTAssertEqual(reloaded.lastSeenAt.timeIntervalSince1970, seeded.timeIntervalSince1970, accuracy: 0.002)
    }

    func testFreshInstallYieldsAZeroBadgeDespitePreexistingUnreadPosts() async throws {
        // Simulate an app updating into this build: history already synced, all of it unread.
        try await MainActor.run {
            for offset in 1...157 {
                let post = Post(context: container.viewContext)
                post.id = UUID()
                post.subject = "Historic post \(offset)"
                post.previewText = "Preview \(offset)"
                post.receivedAt = Date().addingTimeInterval(-TimeInterval(offset * 3600))
                post.url = URL(string: "https://example.com/\(offset)")!
                post.isRead = false
            }
            try container.viewContext.save()
        }

        let watermark = makeWatermark()
        let badgeCount = await MainActor.run {
            container.getBadgeCount(seenAfter: watermark.lastSeenAt)
        }

        XCTAssertEqual(badgeCount, 0, "A freshly seeded watermark must not badge historical posts")
    }

    // MARK: - markSeen

    func testMarkSeenAdvancesTheWatermarkToTheNewestReceivedAt() throws {
        let watermark = makeWatermark()
        let newest = watermark.lastSeenAt.addingTimeInterval(60)

        watermark.markSeen(upTo: newest)

        // The watermark takes the `receivedAt` verbatim — it is the mark, not a floor under some
        // device-clock reading that would drag it further forward.
        XCTAssertEqual(watermark.lastSeenAt.timeIntervalSince1970, newest.timeIntervalSince1970, accuracy: 0.002)
    }

    func testMarkSeenPersistsAcrossInstances() {
        let watermark = makeWatermark()
        let newest = watermark.lastSeenAt.addingTimeInterval(60)
        watermark.markSeen(upTo: newest)

        let reloaded = makeWatermark()
        XCTAssertEqual(reloaded.lastSeenAt.timeIntervalSince1970, newest.timeIntervalSince1970, accuracy: 0.002)
    }

    func testMarkSeenZeroesThePostsContribution() async throws {
        let watermark = makeWatermark()

        // A post that arrives after the watermark was seeded.
        let receivedAt = watermark.lastSeenAt.addingTimeInterval(60)
        try await MainActor.run {
            let post = Post(context: container.viewContext)
            post.id = UUID()
            post.subject = "Brand new"
            post.previewText = "Preview"
            post.receivedAt = receivedAt
            post.url = URL(string: "https://example.com/new")!
            post.isRead = false
            try container.viewContext.save()
        }

        let beforeVisit = await MainActor.run {
            container.getBadgeCount(seenAfter: watermark.lastSeenAt)
        }
        XCTAssertEqual(beforeVisit, 1)

        // Opening the inbox advances the watermark to the newest post — without the post ever
        // having been read.
        watermark.markSeen(upTo: receivedAt)

        let afterVisit = await MainActor.run {
            container.getBadgeCount(seenAfter: watermark.lastSeenAt)
        }
        XCTAssertEqual(afterVisit, 0)
    }

    // MARK: - Device-clock independence

    func testMarkSeenAdvancesToAReceivedAtAheadOfTheDeviceClock() {
        let watermark = makeWatermark()
        // Stands in for a stored `receivedAt` ahead of a lagging device clock.
        let aheadOfDeviceClock = Date().addingTimeInterval(600)

        watermark.markSeen(upTo: aheadOfDeviceClock)

        XCTAssertEqual(
            watermark.lastSeenAt.timeIntervalSince1970,
            aheadOfDeviceClock.timeIntervalSince1970,
            accuracy: 0.002
        )
    }

    func testMarkSeenIgnoresAReceivedAtOlderThanTheWatermark() {
        let watermark = makeWatermark()
        let seeded = watermark.lastSeenAt

        // An eviction, a reset, or a stale snapshot can make the newest post in the store older
        // than what the user has already seen. The monotonic clamp makes that a no-op.
        watermark.markSeen(upTo: seeded.addingTimeInterval(-600))

        XCTAssertEqual(watermark.lastSeenAt.timeIntervalSince1970, seeded.timeIntervalSince1970, accuracy: 0.002)
    }

    func testMarkSeenWithNoPostsLeavesTheWatermarkAndPublisherUntouched() {
        let watermark = makeWatermark()
        let seeded = watermark.lastSeenAt

        let recorded = Recorder()
        watermark.publisher
            .sink { recorded.append($0) }
            .store(in: &cancellables)

        // An empty inbox has nothing to absorb, so the watermark stays where the seed left it —
        // it must not fall forward onto the device clock.
        watermark.markSeen(upTo: nil)

        XCTAssertEqual(watermark.lastSeenAt.timeIntervalSince1970, seeded.timeIntervalSince1970, accuracy: 0.002)
        XCTAssertEqual(recorded.values.count, 1, "Only the replayed value — a no-op must not emit")

        let reloaded = makeWatermark()
        XCTAssertEqual(reloaded.lastSeenAt.timeIntervalSince1970, seeded.timeIntervalSince1970, accuracy: 0.002)
    }

    func testMarkSeenZeroesAPostStampedAheadOfTheDeviceClock() async throws {
        let watermark = makeWatermark()

        // A post whose `receivedAt` is ahead of this device's clock.
        let receivedAt = Date().addingTimeInterval(600)
        try await MainActor.run {
            let post = Post(context: container.viewContext)
            post.id = UUID()
            post.subject = "From the future"
            post.previewText = "Preview"
            post.receivedAt = receivedAt
            post.url = URL(string: "https://example.com/future")!
            post.isRead = false
            try container.viewContext.save()
        }

        let beforeVisit = await MainActor.run {
            container.getBadgeCount(seenAfter: watermark.lastSeenAt)
        }
        XCTAssertEqual(beforeVisit, 1, "The seeded, device-time watermark is behind the post")

        // Marking up to the newest stored `receivedAt` — what `MessagesView` passes — clears it,
        // where any device-clock-derived mark would have stayed behind it.
        watermark.markSeen(upTo: receivedAt)
        let afterVisit = await MainActor.run {
            container.getBadgeCount(seenAfter: watermark.lastSeenAt)
        }
        XCTAssertEqual(afterVisit, 0)
    }

    func testMarkSeenNeverRegressesAWatermarkAheadOfTheDeviceClock() {
        // An inbox visit on a device whose clock lags the stored timestamps leaves the watermark
        // ahead of device-now.
        let watermark = makeWatermark()
        let aheadOfDeviceClock = Date().addingTimeInterval(600)
        watermark.markSeen(upTo: aheadOfDeviceClock)

        // A later visit that finds only older posts — or none at all — must clamp rather than move
        // the watermark backwards and re-badge posts already seen.
        watermark.markSeen(upTo: Date())
        watermark.markSeen(upTo: nil)

        XCTAssertEqual(
            watermark.lastSeenAt.timeIntervalSince1970,
            aheadOfDeviceClock.timeIntervalSince1970,
            accuracy: 0.002
        )

        // The clamp must hold through persistence too, not just in the in-memory subject.
        let reloaded = makeWatermark()
        XCTAssertEqual(
            reloaded.lastSeenAt.timeIntervalSince1970,
            aheadOfDeviceClock.timeIntervalSince1970,
            accuracy: 0.002
        )
    }

    func testAPostStampedBetweenTheWatermarkAndTheDeviceClockStillBadges() async throws {
        let deviceNow = Date()

        // The user has visited the inbox before, so the watermark holds the newest `receivedAt`
        // they were shown — some way behind the device clock.
        let newestSeen = deviceNow.addingTimeInterval(-660)
        let watermark = makeWatermark(alreadySeenUpTo: newestSeen)

        // A post stamped after that instant but before device-now.
        let receivedAt = deviceNow.addingTimeInterval(-600)
        try await MainActor.run {
            let post = Post(context: container.viewContext)
            post.id = UUID()
            post.subject = "Inside the gap"
            post.previewText = "Preview"
            post.receivedAt = receivedAt
            post.url = URL(string: "https://example.com/gap")!
            post.isRead = false
            try container.viewContext.save()
        }

        let badgeCount = await MainActor.run {
            container.getBadgeCount(seenAfter: watermark.lastSeenAt)
        }
        XCTAssertEqual(badgeCount, 1, "A watermark written in device time would have suppressed this")

        // And the visit that follows records the observed timestamp rather than planting the
        // watermark at the device clock, so the *next* post inside that gap badges too.
        watermark.markSeen(upTo: receivedAt)
        XCTAssertLessThan(watermark.lastSeenAt, deviceNow)
    }

    // MARK: - Concurrency

    func testConcurrentMarkSeenLeavesNoTornStateAndNeverGoesBackwards() {
        let watermark = makeWatermark()
        let base = watermark.lastSeenAt

        let recorded = Recorder()
        watermark.publisher
            .sink { recorded.append($0) }
            .store(in: &cancellables)

        // Each iteration marks up to a distinct `receivedAt`, and they arrive in arbitrary order —
        // exactly the race the lock exists for.
        DispatchQueue.concurrentPerform(iterations: 500) { iteration in
            watermark.markSeen(upTo: base.addingTimeInterval(TimeInterval(iteration + 1)))
        }

        // The newest value offered must win regardless of the order the marks ran in: if the
        // comparison and the write were not one atomic step, a mark carrying an older instant could
        // land last and clobber it.
        let published = watermark.lastSeenAt
        XCTAssertEqual(
            published.timeIntervalSince1970,
            base.addingTimeInterval(500).timeIntervalSince1970,
            accuracy: 0.002,
            "The watermark must settle on the newest receivedAt offered"
        )

        // The persisted value and the published value must describe the same write, otherwise
        // `UserDefaults` would hold a different instant than the one subscribers last saw.
        let reloaded = makeWatermark()
        XCTAssertEqual(
            reloaded.lastSeenAt.timeIntervalSince1970,
            published.timeIntervalSince1970,
            accuracy: 0.002,
            "The persisted watermark must match the last published one"
        )

        let emissions = recorded.values
        for (earlier, later) in zip(emissions, emissions.dropFirst()) {
            XCTAssertLessThanOrEqual(earlier, later, "The watermark must never move backwards")
        }
    }

    /// Collects publisher emissions from whichever thread `markSeen` happened to run on.
    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [Date] = []

        func append(_ value: Date) {
            lock.withLock { storage.append(value) }
        }

        var values: [Date] {
            lock.withLock { storage }
        }
    }

    // MARK: - Observability

    func testPublisherReplaysTheCurrentValueOnSubscription() {
        let watermark = makeWatermark()
        let expectation = expectation(description: "publisher replays current value")

        watermark.publisher
            .sink { value in
                XCTAssertEqual(
                    value.timeIntervalSince1970,
                    watermark.lastSeenAt.timeIntervalSince1970,
                    accuracy: 0.002
                )
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1)
    }

    func testPublisherEmitsOnMarkSeen() {
        let watermark = makeWatermark()
        let expectation = expectation(description: "publisher emits on markSeen")
        expectation.expectedFulfillmentCount = 2

        watermark.publisher
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        watermark.markSeen(upTo: watermark.lastSeenAt.addingTimeInterval(60))

        wait(for: [expectation], timeout: 1)
    }

    // MARK: - Reset paths

    func testHubResetAdvancesTheWatermarkPastRefetchedHistory() async throws {
        let watermark = makeWatermark()
        let seeded = watermark.lastSeenAt
        Thread.sleep(forTimeInterval: 0.01)

        // Stand in for the 410 reset / `Rover.resetHub()` callers, both of which reset().
        watermark.reset()
        XCTAssertGreaterThan(watermark.lastSeenAt, seeded)

        // History refetched after the reset carries its original (older) receivedAt values.
        try await MainActor.run {
            for offset in 1...5 {
                let post = Post(context: container.viewContext)
                post.id = UUID()
                post.subject = "Refetched \(offset)"
                post.previewText = "Preview \(offset)"
                post.receivedAt = seeded.addingTimeInterval(-TimeInterval(offset))
                post.url = URL(string: "https://example.com/refetched/\(offset)")!
                post.isRead = false
            }
            try container.viewContext.save()
        }

        let badgeCount = await MainActor.run {
            container.getBadgeCount(seenAfter: watermark.lastSeenAt)
        }
        XCTAssertEqual(badgeCount, 0, "Refetched history must not re-badge after a reset")
    }

    func testHubResetDoesNotReBadgeRefetchedUnreadConversations() async throws {
        let watermark = makeWatermark()
        let seeded = watermark.lastSeenAt
        Thread.sleep(forTimeInterval: 0.01)
        watermark.reset()

        // Conversation history refetched after the reset carries its original (older) reply
        // timestamps. Unread state alone must no longer re-light the badge — conversations are
        // gated by the watermark exactly like posts.
        try await MainActor.run {
            let conversation = Conversation(context: container.viewContext)
            conversation.id = UUID()
            conversation.createdAt = seeded.addingTimeInterval(-120)
            conversation.updatedAt = seeded.addingTimeInterval(-60)
            conversation.subject = "Refetched conversation"
            conversation.lastReplyAt = seeded.addingTimeInterval(-60)
            conversation.lastIncomingReplyAt = seeded.addingTimeInterval(-60)
            conversation.lastReadAt = nil
            try container.viewContext.save()
        }

        let badgeCount = await MainActor.run {
            container.getBadgeCount(seenAfter: watermark.lastSeenAt)
        }
        XCTAssertEqual(badgeCount, 0, "Refetched unread conversations must not re-badge after a reset")
    }

    func testResetCanMoveAWatermarkBackToDeviceNow() {
        // An inbox visit on a lagging device clock leaves the watermark in the future; unlike
        // markSeen, a reset must be able to pull it back so a new identity badges normally.
        let watermark = makeWatermark()
        let aheadOfDeviceClock = Date().addingTimeInterval(600)
        watermark.markSeen(upTo: aheadOfDeviceClock)

        let beforeReset = Date()
        watermark.reset()
        let afterReset = Date()

        XCTAssertGreaterThanOrEqual(watermark.lastSeenAt, beforeReset)
        XCTAssertLessThanOrEqual(watermark.lastSeenAt, afterReset)
        XCTAssertLessThan(watermark.lastSeenAt, aheadOfDeviceClock)

        let reloaded = makeWatermark()
        XCTAssertEqual(
            reloaded.lastSeenAt.timeIntervalSince1970,
            watermark.lastSeenAt.timeIntervalSince1970,
            accuracy: 0.002
        )
    }
}
