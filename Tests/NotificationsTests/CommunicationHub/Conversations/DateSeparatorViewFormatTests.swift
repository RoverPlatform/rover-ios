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

final class DateSeparatorViewFormatTests: XCTestCase {
    private let calendar = Calendar.current

    private func expectedTime(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("jm")
        return f.string(from: date)
    }

    func testToday() {
        let now = Date()
        let result = DateSeparatorView.format(now)
        XCTAssertEqual(result.day, "Today")
        XCTAssertEqual(result.time, expectedTime(for: now))
    }

    func testYesterday() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let result = DateSeparatorView.format(yesterday)
        XCTAssertEqual(result.day, "Yesterday")
        XCTAssertEqual(result.time, expectedTime(for: yesterday))
    }

    func testWithinLastSevenDays() {
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!
        let expectedDay: String = {
            let f = DateFormatter()
            f.locale = .autoupdatingCurrent
            f.setLocalizedDateFormatFromTemplate("EEEE")
            return f.string(from: threeDaysAgo)
        }()
        let result = DateSeparatorView.format(threeDaysAgo)
        XCTAssertEqual(result.day, expectedDay)
        XCTAssertEqual(result.time, expectedTime(for: threeDaysAgo))
    }

    func testOlderSameYear() {
        // Skip near a year boundary (e.g. January 1-8) where 8 days ago is the prior year.
        let eightDaysAgo = calendar.date(byAdding: .day, value: -8, to: Date())!
        guard calendar.component(.year, from: eightDaysAgo) == calendar.component(.year, from: Date())
        else { return }
        let expectedDay: String = {
            let f = DateFormatter()
            f.locale = .autoupdatingCurrent
            f.setLocalizedDateFormatFromTemplate("EEEddMMM")
            return f.string(from: eightDaysAgo)
        }()
        let result = DateSeparatorView.format(eightDaysAgo)
        XCTAssertEqual(result.day, expectedDay)
        XCTAssertEqual(result.time, expectedTime(for: eightDaysAgo))
    }

    func testExactlySevenDaysAgo() {
        // daysAgo == 7 falls into the abbreviated-date branch (daysAgo < 7 is false).
        // Skip near a year boundary where 7 days ago is in the prior year.
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        guard calendar.component(.year, from: sevenDaysAgo) == calendar.component(.year, from: Date())
        else { return }
        let expectedDay: String = {
            let f = DateFormatter()
            f.locale = .autoupdatingCurrent
            f.setLocalizedDateFormatFromTemplate("EEEddMMM")
            return f.string(from: sevenDaysAgo)
        }()
        let result = DateSeparatorView.format(sevenDaysAgo)
        XCTAssertEqual(
            result.day,
            expectedDay,
            "Exactly 7 days ago is not 'within last 7 days' — should render as abbreviated date"
        )
        XCTAssertEqual(result.time, expectedTime(for: sevenDaysAgo))
    }

    func testPriorYear() {
        let lastYear = calendar.component(.year, from: Date()) - 1
        var components = DateComponents()
        components.year = lastYear
        components.month = 3
        components.day = 2
        let date = calendar.date(from: components)!
        let expectedDay: String = {
            let f = DateFormatter()
            f.locale = .autoupdatingCurrent
            f.setLocalizedDateFormatFromTemplate("EEEddMMMy")
            return f.string(from: date)
        }()
        let result = DateSeparatorView.format(date)
        XCTAssertEqual(result.day, expectedDay)
        XCTAssertEqual(result.time, expectedTime(for: date))
    }
}
