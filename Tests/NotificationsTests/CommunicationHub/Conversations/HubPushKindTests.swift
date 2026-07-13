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

import XCTest

@testable import RoverNotifications

/// Tests for `InboxPersistentContainer.hubPushKind(from:)` — the single predicate that decides
/// what `receiveFromPush` inserts and what a 410 reset clears. The two sides must agree on what
/// counts as a Hub push, so these cases mirror the payload shapes routed by `receiveFromPush`.
final class HubPushKindTests: XCTestCase {

    func testPostPayloadIsPost() {
        let userInfo: [AnyHashable: Any] = ["rover": ["post": ["id": UUID().uuidString]]]
        XCTAssertEqual(InboxPersistentContainer.hubPushKind(from: userInfo), .post)
    }

    func testConversationPayloadIsConversation() {
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["id": UUID().uuidString],
                "reply": ["id": UUID().uuidString],
                "participant": ["id": "p1"]
            ]
        ]
        XCTAssertEqual(InboxPersistentContainer.hubPushKind(from: userInfo), .conversation)
    }

    /// `hubPushKind` keys only on the `conversation` object. A conversation payload missing its
    /// reply/participant siblings is still classified as `.conversation` so its notification is
    /// cleared on reset, even though `receiveFromPush` would reject it as malformed.
    func testConversationPayloadWithoutSiblingsIsStillConversation() {
        let userInfo: [AnyHashable: Any] = ["rover": ["conversation": ["id": UUID().uuidString]]]
        XCTAssertEqual(InboxPersistentContainer.hubPushKind(from: userInfo), .conversation)
    }

    func testNonHubRoverPayloadIsNil() {
        let userInfo: [AnyHashable: Any] = ["rover": ["action": ["url": "https://example.com"]]]
        XCTAssertNil(InboxPersistentContainer.hubPushKind(from: userInfo))
    }

    func testMissingRoverKeyIsNil() {
        XCTAssertNil(InboxPersistentContainer.hubPushKind(from: ["aps": ["alert": "hi"]]))
    }

    func testEmptyPayloadIsNil() {
        XCTAssertNil(InboxPersistentContainer.hubPushKind(from: [:]))
    }
}
