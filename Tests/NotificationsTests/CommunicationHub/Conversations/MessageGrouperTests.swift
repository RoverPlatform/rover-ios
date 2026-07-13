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

final class MessageGrouperTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 0)

    // MARK: - Helpers

    private func snap(
        senderType: ReplySenderType,
        participantID: String = "p1",
        offset seconds: TimeInterval = 0
    ) -> ReplySnapshot {
        ReplySnapshot(
            createdAt: base.addingTimeInterval(seconds),
            senderType: senderType,
            participantID: participantID
        )
    }

    // MARK: - Empty input

    func testEmptyInputReturnsNoGroups() {
        XCTAssertTrue(MessageGrouper.group([]).isEmpty)
    }

    // MARK: - Single reply

    func testSingleReplyProducesOneGroup() {
        let s = snap(senderType: .participant, offset: 0)
        let groups = MessageGrouper.group([s])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].replies.count, 1)
        XCTAssertEqual(groups[0].id, s.id)
    }

    // MARK: - Sender change breaks group

    func testSenderChangeBreaksGroup() {
        let s1 = snap(senderType: .participant, participantID: "p1", offset: 0)
        let s2 = snap(senderType: .fan, participantID: "fan-local", offset: 30)
        let groups = MessageGrouper.group([s1, s2])
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].replies, [s1])
        XCTAssertEqual(groups[1].replies, [s2])
    }

    func testDifferentParticipantIDBreaksGroup() {
        let s1 = snap(senderType: .participant, participantID: "p1", offset: 0)
        let s2 = snap(senderType: .participant, participantID: "p2", offset: 30)
        let groups = MessageGrouper.group([s1, s2])
        XCTAssertEqual(groups.count, 2)
    }

    // MARK: - Time window

    func testRepliesWithinWindowAreGrouped() {
        let s1 = snap(senderType: .participant, offset: 0)
        let s2 = snap(senderType: .participant, offset: 119)  // 1 second under 2 min
        let groups = MessageGrouper.group([s1, s2])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].replies.count, 2)
    }

    func testRepliesExceedingWindowBreakGroup() {
        let s1 = snap(senderType: .participant, offset: 0)
        let s2 = snap(senderType: .participant, offset: 121)  // 1 second over 2 min
        let groups = MessageGrouper.group([s1, s2])
        XCTAssertEqual(groups.count, 2)
    }

    func testRepliesExactlyAtWindowBoundaryAreGrouped() {
        let s1 = snap(senderType: .participant, offset: 0)
        let s2 = snap(senderType: .participant, offset: 120)  // exactly 2 min
        let groups = MessageGrouper.group([s1, s2])
        XCTAssertEqual(groups.count, 1)
    }

    // MARK: - Group ID stability

    func testGroupIDIsFirstReplyID() {
        let s1 = snap(senderType: .participant, offset: 0)
        let s2 = snap(senderType: .participant, offset: 30)
        let groups = MessageGrouper.group([s1, s2])
        XCTAssertEqual(groups[0].id, s1.id)
    }

    func testGroupIDRemainsStableWhenReplyAppends() {
        let s1 = snap(senderType: .participant, offset: 0)
        let s2 = snap(senderType: .participant, offset: 30)
        let groupsBefore = MessageGrouper.group([s1, s2])

        // New reply arrives, appended to same group
        let s3 = snap(senderType: .participant, offset: 60)
        let groupsAfter = MessageGrouper.group([s1, s2, s3])

        // Group ID is unchanged — diffable data source sees a reconfigure, not delete+insert.
        XCTAssertEqual(groupsBefore[0].id, s1.id)
        XCTAssertEqual(groupsAfter[0].id, s1.id)
        XCTAssertEqual(groupsBefore[0].id, groupsAfter[0].id)
    }

    // MARK: - Timestamp

    func testGroupTimestampIsLastReplyCreatedAt() {
        let s1 = snap(senderType: .participant, offset: 0)
        let s2 = snap(senderType: .participant, offset: 30)
        let groups = MessageGrouper.group([s1, s2])
        XCTAssertEqual(groups[0].timestamp, s2.createdAt)
    }

    // MARK: - Participant data propagation

    func testParticipantNameFlowsThroughWhenProvided() {
        let s = snap(senderType: .participant, participantID: "p1", offset: 0)
        let groups = MessageGrouper.group([s], participants: ["p1": ParticipantInfo(name: "Alice", avatarURL: nil)])
        XCTAssertEqual(groups[0].participantName, "Alice")
    }

    func testParticipantAvatarURLFlowsThroughWhenProvided() {
        let s = snap(senderType: .participant, participantID: "p1", offset: 0)
        let url = URL(string: "https://example.com/avatar.png")!
        let groups = MessageGrouper.group([s], participants: ["p1": ParticipantInfo(name: nil, avatarURL: url)])
        XCTAssertEqual(groups[0].participantAvatarURL, url)
    }

    func testParticipantFieldsAreNilWhenIDNotInLookup() {
        let s = snap(senderType: .participant, participantID: "p1", offset: 0)
        let groups = MessageGrouper.group([s], participants: [:])
        XCTAssertNil(groups[0].participantName)
        XCTAssertNil(groups[0].participantAvatarURL)
    }

    func testParticipantFieldsAreNilWhenNoLookupProvided() {
        let s = snap(senderType: .participant, participantID: "p1", offset: 0)
        let groups = MessageGrouper.group([s])
        XCTAssertNil(groups[0].participantName)
        XCTAssertNil(groups[0].participantAvatarURL)
    }

    func testParticipantNameFlowsThroughForMultiReplyGroup() {
        let s1 = snap(senderType: .participant, participantID: "p1", offset: 0)
        let s2 = snap(senderType: .participant, participantID: "p1", offset: 30)
        let groups = MessageGrouper.group(
            [s1, s2],
            participants: ["p1": ParticipantInfo(name: "Alice", avatarURL: nil)]
        )
        XCTAssertEqual(groups[0].participantName, "Alice")
        XCTAssertEqual(groups[0].replies.count, 2)
    }

    // MARK: - Image blocks do not break grouping

    func testImageContentBlockDoesNotBreakGroup() {
        var s1 = snap(senderType: .participant, offset: 0)
        s1 = ReplySnapshot(
            id: s1.id,
            createdAt: s1.createdAt,
            senderType: s1.senderType,
            participantID: s1.participantID,
            contentBlocks: [.image(url: URL(string: "https://example.com/img.png")!)]
        )
        let s2 = snap(senderType: .participant, offset: 30)
        let groups = MessageGrouper.group([s1, s2])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].replies.count, 2)
    }

    // MARK: - New-reply counting

    func testNewReplyAppendingToExistingGroupProducesOneGroup() {
        let s1 = snap(senderType: .participant, offset: 0)
        let s2 = snap(senderType: .participant, offset: 30)
        let groups = MessageGrouper.group([s1, s2])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].replies.count, 2)
        XCTAssertEqual(groups[0].id, s1.id)
    }

    // MARK: - Multiple groups

    func testThreeGroupsWithMixedSenders() {
        let p1a = snap(senderType: .participant, participantID: "p1", offset: 0)
        let p1b = snap(senderType: .participant, participantID: "p1", offset: 30)
        let fan = snap(senderType: .fan, participantID: "fan-local", offset: 60)
        let p1c = snap(senderType: .participant, participantID: "p1", offset: 90)

        let groups = MessageGrouper.group([p1a, p1b, fan, p1c])
        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups[0].replies, [p1a, p1b])
        XCTAssertEqual(groups[1].replies, [fan])
        XCTAssertEqual(groups[2].replies, [p1c])
    }
}
