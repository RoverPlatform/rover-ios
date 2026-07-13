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
import RoverFoundation

/// A narrow view of the conversation fields the notification service extension needs.
///
/// This type intentionally decodes less than Hub's full wire contract. The APNs payload should
/// still remain compatible with Hub, but the extension only reads the fields needed to render a
/// communication-style notification: the conversation identity, the latest reply, and the active
/// participant.
struct ConversationPushPayload: Decodable {
    struct RoverPayload: Decodable {
        struct Conversation: Decodable {
            /// Stable thread identifier used for grouping and Apple conversation metadata.
            let id: String
            /// Optional server-provided label for the thread.
            ///
            /// This gives the extension access to a human-readable conversation label when the
            /// server distinguishes between the thread identity and the active participant name.
            let subject: String?
        }

        struct Participant: Decodable {
            /// Stable sender identity for the participant represented by this push.
            let id: String
            /// The sender name shown in the communication notification.
            let name: String
            /// Optional remote avatar source. If this is absent or fails to load, Rover generates
            /// a deterministic initials avatar locally.
            let avatarURL: URL?
        }

        struct Reply: Decodable {
            enum CodingKeys: String, CodingKey {
                case id
                case conversationID
                case senderType
                case participantID
                case content
                case createdAt
            }

            struct ContentBlock: Decodable, Equatable {
                /// Mirrors the server's reply content blocks. The extension currently only knows
                /// how to build preview text from blocks where `type == "text"`.
                let type: String
                let text: String?
                let url: URL?
            }

            let id: String
            let conversationID: String
            let senderType: String
            let participantID: String
            let content: [ContentBlock]
            /// Parsed leniently because existing fixtures and server payloads may omit fractional
            /// seconds even though the broader Rover codebase often uses RFC3339 with millis.
            let createdAt: Date?

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decode(String.self, forKey: .id)
                conversationID = try container.decode(String.self, forKey: .conversationID)
                senderType = try container.decode(String.self, forKey: .senderType)
                participantID = try container.decode(String.self, forKey: .participantID)
                content = try container.decode([ContentBlock].self, forKey: .content)

                let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt)
                createdAt = createdAtString.flatMap(Self.parseCreatedAt)
            }

            private static let iso8601Formatter = ISO8601DateFormatter()

            private static func parseCreatedAt(_ value: String) -> Date? {
                if let date = DateFormatter.rfc3339.date(from: value) {
                    return date
                }

                return iso8601Formatter.date(from: value)
            }
        }

        let conversation: Conversation
        let reply: Reply
        let participant: Participant
    }

    let rover: RoverPayload

    /// Attempts to decode a conversation payload from APNs `userInfo`.
    ///
    /// Failure here means either the payload is not a Rover conversation push or it is missing
    /// fields the communication-notification path needs. The helper treats that as "no
    /// conversation enrichment available" and falls back safely.
    static func from(userInfo: [AnyHashable: Any]) -> ConversationPushPayload? {
        guard let data = try? JSONSerialization.data(withJSONObject: userInfo) else {
            return nil
        }

        return try? JSONDecoder.default.decode(ConversationPushPayload.self, from: data)
    }
}
