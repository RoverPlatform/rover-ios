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

/// Tests for `ConversationCollectionViewController.hasPrependedReplies(in:preBackfillReplyIDs:preBackfillOldestTimestamp:)`.
///
/// All test cases exercise the pure static function directly — no FRC, no Core Data, no UIKit.
@MainActor
final class BackfillDiscriminationTests: XCTestCase {

    // MARK: - Helpers

    private let base = Date(timeIntervalSince1970: 1_000_000)

    private func snap(id: UUID = UUID(), offset: TimeInterval = 0) -> ReplySnapshot {
        ReplySnapshot(
            id: id,
            createdAt: base.addingTimeInterval(offset),
            senderType: .participant,
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

    private typealias VC = ConversationCollectionViewController

    // MARK: - Forward-sync changes during backfill → NOT a backfill

    func testForwardSyncDuringBackfillNotClassifiedAsPrepend() {
        let existing = snap(offset: 0)
        let preIDs: Set<UUID> = [existing.id]
        let fence = base

        let newForward = snap(offset: 60)
        let groups = [group(replies: [existing, newForward])]

        XCTAssertFalse(
            VC.hasPrependedReplies(in: groups, preBackfillReplyIDs: preIDs, preBackfillOldestTimestamp: fence),
            "Reply added after the fence must be classified as forward, not prepend"
        )
    }

    // MARK: - Genuine prepend → IS a backfill

    func testOlderReplyClassifiedAsPrepend() {
        let existing = snap(offset: 0)
        let preIDs: Set<UUID> = [existing.id]
        let fence = base

        let older = snap(offset: -60)
        let groups = [group(replies: [older]), group(replies: [existing])]

        XCTAssertTrue(
            VC.hasPrependedReplies(in: groups, preBackfillReplyIDs: preIDs, preBackfillOldestTimestamp: fence)
        )
    }

    func testTiedTimestampReplyClassifiedAsPrepend() {
        // Regression guard: prepended reply with createdAt == fence must still be treated as prepend.
        let existing = snap(offset: 0)
        let preIDs: Set<UUID> = [existing.id]
        let fence = base

        let tied = snap(offset: 0)  // different ID, same createdAt as fence
        let groups = [group(replies: [tied, existing])]

        XCTAssertTrue(
            VC.hasPrependedReplies(in: groups, preBackfillReplyIDs: preIDs, preBackfillOldestTimestamp: fence),
            "A new reply with createdAt == fence must be treated as prepend (tied-timestamp case)"
        )
    }

    // MARK: - No added replies → NOT a backfill

    func testNoAddedRepliesNotClassifiedAsPrepend() {
        let s1 = snap(offset: 0)
        let preIDs: Set<UUID> = [s1.id]
        let fence = base

        let groups = [group(replies: [s1])]

        XCTAssertFalse(
            VC.hasPrependedReplies(in: groups, preBackfillReplyIDs: preIDs, preBackfillOldestTimestamp: fence)
        )
    }

    // MARK: - Empty pre-backfill state → any data is a prepend

    func testEmptyConversationFirstLoadClassifiedAsPrepend() {
        let s1 = snap(offset: 0)
        let groups = [group(replies: [s1])]

        XCTAssertTrue(
            VC.hasPrependedReplies(in: groups, preBackfillReplyIDs: [], preBackfillOldestTimestamp: nil)
        )
    }

    // MARK: - Mixed batch: prepend + forward replies in same FRC change

    func testMixedBatchWithOlderReplyClassifiedAsPrepend() {
        let existing = snap(offset: 0)
        let preIDs: Set<UUID> = [existing.id]
        let fence = base

        let olderPrepend = snap(offset: -60)
        let newerForward = snap(offset: 60)

        let groups = [
            group(replies: [olderPrepend]),
            group(replies: [existing, newerForward])
        ]

        XCTAssertTrue(
            VC.hasPrependedReplies(in: groups, preBackfillReplyIDs: preIDs, preBackfillOldestTimestamp: fence),
            "Mixed batch must be classified as backfill so prepend anchoring runs"
        )
    }

    // MARK: - forwardAddedCount: split-event double-count prevention (P1)

    func testForwardReplyAlreadyInManagerCacheNotCountedAgain() {
        let existing = snap(offset: 0)
        let fence = base

        // C arrived via an earlier forward-only FRC event; it is already in manager cache.
        let forwardC = snap(offset: 60)
        let knownBeforeApply: Set<UUID> = [existing.id, forwardC.id]

        let olderPrepend = snap(offset: -60)
        let groups = [
            group(replies: [olderPrepend]),
            group(replies: [existing, forwardC])
        ]

        XCTAssertEqual(
            VC.forwardAddedCount(
                in: groups,
                knownBeforeBackfillApply: knownBeforeApply,
                preBackfillOldestTimestamp: fence
            ),
            0,
            "Forward reply already counted via applyForwardSnapshot must not be counted again"
        )
    }

    func testForwardReplyNotYetInManagerCacheIsCounted() {
        let existing = snap(offset: 0)
        let fence = base

        // Manager cache only has the original replies; C is new in this batch.
        let knownBeforeApply: Set<UUID> = [existing.id]

        let olderPrepend = snap(offset: -60)
        let forwardC = snap(offset: 60)
        let groups = [
            group(replies: [olderPrepend]),
            group(replies: [existing, forwardC])
        ]

        XCTAssertEqual(
            VC.forwardAddedCount(
                in: groups,
                knownBeforeBackfillApply: knownBeforeApply,
                preBackfillOldestTimestamp: fence
            ),
            1,
            "Forward reply new in this batch must be counted exactly once"
        )
    }

    func testPrependedRepliesNotCountedAsForward() {
        let existing = snap(offset: 0)
        let fence = base
        let knownBeforeApply: Set<UUID> = [existing.id]

        let older1 = snap(offset: -120)
        let older2 = snap(offset: -60)
        let groups = [
            group(replies: [older1]),
            group(replies: [older2, existing])
        ]

        XCTAssertEqual(
            VC.forwardAddedCount(
                in: groups,
                knownBeforeBackfillApply: knownBeforeApply,
                preBackfillOldestTimestamp: fence
            ),
            0,
            "Backfilled (older) replies must not be counted as forward additions"
        )
    }

    // MARK: - Multi-reply oldest group: fence is last reply's timestamp

    func testMultiReplyOldestGroupFenceIsLastReplyTimestamp() {
        // Oldest group has two replies: T+0 and T+60 (same sender, within grouping window).
        // Production fence = group.timestamp = last reply's createdAt = T+60.
        // A reply at T+30 (new UUID, not in preIDs) must be classified as prepend because
        // T+30 ≤ T+60. With the old first-reply fence (T+0), T+30 > T+0 → returns false.
        let early = snap(offset: 0)
        let late = snap(offset: 60)
        let preIDs: Set<UUID> = [early.id, late.id]
        let fence = group(replies: [early, late]).timestamp  // T+60 with correct helper

        let between = snap(offset: 30)
        let groups = [
            group(replies: [between]),
            group(replies: [early, late])
        ]

        XCTAssertTrue(
            VC.hasPrependedReplies(
                in: groups,
                preBackfillReplyIDs: preIDs,
                preBackfillOldestTimestamp: fence
            ),
            "Reply at T+30 must be prepend when fence is last reply's time (T+60)"
        )
    }
}
