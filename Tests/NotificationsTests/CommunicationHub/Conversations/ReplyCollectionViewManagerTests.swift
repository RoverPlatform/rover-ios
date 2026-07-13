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

/// Tests for `ReplyCollectionViewManager` — specifically the reply-counting logic in
/// `applyForwardSnapshot` and the scroll-anchor delegation in `applyPrependSnapshot`.
@MainActor
final class ReplyCollectionViewManagerTests: XCTestCase {

    // MARK: - Helpers

    private let base = Date(timeIntervalSince1970: 1_000_000)

    private func snap(
        id: UUID = UUID(),
        offset: TimeInterval = 0,
        senderType: ReplySenderType = .participant
    ) -> ReplySnapshot {
        ReplySnapshot(
            id: id,
            createdAt: base.addingTimeInterval(offset),
            senderType: senderType,
            participantID: "p1"
        )
    }

    private func group(replies: [ReplySnapshot]) -> MessageGroup {
        precondition(!replies.isEmpty, "group() requires at least one reply")
        return MessageGroup(
            id: replies[0].id,
            senderType: replies[0].senderType,
            participantID: replies[0].participantID,
            replies: replies,
            timestamp: replies.last!.createdAt  // mirrors MessageGrouper.makeGroup(); safe: precondition above
        )
    }

    // MARK: - injectSeparators

    func testInjectSeparatorsReturnsEmptyForNoGroups() {
        XCTAssertTrue(ReplyCollectionViewManager.injectSeparators([]).isEmpty)
    }

    func testInjectSeparatorsAddsSeparatorBeforeFirstGroup() {
        let reply = snap(offset: 0)
        let items = ReplyCollectionViewManager.injectSeparators([group(replies: [reply])])

        XCTAssertEqual(items.count, 2)
        guard case .separator(let date) = items[0] else {
            return XCTFail("Expected separator at index 0")
        }
        XCTAssertEqual(date, reply.createdAt)
        guard case .group(let id) = items[1] else {
            return XCTFail("Expected group at index 1")
        }
        XCTAssertEqual(id, reply.id)
    }

    func testInjectSeparatorsKeepsSameDayGroupsUnderOneSeparator() {
        let firstReply = snap(offset: 0)
        let secondReply = snap(offset: 3_600, senderType: .fan)
        let items = ReplyCollectionViewManager.injectSeparators([
            group(replies: [firstReply]),
            group(replies: [secondReply])
        ])

        XCTAssertEqual(items.count, 3)
        guard case .separator = items[0] else {
            return XCTFail("Expected one separator before same-day groups")
        }
        guard case .group(let firstID) = items[1] else {
            return XCTFail("Expected first group at index 1")
        }
        guard case .group(let secondID) = items[2] else {
            return XCTFail("Expected second group at index 2")
        }
        XCTAssertEqual(firstID, firstReply.id)
        XCTAssertEqual(secondID, secondReply.id)
    }

    func testInjectSeparatorsAddsNewSeparatorWhenDayChanges() {
        let calendar = Calendar.current
        let firstDay = calendar.startOfDay(for: base)
        let secondDay = calendar.date(byAdding: .day, value: 1, to: firstDay)!
        let firstReply = ReplySnapshot(
            id: UUID(),
            createdAt: firstDay,
            senderType: .participant,
            participantID: "p1"
        )
        let secondReply = ReplySnapshot(
            id: UUID(),
            createdAt: secondDay,
            senderType: .fan,
            participantID: "p1"
        )

        let items = ReplyCollectionViewManager.injectSeparators([
            group(replies: [firstReply]),
            group(replies: [secondReply])
        ])

        XCTAssertEqual(items.count, 4)
        guard case .separator(let firstDate) = items[0] else {
            return XCTFail("Expected first separator at index 0")
        }
        guard case .group(let firstID) = items[1] else {
            return XCTFail("Expected first group at index 1")
        }
        guard case .separator(let secondDate) = items[2] else {
            return XCTFail("Expected second separator at index 2")
        }
        guard case .group(let secondID) = items[3] else {
            return XCTFail("Expected second group at index 3")
        }
        XCTAssertEqual(firstDate, firstReply.createdAt)
        XCTAssertEqual(firstID, firstReply.id)
        XCTAssertEqual(secondDate, secondReply.createdAt)
        XCTAssertEqual(secondID, secondReply.id)
    }

    // MARK: - applyForwardSnapshot: addedCount counting

    func testForwardSnapshotCountsNewRepliesNotNewGroups() {
        // Regression: with stable group IDs (keyed on first reply), appending a reply to an
        // existing group does NOT produce a new group ID — addedCount must count reply IDs.
        let s1 = snap(offset: 0)
        let initial = [group(replies: [s1])]

        let manager = ReplyCollectionViewManager()
        manager.applyInitialSnapshot(initial)

        let spy = ScrollCoordinatorSpy()
        manager.scrollCoordinator = spy

        let s2 = snap(offset: 30)  // same sender → appends to existing group
        let updated = [group(replies: [s1, s2])]
        manager.applyForwardSnapshot(updated)

        // The group ID hasn't changed (still s1.id), but a new reply was added.
        XCTAssertEqual(
            spy.receivedNewReplyCount,
            1,
            "addedCount must be 1 even when group ID is unchanged"
        )
    }

    func testForwardSnapshotCountsZeroWhenNothingAdded() {
        let s1 = snap(offset: 0)
        let initial = [group(replies: [s1])]

        let manager = ReplyCollectionViewManager()
        manager.applyInitialSnapshot(initial)

        let spy = ScrollCoordinatorSpy()
        manager.scrollCoordinator = spy

        // Re-apply identical groups (e.g. FRC change with no new replies).
        manager.applyForwardSnapshot(initial)

        XCTAssertEqual(spy.receivedNewReplyCount, 0)
        XCTAssertEqual(
            spy.didReceiveNewRepliesCallCount,
            1,
            "didReceiveNewReplies must still be called even when count is 0"
        )
    }

    func testForwardSnapshotCountsMultipleNewRepliesAcrossGroups() {
        let s1 = snap(offset: 0)
        let initial = [group(replies: [s1])]

        let manager = ReplyCollectionViewManager()
        manager.applyInitialSnapshot(initial)

        let spy = ScrollCoordinatorSpy()
        manager.scrollCoordinator = spy

        let s2 = snap(offset: 30)
        let s3 = snap(offset: 60, senderType: .fan)  // different sender → new group
        let updated = [group(replies: [s1, s2]), group(replies: [s3])]
        manager.applyForwardSnapshot(updated)

        XCTAssertEqual(spy.receivedNewReplyCount, 2)
    }

    // MARK: - applyForwardSnapshot: participant metadata change

    func testForwardSnapshotWithChangedParticipantMetadataReconfiguresGroupWithZeroNewReplies() {
        let s1 = snap(offset: 0)
        let initialGroup = MessageGroup(
            id: s1.id,
            senderType: .participant,
            participantID: "p1",
            participantName: "Alice",
            participantAvatarURL: URL(string: "https://example.com/alice.jpg"),
            replies: [s1],
            timestamp: s1.createdAt
        )

        let manager = ReplyCollectionViewManager()
        manager.applyInitialSnapshot([initialGroup])

        let spy = ScrollCoordinatorSpy()
        manager.scrollCoordinator = spy

        // Same reply ID, different participant metadata — simulates a Participant attribute update.
        let updatedGroup = MessageGroup(
            id: s1.id,
            senderType: .participant,
            participantID: "p1",
            participantName: "Alice Updated",
            participantAvatarURL: URL(string: "https://example.com/alice-new.jpg"),
            replies: [s1],
            timestamp: s1.createdAt
        )

        manager.applyForwardSnapshot([updatedGroup])

        // addedCount == 0: no new replies, so no scroll or pill increment.
        XCTAssertEqual(spy.receivedNewReplyCount, 0)
        XCTAssertEqual(
            spy.didReceiveNewRepliesCallCount,
            1,
            "didReceiveNewReplies must still be called even when count is 0"
        )
        // The group ID is stable — same first-reply UUID, different participant metadata.
        // MessageGroup equality includes participantName, so existing != updatedGroup,
        // meaning changedIDs == [s1.id] and reconfigureItems was called for that ID.
        XCTAssertEqual(
            manager.lastReconfiguredGroupIDs,
            [s1.id],
            "Group with changed participant metadata must be scheduled for reconfiguration"
        )
        // No new reply IDs entered the collection.
        XCTAssertEqual(manager.allReplyIDs, [s1.id])
    }

    // MARK: - applyPrependSnapshot: scroll anchor delegation

    func testPrependSnapshotCallsWillApplyOnCoordinator() {
        let s1 = snap(offset: 0)
        let initial = [group(replies: [s1])]

        let manager = ReplyCollectionViewManager()
        manager.applyInitialSnapshot(initial)

        let spy = ScrollCoordinatorSpy()
        manager.scrollCoordinator = spy

        let older = snap(offset: -60)
        let prepended = [group(replies: [older]), group(replies: [s1])]
        manager.applyPrependSnapshot(prepended)

        XCTAssertTrue(
            spy.willApplyPrependSnapshotCalled,
            "coordinator must be asked for previous height before applying prepend snapshot"
        )
    }

    func testPrependSnapshotCallsDidApplyOnCoordinator() {
        let s1 = snap(offset: 0)
        let initial = [group(replies: [s1])]

        let manager = ReplyCollectionViewManager()
        manager.applyInitialSnapshot(initial)

        let spy = ScrollCoordinatorSpy()
        manager.scrollCoordinator = spy

        let older = snap(offset: -60)
        let prepended = [group(replies: [older]), group(replies: [s1])]
        manager.applyPrependSnapshot(prepended)

        XCTAssertTrue(
            spy.didApplyPrependSnapshotCalled,
            "coordinator must be notified after prepend snapshot is applied"
        )
    }

    // MARK: - oldestGroupTimestamp

    func testOldestGroupTimestampReturnsMinTimestamp() {
        let s1 = snap(offset: 0)
        let s2 = snap(offset: 60, senderType: .fan)
        let manager = ReplyCollectionViewManager()
        manager.applyInitialSnapshot([group(replies: [s1]), group(replies: [s2])])
        XCTAssertEqual(manager.oldestGroupTimestamp, s1.createdAt)
    }

    func testOldestGroupTimestampIsNilWhenEmpty() {
        let manager = ReplyCollectionViewManager()
        XCTAssertNil(manager.oldestGroupTimestamp)
    }

    func testOldestGroupTimestampReflectsLastReplyInGroup() {
        // Oldest group has two replies from the same sender: T+0 and T+60.
        // oldestGroupTimestamp must equal the last reply's createdAt (T+60), not the first's (T+0).
        // This exercises: group.timestamp → updateGroupCache → cachedOldestGroupTimestamp → oldestGroupTimestamp.
        let s1 = snap(offset: 0)
        let s2 = snap(offset: 60)
        let manager = ReplyCollectionViewManager()
        manager.applyInitialSnapshot([group(replies: [s1, s2])])
        XCTAssertEqual(
            manager.oldestGroupTimestamp,
            s2.createdAt,
            "oldestGroupTimestamp must reflect the last reply's time, not the first"
        )
    }
}

// MARK: - Test Double

/// Lightweight spy that conforms to `ScrollCoordinatorProtocol` directly.
/// No UICollectionView required, no subclassing of the `final` ScrollCoordinator.
@MainActor
private final class ScrollCoordinatorSpy: ScrollCoordinatorProtocol {
    var receivedNewReplyCount: Int = 0
    var didReceiveNewRepliesCallCount: Int = 0
    var willApplyPrependSnapshotCalled = false
    var didApplyPrependSnapshotCalled = false

    func didReceiveNewReplies(count: Int) {
        receivedNewReplyCount += count
        didReceiveNewRepliesCallCount += 1
    }

    func willApplyPrependSnapshot() -> CGFloat {
        willApplyPrependSnapshotCalled = true
        return 0
    }

    func didApplyPrependSnapshot(previousContentHeight: CGFloat) {
        didApplyPrependSnapshotCalled = true
    }
}
