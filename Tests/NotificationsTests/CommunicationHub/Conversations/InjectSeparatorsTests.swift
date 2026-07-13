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

@MainActor
final class InjectSeparatorsTests: XCTestCase {
    private let calendar = Calendar.current

    // MARK: - Helpers

    private func makeGroup(id: UUID = UUID(), date: Date) -> MessageGroup {
        MessageGroup(
            id: id,
            senderType: .fan,
            participantID: "test",
            replies: [],
            timestamp: date
        )
    }

    /// Returns the start of the day that is `offsetDays` from today.
    private func day(offsetDays: Int) -> Date {
        let base = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: offsetDays, to: base)!
    }

    // MARK: - Tests

    func testEmptyInput() {
        XCTAssertEqual(ReplyCollectionViewManager.injectSeparators([]), [])
    }

    func testSingleGroup() {
        let id = UUID()
        let d = day(offsetDays: 0)
        let result = ReplyCollectionViewManager.injectSeparators([makeGroup(id: id, date: d)])
        XCTAssertEqual(result, [.separator(calendar.startOfDay(for: d)), .group(id)])
    }

    func testTwoGroupsSameDay() {
        let id1 = UUID()
        let id2 = UUID()
        let d = day(offsetDays: -1)
        let result = ReplyCollectionViewManager.injectSeparators([
            makeGroup(id: id1, date: d),
            makeGroup(id: id2, date: d.addingTimeInterval(60))
        ])
        XCTAssertEqual(
            result,
            [
                .separator(calendar.startOfDay(for: d)),
                .group(id1),
                .group(id2)
            ]
        )
    }

    func testTwoGroupsDifferentDays() {
        let id1 = UUID()
        let id2 = UUID()
        let d1 = day(offsetDays: -2)
        let d2 = day(offsetDays: -1)
        let result = ReplyCollectionViewManager.injectSeparators([
            makeGroup(id: id1, date: d1),
            makeGroup(id: id2, date: d2)
        ])
        XCTAssertEqual(
            result,
            [
                .separator(d1), .group(id1),
                .separator(d2), .group(id2)
            ]
        )
    }

    func testThreeGroupsThreeDays() {
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()
        let d1 = day(offsetDays: -3)
        let d2 = day(offsetDays: -2)
        let d3 = day(offsetDays: -1)
        let result = ReplyCollectionViewManager.injectSeparators([
            makeGroup(id: id1, date: d1),
            makeGroup(id: id2, date: d2),
            makeGroup(id: id3, date: d3)
        ])
        XCTAssertEqual(
            result,
            [
                .separator(d1), .group(id1),
                .separator(d2), .group(id2),
                .separator(d3), .group(id3)
            ]
        )
    }

    func testIdenticalTimestampsNoDuplicateSeparator() {
        let id1 = UUID()
        let id2 = UUID()
        let d = day(offsetDays: -1)
        let result = ReplyCollectionViewManager.injectSeparators([
            makeGroup(id: id1, date: d),
            makeGroup(id: id2, date: d)
        ])
        let separatorCount = result.filter {
            guard case .separator = $0 else { return false }
            return true
        }.count
        XCTAssertEqual(
            separatorCount,
            1,
            "Identical timestamps should not produce duplicate separators"
        )
    }

    func testLastItemIsAlwaysGroup() {
        let id1 = UUID()
        let id2 = UUID()
        let d1 = day(offsetDays: -2)
        let d2 = day(offsetDays: -1)
        let result = ReplyCollectionViewManager.injectSeparators([
            makeGroup(id: id1, date: d1),
            makeGroup(id: id2, date: d2)
        ])
        XCTAssertEqual(result.last, .group(id2), "Last item must always be .group(_)")
    }

    func testPrependDayBoundary() {
        // Simulates a backfill prepend: an older-day group is followed by a newer-day group.
        // Expected output: [.separator(dayOlder), .group(id1), .separator(dayNewer), .group(id2)]
        let id1 = UUID()
        let id2 = UUID()
        let dayOlder = day(offsetDays: -5)
        let dayNewer = day(offsetDays: -1)
        let result = ReplyCollectionViewManager.injectSeparators([
            makeGroup(id: id1, date: dayOlder),
            makeGroup(id: id2, date: dayNewer)
        ])
        XCTAssertEqual(
            result,
            [
                .separator(dayOlder), .group(id1),
                .separator(dayNewer), .group(id2)
            ]
        )
    }

    func testReconfigureSeparatorCountStable() {
        // Simulates the reconfigureItems path: calling injectSeparators twice with the same
        // groups must produce the same separator count (separators are not added or removed).
        let id1 = UUID()
        let id2 = UUID()
        let d1 = day(offsetDays: -2)
        let d2 = day(offsetDays: -1)
        let groups = [makeGroup(id: id1, date: d1), makeGroup(id: id2, date: d2)]

        let countFirst = ReplyCollectionViewManager.injectSeparators(groups).filter {
            guard case .separator = $0 else { return false }
            return true
        }.count
        let countSecond = ReplyCollectionViewManager.injectSeparators(groups).filter {
            guard case .separator = $0 else { return false }
            return true
        }.count

        XCTAssertEqual(countFirst, 2)
        XCTAssertEqual(
            countFirst,
            countSecond,
            "Separator count must be stable across repeated injectSeparators calls with the same input"
        )
    }
}
