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

enum HubItem: Identifiable {
    case post(Post)
    case conversation(Conversation)

    var id: String {
        switch self {
        case .post(let p):
            return "post-\(p.id?.uuidString ?? p.objectID.uriRepresentation().absoluteString)"
        case .conversation(let c):
            return "conversation-\(c.id?.uuidString ?? c.objectID.uriRepresentation().absoluteString)"
        }
    }

    var activityAt: Date {
        switch self {
        case .post(let p): return p.receivedAt ?? .distantPast
        case .conversation(let c): return c.lastReplyAt ?? c.createdAt ?? .distantPast
        }
    }

    var isRead: Bool {
        switch self {
        case .post(let p): return p.isRead
        case .conversation(let c): return c.isRead
        }
    }
}
