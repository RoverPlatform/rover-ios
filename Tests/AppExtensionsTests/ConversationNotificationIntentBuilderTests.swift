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

import Intents
import XCTest

@testable import RoverAppExtensions

final class ConversationNotificationIntentBuilderTests: XCTestCase {
    func testBuildsMessageIntentWithSenderAndConversationIdentifier() throws {
        let payload = try XCTUnwrap(
            ConversationPushPayload.from(userInfo: ConversationPushTestFixture.conversationUserInfo())
        )

        let intent = try XCTUnwrap(
            ConversationNotificationIntentBuilder().makeIntent(from: payload, avatar: nil)
        )

        XCTAssertEqual(intent.conversationIdentifier, "conv-123")
        XCTAssertEqual(intent.content, "Hi, I have a question")
        XCTAssertEqual(intent.sender?.displayName, "Jane Doe")
        XCTAssertEqual(intent.sender?.personHandle?.value, "participant-uuid")
        XCTAssertEqual(intent.outgoingMessageType, .outgoingMessageText)
        XCTAssertNil(intent.recipients)
    }

    func testReturnsNilWhenPreviewTextCannotBeDerived() throws {
        var userInfo = ConversationPushTestFixture.conversationUserInfo()
        var rover = try XCTUnwrap(userInfo["rover"] as? [String: Any])
        var reply = try XCTUnwrap(rover["reply"] as? [String: Any])
        reply["content"] = [["type": "image", "url": "https://example.com/image.jpg"]]
        rover["reply"] = reply
        userInfo["rover"] = rover

        let payload = try XCTUnwrap(ConversationPushPayload.from(userInfo: userInfo))
        XCTAssertNil(ConversationNotificationIntentBuilder().makeIntent(from: payload, avatar: nil))
    }
}
