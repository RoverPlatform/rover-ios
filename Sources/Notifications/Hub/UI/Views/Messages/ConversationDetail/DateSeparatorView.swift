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

import SwiftUI

// Centered date separator rendered between message groups at calendar day boundaries.
struct DateSeparatorView: View {
    let date: Date

    var body: some View {
        let parts = Self.format(date)
        return (
            Text(parts.day).fontWeight(.semibold)
            + Text(", \(parts.time)")
        )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
            .accessibilityLabel("\(parts.day), \(parts.time)")
            .accessibilityAddTraits(.isStaticText)
    }

    /// Formats `date` as a human-readable string relative to the current calendar day.
    ///
    /// - Today → "Today, 3:15 PM"
    /// - Yesterday → "Yesterday, 3:15 PM"
    /// - Within last 7 days → "Wednesday, 3:15 PM"
    /// - Same calendar year, older than 7 days → "Mon 2 Mar, 3:15 PM"
    /// - Prior calendar year → "Mon 2 Mar 2025, 3:15 PM"
    static func format(_ date: Date) -> (day: String, time: String) {
        let calendar = Calendar.current
        let now = Date()
        let time = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) { return ("Today", time) }
        if calendar.isDateInYesterday(date) { return ("Yesterday", time) }

        let daysAgo =
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: date),
                to: calendar.startOfDay(for: now)
            ).day ?? 0

        if daysAgo < 7 {
            return (weekdayFormatter.string(from: date), time)
        }

        let dayText =
            calendar.component(.year, from: date) < calendar.component(.year, from: now)
            ? shortDateWithYearFormatter.string(from: date)
            : shortDateFormatter.string(from: date)
        return (dayText, time)
    }

    // DateFormatter initialisation is expensive; cache instances as static properties.
    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("EEEE")
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("EEEddMMM")
        return f
    }()

    private static let shortDateWithYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("EEEddMMMy")
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("jm")
        return f
    }()
}
