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

final class NotificationExtensionHelperContentTests: XCTestCase {
    override func tearDown() {
        ConversationPushTestFixture.clearDefaults()
        super.tearDown()
    }

    func testDidReceiveWithContentHandlerDeliversGenericRoverPush() {
        let helper = NotificationExtensionHelper(appGroup: ConversationPushTestFixture.appGroup)!
        let request = ConversationPushTestFixture.request(
            userInfo: ConversationPushTestFixture.genericRoverUserInfo()
        )
        let bestAttemptContent = request.content.mutableCopy() as! UNMutableNotificationContent
        let defaults = UserDefaults(suiteName: ConversationPushTestFixture.appGroup)!
        let expectation = expectation(description: "content handler called")

        helper.didReceive(request, withContent: bestAttemptContent) { deliveredContent in
            XCTAssertIdentical(deliveredContent as AnyObject?, bestAttemptContent)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
        XCTAssertNotNil(defaults.object(forKey: "io.rover.lastReceivedNotification"))
    }

    func testNotificationContentReturnsMutableContentForInvalidPayload() async {
        let helper = NotificationExtensionHelper(appGroup: ConversationPushTestFixture.appGroup)!
        let request = ConversationPushTestFixture.request(userInfo: ["not-rover": true])
        let bestAttemptContent = request.content.mutableCopy() as! UNMutableNotificationContent

        let deliveredContent = await helper.notificationContent(
            for: request,
            withContent: bestAttemptContent
        )

        XCTAssertIdentical(deliveredContent as AnyObject, bestAttemptContent)
    }

    func testDidReceiveRemainsBackwardsCompatible() {
        let helper = NotificationExtensionHelper(appGroup: ConversationPushTestFixture.appGroup)!
        let request = ConversationPushTestFixture.request(
            userInfo: ConversationPushTestFixture.genericRoverUserInfo()
        )
        let bestAttemptContent = request.content.mutableCopy() as! UNMutableNotificationContent

        XCTAssertTrue(helper.didReceive(request, withContent: bestAttemptContent))
    }
}
