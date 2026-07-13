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

@testable import RoverNotifications

final class StringAttributedLinksTests: XCTestCase {

    // MARK: - Link detection

    func testHTTPSURL_producesLinkAttribute() {
        let input = "Visit https://example.com today"
        let result = input.attributedForLinks(whiteLinks: false)

        let linkRuns = result.runs.filter { $0.link != nil }
        XCTAssertEqual(linkRuns.count, 1)
        XCTAssertEqual(linkRuns.first.flatMap { $0.link }, URL(string: "https://example.com"))
    }

    func testBareDomain_producesLinkAttribute() {
        let input = "Visit example.com today"
        let result = input.attributedForLinks(whiteLinks: false)

        let linkRuns = result.runs.filter { $0.link != nil }
        XCTAssertEqual(linkRuns.count, 1, "Bare domain should produce exactly one link run")
    }

    func testPhoneNumber_producesTelURL() {
        let input = "Call (416) 555-0100"
        let result = input.attributedForLinks(whiteLinks: false)

        let linkRuns = result.runs.filter { $0.link != nil }
        XCTAssertEqual(linkRuns.count, 1)
        let url = linkRuns.first.flatMap { $0.link }
        XCTAssertEqual(url?.scheme, "tel")
        XCTAssertTrue(url?.absoluteString.contains("5550100") == true)
    }

    func testEmailAddress_producesMailtoURL() {
        let input = "Email hello@example.com please"
        let result = input.attributedForLinks(whiteLinks: false)

        let linkRuns = result.runs.filter { $0.link != nil }
        XCTAssertEqual(linkRuns.count, 1)
        XCTAssertEqual(linkRuns.first.flatMap { $0.link }, URL(string: "mailto:hello@example.com"))
    }

    func testMultipleLinks_allGetLinkAttribute() {
        let input = "See https://example.com or call (416) 555-0100"
        let result = input.attributedForLinks(whiteLinks: false)

        let linkRuns = result.runs.filter { $0.link != nil }
        XCTAssertEqual(linkRuns.count, 2)
        let schemes = Set(linkRuns.compactMap { $0.link?.scheme })
        XCTAssertEqual(schemes, ["https", "tel"])
    }

    func testNoLinks_returnsPlainAttributedString() {
        let input = "No links here at all"
        let result = input.attributedForLinks(whiteLinks: false)

        let linkRuns = result.runs.filter { $0.link != nil }
        XCTAssertTrue(linkRuns.isEmpty)
    }
}
