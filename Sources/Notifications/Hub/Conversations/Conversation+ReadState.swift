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

extension Conversation {
    var isRead: Bool {
        // Some payloads can omit `lastIncomingReplyAt` while still providing
        // `lastReplyAt`; treat that as activity so new conversations do not
        // appear read by default.
        guard let latestRelevantReplyAt = lastIncomingReplyAt ?? lastReplyAt else {
            return true
        }

        guard let lastReadAt else {
            return false
        }

        return latestRelevantReplyAt <= lastReadAt
    }

    /// SQL equivalent of `isRead` for use in Core Data fetch/count requests.
    static let unreadPredicate = NSPredicate(
        format: """
            (lastIncomingReplyAt != nil AND (lastReadAt == nil OR lastIncomingReplyAt > lastReadAt)) \
            OR (lastIncomingReplyAt == nil AND lastReplyAt != nil AND (lastReadAt == nil OR lastReplyAt > lastReadAt))
            """
    )
}
