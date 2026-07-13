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

import CoreData
import Foundation

/// A value-type snapshot extracted from a `Reply` managed object.
/// Used as the item type inside `MessageGroup` so that `MessageGroup`
/// carries no managed-object references and has stable, value-based `Hashable` conformance.
struct ReplySnapshot: Hashable {
    let id: UUID
    /// `nil` only in unit tests where no managed-object context is available.
    ///
    /// Excluded from `Hashable`/`Equatable` — `NSManagedObjectID` uses object identity,
    /// which changes when a temporary ID is promoted to a permanent one after `save()`.
    let objectID: NSManagedObjectID?
    let createdAt: Date
    let senderType: ReplySenderType
    let participantID: String
    let syncState: ReplySyncState
    let contentBlocks: [ContentBlock]

    /// Production initialiser — extracts all fields from a `Reply` managed object.
    init(reply: Reply) {
        self.id = reply.id ?? UUID()
        self.objectID = reply.objectID
        self.createdAt = reply.createdAt ?? Date()
        self.senderType = ReplySenderType(rawValue: reply.senderType ?? "") ?? .participant
        self.participantID = reply.participantID ?? ""
        self.syncState = ReplySyncState(rawValue: reply.syncState ?? "") ?? .sent
        self.contentBlocks = reply.persistedContentBlocks
    }

    /// Test-only initialiser — creates a snapshot without a managed-object context.
    init(
        id: UUID = UUID(),
        createdAt: Date,
        senderType: ReplySenderType,
        participantID: String,
        syncState: ReplySyncState = .confirmed,
        contentBlocks: [ContentBlock] = [.text(text: "Test")]
    ) {
        self.id = id
        self.objectID = nil
        self.createdAt = createdAt
        self.senderType = senderType
        self.participantID = participantID
        self.syncState = syncState
        self.contentBlocks = contentBlocks
    }
}

extension ReplySnapshot {
    static func == (lhs: ReplySnapshot, rhs: ReplySnapshot) -> Bool {
        lhs.id == rhs.id
            && lhs.createdAt == rhs.createdAt
            && lhs.senderType == rhs.senderType
            && lhs.participantID == rhs.participantID
            && lhs.syncState == rhs.syncState
            && lhs.contentBlocks == rhs.contentBlocks
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(createdAt)
        hasher.combine(senderType)
        hasher.combine(participantID)
        hasher.combine(syncState)
        hasher.combine(contentBlocks)
    }
}

/// A group of consecutive replies from the same sender within a 2-minute window.
/// The `id` is the **first** reply's UUID — stable when new replies append to the group.
struct MessageGroup: Hashable {
    /// First reply's ID — stable across appends; triggers delete+insert only when the group is
    /// split (sender change, time window) or a backward-pagination prepend changes the first reply.
    let id: UUID
    let senderType: ReplySenderType
    let participantID: String
    let participantName: String?
    let participantAvatarURL: URL?
    /// Ordered oldest-first.
    let replies: [ReplySnapshot]
    /// Last reply's `createdAt` — displayed as the group timestamp.
    let timestamp: Date
    let hasQueuedReply: Bool

    init(
        id: UUID,
        senderType: ReplySenderType,
        participantID: String,
        participantName: String? = nil,
        participantAvatarURL: URL? = nil,
        replies: [ReplySnapshot],
        timestamp: Date
    ) {
        self.id = id
        self.senderType = senderType
        self.participantID = participantID
        self.participantName = participantName
        self.participantAvatarURL = participantAvatarURL
        self.replies = replies
        self.timestamp = timestamp
        self.hasQueuedReply = replies.contains(where: { $0.syncState == .queued })
    }
}
