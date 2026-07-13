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

final class NotificationExtensionHelperRoverPushTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ConversationPushTestFixture.clearDefaults()
    }

    override func tearDown() {
        ConversationPushTestFixture.clearDefaults()
        super.tearDown()
    }

    func testDidReceiveReturnsTrueForGenericRoverPush() {
        let helper = NotificationExtensionHelper(appGroup: ConversationPushTestFixture.appGroup)!
        let content = UNMutableNotificationContent()
        content.userInfo = ConversationPushTestFixture.genericRoverUserInfo()

        XCTAssertTrue(
            helper.didReceive(
                ConversationPushTestFixture.request(userInfo: content.userInfo),
                withContent: content
            ))
    }

    func testDidReceiveDoesNotClearReceiptForConversationPushWithoutNotificationBlock() {
        // A conversation push carries rover.conversation but no rover.notification.
        // If a campaign push was received immediately before, its receipt must survive —
        // clearing it here would misattribute the subsequent campaign open as non-influenced.
        let helper = NotificationExtensionHelper(appGroup: ConversationPushTestFixture.appGroup)!
        let defaults = UserDefaults(suiteName: ConversationPushTestFixture.appGroup)!
        let existingReceipt = Data([0x01])
        defaults.set(existingReceipt, forKey: "io.rover.lastReceivedNotification")

        let content = UNMutableNotificationContent()
        content.userInfo = ConversationPushTestFixture.conversationUserInfoWithoutNotification()

        XCTAssertFalse(
            helper.didReceive(
                ConversationPushTestFixture.request(userInfo: content.userInfo),
                withContent: content
            ))
        XCTAssertEqual(
            defaults.data(forKey: "io.rover.lastReceivedNotification"), existingReceipt,
            "campaign receipt must be preserved when a conversation push is processed")
    }

    func testDidReceiveReturnsFalseAndClearsStateForInvalidPayload() {
        let helper = NotificationExtensionHelper(appGroup: ConversationPushTestFixture.appGroup)!
        let defaults = UserDefaults(suiteName: ConversationPushTestFixture.appGroup)!
        defaults.set(Data([0x01]), forKey: "io.rover.lastReceivedNotification")

        let content = UNMutableNotificationContent()
        content.userInfo = ["not-rover": true]

        XCTAssertFalse(
            helper.didReceive(
                ConversationPushTestFixture.request(userInfo: content.userInfo),
                withContent: content
            ))
        XCTAssertNil(defaults.object(forKey: "io.rover.lastReceivedNotification"))
    }

    func testDidReceiveClearsStateForMalformedRoverPayloadThatIsNotAConversationPush() {
        let helper = NotificationExtensionHelper(appGroup: ConversationPushTestFixture.appGroup)!
        let defaults = UserDefaults(suiteName: ConversationPushTestFixture.appGroup)!
        defaults.set(Data([0x01]), forKey: "io.rover.lastReceivedNotification")

        let content = UNMutableNotificationContent()
        content.userInfo = [
            "rover": [
                "unknown": true
            ]
        ]

        XCTAssertFalse(
            helper.didReceive(
                ConversationPushTestFixture.request(userInfo: content.userInfo),
                withContent: content
            ))
        XCTAssertNil(defaults.object(forKey: "io.rover.lastReceivedNotification"))
    }
}
