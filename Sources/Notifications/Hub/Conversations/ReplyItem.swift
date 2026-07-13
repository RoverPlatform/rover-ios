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
import os.log

enum ContentBlock: Codable, Equatable, Hashable {
    case text(text: String)
    case image(url: URL)
    /// A content block type the SDK does not recognise. The full original JSON payload is
    /// preserved in `rawJSON` so a future app version can re-parse it once it gains support
    /// for the new type. We cannot rely on re-syncing the reply because the cursor-based
    /// sync model means each reply is only delivered once. Unknown blocks are never surfaced
    /// in the UI — `ContentBlock(persistedBlock:)` returns `nil` for `type == "unknown"`.
    case unknown(rawJSON: String)

    enum CodingKeys: String, CodingKey { case type, text, url }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let blockType = try container.decode(String.self, forKey: .type)
        switch blockType {
        case "text": self = .text(text: try container.decode(String.self, forKey: .text))
        case "image": self = .image(url: try container.decode(URL.self, forKey: .url))
        default:
            // Capture the full block payload so nothing is lost. We re-read all keys via
            // AnyCodingKey (both containers decode the same underlying JSON object) and
            // re-serialise to a JSON string. .withoutEscapingSlashes keeps URLs readable.
            let anyContainer = try decoder.container(keyedBy: AnyCodingKey.self)
            var dict: [String: Any] = [:]
            for key in anyContainer.allKeys {
                if let value = try? anyContainer.decode(RawJSONValue.self, forKey: key) {
                    dict[key.stringValue] = value.anyValue
                }
            }
            let jsonData =
                (try? JSONSerialization.data(withJSONObject: dict, options: .withoutEscapingSlashes)) ?? Data()
            self = .unknown(rawJSON: String(data: jsonData, encoding: .utf8) ?? "{}")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let url):
            try container.encode("image", forKey: .type)
            try container.encode(url, forKey: .url)
        case .unknown:
            try container.encode("unknown", forKey: .type)
        }
    }
}

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private enum RawJSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? c.decode(Double.self) {
            self = .number(n)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else {
            self = .null
        }
    }

    var anyValue: Any {
        switch self {
        case .string(let s): return s
        case .number(let n): return n
        case .bool(let b): return b
        case .null: return NSNull()
        }
    }
}

struct ReplyItem: Equatable, Identifiable, Codable {
    typealias ID = UUID

    var id: ID
    var conversationID: UUID
    var senderType: ReplySenderType
    var participantID: String?
    var content: [ContentBlock]
    var externalID: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case conversationID
        case senderType
        case participantID
        case content
        case externalID
        case createdAt
    }

    init(
        id: ID,
        conversationID: UUID,
        senderType: ReplySenderType,
        participantID: String? = nil,
        content: [ContentBlock],
        externalID: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderType = senderType
        self.participantID = participantID
        self.content = content
        self.externalID = externalID
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(ID.self, forKey: .id)
        conversationID = try container.decode(UUID.self, forKey: .conversationID)
        senderType = try container.decode(ReplySenderType.self, forKey: .senderType)
        content = try container.decode([ContentBlock].self, forKey: .content)
        externalID = try container.decodeIfPresent(String.self, forKey: .externalID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        participantID = try container.decodeIfPresent(String.self, forKey: .participantID)

        // participantID is required for non-fan replies.
        guard participantID != nil || senderType == .fan else {
            throw DecodingError.valueNotFound(
                String.self,
                DecodingError.Context(
                    codingPath: container.codingPath + [CodingKeys.participantID],
                    debugDescription: "participantID is required for non-fan replies."
                )
            )
        }
    }
}

struct RepliesSyncResponse: Codable {
    let replies: [ReplyItem]
    let nextCursor: String?
    let nextBefore: String?
    let hasMore: Bool
}

enum ReplySenderType: String, Codable {
    case fan
    case participant
}

enum ReplySyncState: String {
    case queued
    case sent
    case confirmed
    case failed
}

private extension ContentBlock {
    init?(persistedBlock: ReplyContentBlock) {
        switch persistedBlock.type {
        case "text":
            guard let text = persistedBlock.text else {
                return nil
            }
            self = .text(text: text)
        case "image":
            guard let url = persistedBlock.url else {
                return nil
            }
            self = .image(url: url)
        default:
            return nil
        }
    }
}

extension Reply {
    var persistedContentBlocks: [ContentBlock] {
        guard let blocks = contentBlocks?.allObjects as? [ReplyContentBlock] else {
            return []
        }

        return
            blocks
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { block in
                guard let contentBlock = ContentBlock(persistedBlock: block) else {
                    os_log(
                        "Skipping unreadable ReplyContentBlock type=%{private}@ for reply %{private}@",
                        log: .hub,
                        type: .error,
                        block.type ?? "nil",
                        self.id?.uuidString ?? "nil"
                    )
                    return nil
                }
                return contentBlock
            }
    }
}
