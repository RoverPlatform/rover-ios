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

final class NotificationTapBehaviorDecodingTests: XCTestCase {
    // MARK: - Valid payloads

    func testOpenAppDecodes() throws {
        let behavior = try decodeTapBehavior(
            """
            {"__typename": "OpenAppNotificationTapBehavior"}
            """
        )
        XCTAssertEqual(behavior, .openApp)
    }

    func testOpenURLWithValidURLDecodes() throws {
        let behavior = try decodeTapBehavior(
            """
            {"__typename": "OpenURLNotificationTapBehavior", "url": "myapp://deep/link"}
            """
        )
        XCTAssertEqual(behavior, .openURL(url: URL(string: "myapp://deep/link")!))
    }

    func testPresentWebsiteWithValidURLDecodes() throws {
        let behavior = try decodeTapBehavior(
            """
            {"__typename": "PresentWebsiteNotificationTapBehavior", "url": "https://example.com"}
            """
        )
        XCTAssertEqual(behavior, .presentWebsite(url: URL(string: "https://example.com")!))
    }

    // MARK: - Graceful fallback for blank deep link URLs (SDK-344)

    func testOpenURLWithEmptyURLFallsBackToOpenApp() throws {
        let behavior = try decodeTapBehavior(
            """
            {"__typename": "OpenURLNotificationTapBehavior", "url": ""}
            """
        )
        XCTAssertEqual(behavior, .openApp)
    }

    func testOpenURLWithWhitespaceURLFallsBackToOpenApp() throws {
        let behavior = try decodeTapBehavior(
            """
            {"__typename": "OpenURLNotificationTapBehavior", "url": "   "}
            """
        )
        XCTAssertEqual(behavior, .openApp)
    }

    func testOpenURLWithMissingURLKeyFallsBackToOpenApp() throws {
        let behavior = try decodeTapBehavior(
            """
            {"__typename": "OpenURLNotificationTapBehavior"}
            """
        )
        XCTAssertEqual(behavior, .openApp)
    }

    func testOpenURLWithNullURLFallsBackToOpenApp() throws {
        let behavior = try decodeTapBehavior(
            """
            {"__typename": "OpenURLNotificationTapBehavior", "url": null}
            """
        )
        XCTAssertEqual(behavior, .openApp)
    }

    func testPresentWebsiteWithEmptyURLFallsBackToOpenApp() throws {
        let behavior = try decodeTapBehavior(
            """
            {"__typename": "PresentWebsiteNotificationTapBehavior", "url": ""}
            """
        )
        XCTAssertEqual(behavior, .openApp)
    }

    func testOpenURLWithUnparseableURLFallsBackToOpenApp() throws {
        // A malformed IPv6 host literal is one of the few strings URL(string:) still
        // rejects under RFC 3986 parsing, covering the URL(string:) == nil branch.
        let behavior = try decodeTapBehavior(
            """
            {"__typename": "OpenURLNotificationTapBehavior", "url": "https://[fe80::3221:5634:6544]invalid:433/"}
            """
        )
        XCTAssertEqual(behavior, .openApp)
    }

    func testPresentWebsiteWithMissingURLKeyFallsBackToOpenApp() throws {
        let behavior = try decodeTapBehavior(
            """
            {"__typename": "PresentWebsiteNotificationTapBehavior"}
            """
        )
        XCTAssertEqual(behavior, .openApp)
    }

    func testPresentWebsiteWithNullURLFallsBackToOpenApp() throws {
        let behavior = try decodeTapBehavior(
            """
            {"__typename": "PresentWebsiteNotificationTapBehavior", "url": null}
            """
        )
        XCTAssertEqual(behavior, .openApp)
    }

    func testOpenURLWithWrongTypeURLFallsBackToOpenApp() throws {
        let behavior = try decodeTapBehavior(
            """
            {"__typename": "OpenURLNotificationTapBehavior", "url": 42}
            """
        )
        XCTAssertEqual(behavior, .openApp)
    }

    // MARK: - Round-trip encoding

    func testFallenBackBehaviorEncodesAsOpenApp() throws {
        let decoded = try decodeTapBehavior(
            """
            {"__typename": "OpenURLNotificationTapBehavior", "url": ""}
            """
        )
        let encoded = try JSONEncoder.default.encode(decoded)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        XCTAssertEqual(object["__typename"] as? String, "OpenAppNotificationTapBehavior")
        XCTAssertNil(object["url"])
    }

    // MARK: - Unknown type names still fail

    func testUnknownTypeNameThrows() {
        XCTAssertThrowsError(
            try decodeTapBehavior(
                """
                {"__typename": "SomeUnknownTapBehavior"}
                """
            )
        )
    }

    // MARK: - Full notification payload

    func testNotificationWithEmptyDeepLinkURLDecodes() throws {
        let json = """
            {
                "id": "deadbeef-0000-0000-0000-000000000000",
                "campaignID": "1234",
                "title": "Go Birds",
                "body": "Tap for the latest",
                "attachment": null,
                "tapBehavior": {"__typename": "OpenURLNotificationTapBehavior", "url": ""},
                "deliveredAt": "2026-08-09T12:00:00.000+00:00",
                "expiresAt": null,
                "isRead": false,
                "isNotificationCenterEnabled": true,
                "isDeleted": false,
                "conversionTags": []
            }
            """
        let notification = try JSONDecoder.default.decode(
            Notification.self,
            from: Data(json.utf8)
        )
        XCTAssertEqual(notification.tapBehavior, .openApp)
        XCTAssertEqual(notification.id, "deadbeef-0000-0000-0000-000000000000")
        XCTAssertEqual(notification.campaignID, "1234")
    }

    // MARK: - Helpers

    private func decodeTapBehavior(_ json: String) throws -> NotificationTapBehavior {
        try JSONDecoder.default.decode(NotificationTapBehavior.self, from: Data(json.utf8))
    }
}
