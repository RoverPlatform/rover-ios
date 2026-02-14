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

import Foundation

extension Date {
    // Helper function to format timestamp according to rules
    func formattedTimestamp() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: self)
        let nowComponents = calendar.dateComponents([.year, .month, .day], from: now)

        // If it occurred today, just display the time
        if components.year == nowComponents.year &&
            components.month == nowComponents.month &&
            components.day == nowComponents.day {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: self)
        }

        // If it occurred yesterday, display "Yesterday"
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(yesterday, inSameDayAs: self) {
            return "Yesterday"
        }

        // If it occurred this week, display the day-of-the-week
        if let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now),
           self > oneWeekAgo {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Full day name
            return formatter.string(from: self)
        }

        // If it occurred this year, display the month (3-letter abbreviation) and the day
        if components.year == nowComponents.year {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self)
        }

        // Otherwise display it like YYYY-MM-DD
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}
