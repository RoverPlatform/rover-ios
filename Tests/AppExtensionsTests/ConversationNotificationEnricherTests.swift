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
import UserNotifications
import XCTest

@testable import RoverAppExtensions

final class ConversationNotificationEnricherTests: XCTestCase {
    func testReturnsUpdatedContentWhenIntentDonationAndContentUpdateSucceed() async throws {
        let payload = try XCTUnwrap(
            ConversationPushPayload.from(userInfo: ConversationPushTestFixture.conversationUserInfo())
        )
        let originalContent = UNMutableNotificationContent()
        originalContent.userInfo = ConversationPushTestFixture.conversationUserInfo()
        originalContent.threadIdentifier = "stale-thread"

        let updatedContent = UNMutableNotificationContent()
        updatedContent.title = "Jane Doe"
        updatedContent.body = "Hi, I have a question"
        let updater = UpdaterSpy(content: updatedContent)

        let enricher = ConversationNotificationEnricher(
            avatarLoader: AvatarLoaderStub(image: nil),
            donor: DonorSpy(),
            contentUpdater: updater,
            intentBuilder: ConversationNotificationIntentBuilder()
        )

        let result = await enricher.enrichedContent(payload: payload, from: originalContent)

        XCTAssertEqual(result?.title, "Jane Doe")
        XCTAssertEqual(result?.body, "Hi, I have a question")
        XCTAssertEqual(updater.receivedThreadIdentifiers, ["conv-123"])
    }

    func testReturnsNilWhenContentUpdateFails() async throws {
        let payload = try XCTUnwrap(
            ConversationPushPayload.from(userInfo: ConversationPushTestFixture.conversationUserInfo())
        )
        let originalContent = UNMutableNotificationContent()

        let enricher = ConversationNotificationEnricher(
            avatarLoader: AvatarLoaderStub(image: nil),
            donor: DonorSpy(),
            contentUpdater: ThrowingUpdater(),
            intentBuilder: ConversationNotificationIntentBuilder()
        )

        let result = await enricher.enrichedContent(payload: payload, from: originalContent)

        XCTAssertNil(result)
    }

    func testDoesNotLoadAvatarWhenIntentCannotBeBuilt() async throws {
        var userInfo = ConversationPushTestFixture.conversationUserInfo()
        var rover = try XCTUnwrap(userInfo["rover"] as? [String: Any])
        var reply = try XCTUnwrap(rover["reply"] as? [String: Any])
        reply["content"] = [["type": "image", "url": "https://example.com/image.jpg"]]
        rover["reply"] = reply
        userInfo["rover"] = rover

        let payload = try XCTUnwrap(ConversationPushPayload.from(userInfo: userInfo))
        let originalContent = UNMutableNotificationContent()
        let avatarLoader = AvatarLoaderSpy(image: nil)

        let enricher = ConversationNotificationEnricher(
            avatarLoader: avatarLoader,
            donor: DonorSpy(),
            contentUpdater: ThrowingUpdater(),
            intentBuilder: ConversationNotificationIntentBuilder()
        )

        let result = await enricher.enrichedContent(payload: payload, from: originalContent)

        XCTAssertNil(result)
        XCTAssertTrue(avatarLoader.receivedCalls.isEmpty)
    }
}
