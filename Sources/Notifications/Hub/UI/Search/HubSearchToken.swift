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

/// A search token applied in the Hub messages search field, narrowing
/// results to a single subscription's posts or a single sender's
/// conversations. Tokens are inserted by tapping a search suggestion.
enum HubSearchToken: Identifiable, Hashable {
    case subscription(id: String, name: String, logoURL: URL?)
    case sender(participantID: String, name: String, avatarURL: URL?)

    var id: String {
        switch self {
        case .subscription(let id, _, _):
            return "sub:\(id)"
        case .sender(let participantID, _, _):
            return "sender:\(participantID)"
        }
    }

    var name: String {
        switch self {
        case .subscription(_, let name, _), .sender(_, let name, _):
            return name
        }
    }

    var imageURL: URL? {
        switch self {
        case .subscription(_, _, let logoURL):
            return logoURL
        case .sender(_, _, let avatarURL):
            return avatarURL
        }
    }

    var systemImage: String {
        switch self {
        case .subscription:
            return "newspaper.circle.fill"
        case .sender:
            return "person.circle.fill"
        }
    }
}
