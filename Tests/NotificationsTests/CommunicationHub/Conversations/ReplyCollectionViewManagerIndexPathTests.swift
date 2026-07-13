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

/// Tests that `indexPath(forReplyID:)` returns the correct index path when separator items
/// are interleaved with group items in the snapshot.
@MainActor
final class ReplyCollectionViewManagerIndexPathTests: XCTestCase {
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
            timestamp: replies.last!.createdAt
        )
    }

    func testIndexPathAccountsForSeparatorOffset() {
        let manager = ReplyCollectionViewManager()
        let calendar = Calendar.current

        // Two groups on different days.
        // After injectSeparators the snapshot order is:
        //   item 0: .separator(day1)
        //   item 1: .group(id1)
        //   item 2: .separator(day2)
        //   item 3: .group(id2)
        let id1 = UUID()
        let id2 = UUID()

        var c1 = DateComponents()
        c1.year = 2026
        c1.month = 3
        c1.day = 12
        let date1 = calendar.date(from: c1)!

        var c2 = DateComponents()
        c2.year = 2026
        c2.month = 3
        c2.day = 13
        let date2 = calendar.date(from: c2)!

        let reply1 = ReplySnapshot(
            id: id1,
            createdAt: date1,
            senderType: .fan,
            participantID: "u1"
        )
        let reply2 = ReplySnapshot(
            id: id2,
            createdAt: date2,
            senderType: .participant,
            participantID: "a1"
        )

        let group1 = MessageGroup(
            id: id1,
            senderType: .fan,
            participantID: "u1",
            replies: [reply1],
            timestamp: date1
        )
        let group2 = MessageGroup(
            id: id2,
            senderType: .participant,
            participantID: "a1",
            replies: [reply2],
            timestamp: date2
        )

        manager.applyInitialSnapshot([group1, group2])

        XCTAssertEqual(
            manager.indexPath(forReplyID: id1),
            IndexPath(item: 1, section: 0),
            "group1 should be at item 1 (after its day separator at item 0)"
        )
        XCTAssertEqual(
            manager.indexPath(forReplyID: id2),
            IndexPath(item: 3, section: 0),
            "group2 should be at item 3 (sep1 + group1 + sep2 before it)"
        )
    }

    func testIndexPathReturnsNilForUnknownReplyID() {
        let manager = ReplyCollectionViewManager()
        let known = snap(offset: 0)

        manager.applyInitialSnapshot([group(replies: [known])])

        XCTAssertNil(manager.indexPath(forReplyID: UUID()))
    }

    func testIndexPathUpdatesAfterForwardSnapshotAppendsReplyToExistingGroup() {
        let manager = ReplyCollectionViewManager()
        let first = snap(offset: 0)
        let appended = snap(offset: 60)

        manager.applyInitialSnapshot([group(replies: [first])])
        manager.applyForwardSnapshot([group(replies: [first, appended])])

        XCTAssertEqual(
            manager.indexPath(forReplyID: first.id),
            IndexPath(item: 1, section: 0)
        )
        XCTAssertEqual(
            manager.indexPath(forReplyID: appended.id),
            IndexPath(item: 1, section: 0)
        )
    }

    func testIndexPathUpdatesAfterPrependSnapshotInsertsOlderGroup() {
        let manager = ReplyCollectionViewManager()
        let existingReply = snap(offset: 60)
        let olderReply = snap(offset: 0, senderType: .fan)

        manager.applyInitialSnapshot([group(replies: [existingReply])])
        manager.applyPrependSnapshot([
            group(replies: [olderReply]),
            group(replies: [existingReply]),
        ])

        XCTAssertEqual(
            manager.indexPath(forReplyID: olderReply.id),
            IndexPath(item: 1, section: 0)
        )
        XCTAssertEqual(
            manager.indexPath(forReplyID: existingReply.id),
            IndexPath(item: 2, section: 0)
        )
    }
}
