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

/// JSON DTO for Conversations from the Rover Engage API.
struct ConversationItem: Equatable, Identifiable, Codable {
    typealias ID = UUID

    var id: ID
    var subject: String?
    var lastReplyAt: Date?
    var lastIncomingReplyAt: Date?
    var lastIncomingParticipantID: String?
    var lastReadAt: Date?
    var lastReadReplyID: UUID?
    var lastReplyPreview: String?
    var participantIDs: Set<String>
    var createdAt: Date
    var updatedAt: Date
}

/// JSON DTO for a Participant from the Rover Engage API.
struct ParticipantItem: Codable {
    var id: String
    var name: String?
    var avatarURL: String?
    var bio: String?
    var updatedAt: Date
}

struct ConversationsSyncResponse: Codable {
    let conversations: [ConversationItem]
    let included: IncludedData?
    let nextCursor: String?
    let nextBefore: String?
    let hasMore: Bool

    struct IncludedData: Codable {
        static let includeKey = "participants"
        let participants: [ParticipantItem]
    }
}
