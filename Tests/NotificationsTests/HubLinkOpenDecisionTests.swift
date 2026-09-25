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

/// The rule for a link tapped in a Post or Conversation (SDK-425): only a deep link
/// into THIS app, from a surface that is presented modally, dismisses before opening.
/// Everything else opens where the user is.
final class HubLinkOpenDecisionTests: XCTestCase {
    /// The host app registers `rv-myapp` (Rover's) and `myapp` (its own) schemes.
    private let classifier = HubLinkOpenClassifier(
        isRoverLink: { url in url.scheme?.lowercased() == "rv-myapp" },
        hostAppURLSchemes: ["rv-myapp", "myapp"]
    )

    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    // MARK: - Web links

    func testHTTPSPresentsTheInAppBrowserRegardlessOfSurface() {
        XCTAssertEqual(classifier.decide(url("https://example.com/page"), canDismiss: true), .presentInAppBrowser)
        XCTAssertEqual(classifier.decide(url("https://example.com/page"), canDismiss: false), .presentInAppBrowser)
        XCTAssertEqual(classifier.decide(url("http://example.com"), canDismiss: true), .presentInAppBrowser)
    }

    func testWebLinksNeverConsultTheRouter() {
        let classifier = HubLinkOpenClassifier(
            isRoverLink: { _ in
                XCTFail("a web link must not materialize a router action")
                return true
            },
            hostAppURLSchemes: ["myapp"]
        )
        XCTAssertEqual(classifier.decide(url("https://myapp.example.com/posts/1"), canDismiss: true), .presentInAppBrowser)
    }

    // MARK: - Rover links

    func testRoverLinkOpensInPlaceEvenWhenModal() {
        // The SDK's own routing presents the destination over the current surface,
        // and dismissing first would undo the navigation it queues.
        XCTAssertEqual(classifier.decide(url("rv-myapp://posts/abc"), canDismiss: true), .openInPlace)
    }

    // MARK: - Schemes that leave the app

    func testMailToTelAndSMSOpenInPlace() {
        for link in ["mailto:fan@example.com", "tel:+15555550123", "sms:+15555550123"] {
            XCTAssertEqual(classifier.decide(url(link), canDismiss: true), .openInPlace, link)
        }
    }

    func testAnotherAppsSchemeOpensInPlace() {
        // Not registered by this app, so it cannot land behind this app's modal.
        XCTAssertEqual(classifier.decide(url("spotify://track/123"), canDismiss: true), .openInPlace)
    }

    // MARK: - This app's own deep links

    func testThisAppsDeepLinkDismissesThenOpensWhenModal() {
        XCTAssertEqual(classifier.decide(url("myapp://tickets/next-game"), canDismiss: true), .dismissThenOpen)
    }

    func testThisAppsDeepLinkOpensInPlaceWhenThereIsNothingToDismiss() {
        // Embedded in a tab (FanReach) or pushed: the destination opens on top.
        XCTAssertEqual(classifier.decide(url("myapp://tickets/next-game"), canDismiss: false), .openInPlace)
    }

    func testOnlyADismissableSurfaceWithThisAppsSchemeConsultsTheRouter() {
        // The router's answer only matters once the link could land behind a modal, so
        // an embedded surface, or another app's scheme, never asks it.
        let classifier = HubLinkOpenClassifier(
            isRoverLink: { url in
                XCTFail("the router must not be consulted for \(url)")
                return true
            },
            hostAppURLSchemes: ["rv-myapp", "myapp"]
        )
        XCTAssertEqual(classifier.decide(url("rv-myapp://posts/abc"), canDismiss: false), .openInPlace)
        XCTAssertEqual(classifier.decide(url("myapp://tickets/next-game"), canDismiss: false), .openInPlace)
        XCTAssertEqual(classifier.decide(url("spotify://track/123"), canDismiss: true), .openInPlace)
    }

    func testSchemeComparisonIsCaseInsensitive() {
        XCTAssertEqual(classifier.decide(url("MyApp://tickets/next-game"), canDismiss: true), .dismissThenOpen)
        XCTAssertEqual(classifier.decide(url("HTTPS://example.com"), canDismiss: true), .presentInAppBrowser)
    }

    func testRelativeURLWithoutSchemeOpensInPlace() {
        XCTAssertEqual(classifier.decide(url("/relative/path"), canDismiss: true), .openInPlace)
    }

    // MARK: - Info.plist

    func testHostAppURLSchemesAreReadLowercasedFromCFBundleURLTypes() throws {
        let plist: [String: Any] = [
            "CFBundleURLTypes": [
                ["CFBundleURLSchemes": ["MyApp", "myapp-beta"]],
                ["CFBundleURLName": "no schemes here"],
                ["CFBundleURLSchemes": ["rv-myapp"]]
            ]
        ]
        let bundle = try makeBundle(infoDictionary: plist)
        XCTAssertEqual(
            HubLinkOpenClassifier.hostAppURLSchemes(from: bundle),
            ["myapp", "myapp-beta", "rv-myapp"]
        )
    }

    func testBundleWithoutURLTypesRegistersNoSchemes() {
        // The test bundle declares no URL types of its own.
        XCTAssertEqual(HubLinkOpenClassifier.hostAppURLSchemes(from: Bundle(for: Self.self)), [])
    }

    /// Writes a throwaway bundle on disk whose Info.plist is `infoDictionary`.
    private func makeBundle(infoDictionary: [String: Any]) throws -> Bundle {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Fixture.bundle")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: infoDictionary, format: .xml, options: 0)
        try data.write(to: directory.appendingPathComponent("Info.plist"))
        return try XCTUnwrap(Bundle(url: directory))
    }
}
