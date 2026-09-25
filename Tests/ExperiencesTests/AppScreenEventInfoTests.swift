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

import Foundation
import XCTest

@testable import RoverData
@testable import RoverExperiences

/// Pins the wire shape of the two App Screens analytics events: their names,
/// namespace, and the exact attribute set — asserted as whole dictionaries, so an
/// attribute added by accident fails here rather than reaching the Rover cloud.
/// The data export allowlist keys off these strings, so a rename is a breaking
/// change and must fail a test rather than a customer's dashboard.
final class AppScreenEventInfoTests: XCTestCase {

    /// The event's attributes as a plain `[String: String]`. Returns `nil` if any
    /// value is not a string, so a non-string attribute cannot pass unnoticed.
    private func attributes(_ event: EventInfo) -> [String: String]? {
        guard let attributes = event.attributes else {
            return nil
        }
        return attributes.rawValue as? [String: String]
    }

    // MARK: - App Screen Viewed

    /// Name, namespace, and the whole attribute dictionary: `screenURL` alone.
    func testAppScreenViewedShape() throws {
        let url = try XCTUnwrap(URL(string: "https://app.example.com/a/player-detail?id=dez-carter"))
        let event = EventInfo.appScreenViewed(screenURL: url)

        XCTAssertEqual(event.name, "App Screen Viewed")
        XCTAssertEqual(event.namespace, "rover")
        XCTAssertEqual(
            attributes(event),
            ["screenURL": "https://app.example.com/a/player-detail?id=dez-carter"]
        )
    }

    /// The URL rides along verbatim: query and explicit port included, nothing
    /// normalized away, and no derived template attribute alongside it.
    func testAppScreenViewedReportsTheURLVerbatim() throws {
        let url = try XCTUnwrap(URL(string: "https://app.example.com:8443/a/player-detail?id=3&tab=stats"))
        let event = EventInfo.appScreenViewed(screenURL: url)

        XCTAssertEqual(
            attributes(event),
            ["screenURL": "https://app.example.com:8443/a/player-detail?id=3&tab=stats"]
        )
    }

    // MARK: - App Screen Link Clicked

    /// Name, namespace, and the whole attribute dictionary: `screenURL` + `linkURL`.
    func testAppScreenLinkClickedShape() throws {
        let screenURL = try XCTUnwrap(URL(string: "https://app.example.com/a/home?tab=news"))
        let linkURL = try XCTUnwrap(URL(string: "https://app.example.com/a/player-detail?id=dez-carter"))
        let event = EventInfo.appScreenLinkClicked(screenURL: screenURL, linkURL: linkURL)

        XCTAssertEqual(event.name, "App Screen Link Clicked")
        XCTAssertEqual(event.namespace, "rover")
        XCTAssertEqual(
            attributes(event),
            [
                "screenURL": "https://app.example.com/a/home?tab=news",
                "linkURL": "https://app.example.com/a/player-detail?id=dez-carter"
            ]
        )
    }

    /// A deep link or `mailto:` is reported verbatim — the factory never coerces the
    /// link URL, and records nothing about which bridge message carried the tap.
    func testAppScreenLinkClickedKeepsNonHTTPLinkURL() throws {
        let screenURL = try XCTUnwrap(URL(string: "https://app.example.com/a/home"))
        let linkURL = try XCTUnwrap(URL(string: "mytestbench://tab/inbox"))
        let event = EventInfo.appScreenLinkClicked(screenURL: screenURL, linkURL: linkURL)

        XCTAssertEqual(
            attributes(event),
            [
                "screenURL": "https://app.example.com/a/home",
                "linkURL": "mytestbench://tab/inbox"
            ]
        )
    }
}
