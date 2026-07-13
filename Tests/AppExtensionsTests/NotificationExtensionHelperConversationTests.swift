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

import UserNotifications
import XCTest

@testable import RoverAppExtensions

final class NotificationExtensionHelperConversationTests: XCTestCase {
    override func tearDown() {
        ConversationPushTestFixture.clearDefaults()
        super.tearDown()
    }

    func testNotificationContentReturnsEnrichedContentForConversationPush() async {
        let helper = NotificationExtensionHelper(
            userDefaults: UserDefaults(suiteName: ConversationPushTestFixture.appGroup)!,
            conversationEnricher: ConversationEnricherSpy(result: stubUpdatedContent())
        )
        let request = ConversationPushTestFixture.request(
            userInfo: ConversationPushTestFixture.conversationUserInfo()
        )
        let bestAttemptContent = request.content.mutableCopy() as! UNMutableNotificationContent

        let deliveredContent = await helper.notificationContent(
            for: request,
            withContent: bestAttemptContent
        )

        XCTAssertEqual(deliveredContent.title, "Jane Doe")
    }

    func testNotificationContentReturnsEnrichedContentForConversationPushWithoutNotificationMetadata() async {
        let helper = NotificationExtensionHelper(
            userDefaults: UserDefaults(suiteName: ConversationPushTestFixture.appGroup)!,
            conversationEnricher: ConversationEnricherSpy(result: stubUpdatedContent())
        )
        let request = ConversationPushTestFixture.request(
            userInfo: ConversationPushTestFixture.conversationUserInfoWithoutNotification()
        )
        let bestAttemptContent = request.content.mutableCopy() as! UNMutableNotificationContent

        let deliveredContent = await helper.notificationContent(
            for: request,
            withContent: bestAttemptContent
        )

        XCTAssertEqual(deliveredContent.title, "Jane Doe")
    }

    func testNotificationContentFallsBackToOriginalContentWhenEnrichmentFails() async {
        let helper = NotificationExtensionHelper(
            userDefaults: UserDefaults(suiteName: ConversationPushTestFixture.appGroup)!,
            conversationEnricher: ConversationEnricherSpy(result: nil)
        )
        let request = ConversationPushTestFixture.request(
            userInfo: ConversationPushTestFixture.conversationUserInfo()
        )
        let bestAttemptContent = request.content.mutableCopy() as! UNMutableNotificationContent

        let deliveredContent = await helper.notificationContent(
            for: request,
            withContent: bestAttemptContent
        )

        XCTAssertIdentical(deliveredContent as AnyObject?, bestAttemptContent)
    }
}
