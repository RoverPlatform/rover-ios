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

@testable import RoverAppExtensions

final class ConversationPushPayloadTests: XCTestCase {
    func testDecodesMinimalConversationPush() throws {
        let payload = try XCTUnwrap(
            ConversationPushPayload.from(userInfo: ConversationPushTestFixture.conversationUserInfo())
        )

        XCTAssertEqual(payload.rover.conversation.id, "conv-123")
        XCTAssertEqual(payload.rover.participant.id, "participant-uuid")
        XCTAssertEqual(payload.rover.participant.name, "Jane Doe")
        XCTAssertEqual(payload.rover.participant.avatarURL?.absoluteString, "https://example.com/avatar.jpg")
    }

    func testReturnsNilWhenRequiredFieldsAreMissing() {
        var userInfo = ConversationPushTestFixture.conversationUserInfo()
        userInfo["rover"] = [
            "conversation": ["id": "conv-123"],
            "reply": ["content": []],
        ]

        XCTAssertNil(ConversationPushPayload.from(userInfo: userInfo))
    }
}
