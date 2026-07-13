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

/// Display data for a participant, used to enrich `MessageGroup` during grouping.
struct ParticipantInfo: Equatable {
    let name: String?
    let avatarURL: URL?
}

/// Groups an ordered array of reply snapshots into `MessageGroup` clusters.
/// Pure function — no state, no side effects.
enum MessageGrouper {
    /// Maximum gap between consecutive replies from the same sender before a new group starts.
    static let groupingWindow: TimeInterval = 2 * 60  // 2 minutes

    /// Groups `snapshots` (ordered oldest-first) into `MessageGroup` clusters.
    ///
    /// A new group starts when:
    /// - The sender (`senderType` + `participantID`) changes, or
    /// - More than `groupingWindow` seconds have elapsed since the previous reply.
    ///
    /// - Parameter snapshots: Replies ordered oldest-first.
    /// - Parameter participants: Optional lookup keyed by `participantID` providing
    ///   display name and avatar URL. Missing entries leave those fields `nil`.
    /// - Returns: Groups ordered oldest-first.
    static func group(
        _ snapshots: [ReplySnapshot],
        participants: [String: ParticipantInfo] = [:]
    ) -> [MessageGroup] {
        guard !snapshots.isEmpty else { return [] }

        var groups: [MessageGroup] = []
        var current: [ReplySnapshot] = []

        for snapshot in snapshots {
            if current.isEmpty {
                current.append(snapshot)
                continue
            }

            let last = current.last!
            let sameSender =
                last.senderType == snapshot.senderType
                && last.participantID == snapshot.participantID
            let withinWindow =
                snapshot.createdAt.timeIntervalSince(last.createdAt) <= groupingWindow

            if sameSender && withinWindow {
                current.append(snapshot)
            } else {
                groups.append(makeGroup(from: current, participants: participants))
                current = [snapshot]
            }
        }

        if !current.isEmpty {
            groups.append(makeGroup(from: current, participants: participants))
        }

        return groups
    }

    private static func makeGroup(
        from replies: [ReplySnapshot],
        participants: [String: ParticipantInfo]
    ) -> MessageGroup {
        let first = replies[0]
        let info = participants[first.participantID]
        return MessageGroup(
            id: first.id,
            senderType: first.senderType,
            participantID: first.participantID,
            participantName: info?.name,
            participantAvatarURL: info?.avatarURL,
            replies: replies,
            // `replies` is always non-empty here: makeGroup is only called from
            // the else-branch (which appended at least one reply to `current`) and
            // the `if !current.isEmpty` guard — so `last!` is safe.
            timestamp: replies.last!.createdAt
        )
    }
}
