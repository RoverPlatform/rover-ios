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

@testable import RoverExperiences

@MainActor
final class AppScreenAddressTests: XCTestCase {
    private func url(_ string: String) -> URL { URL(string: string)! }

    func testCanonicalizationCoercesSchemeToHTTPS() {
        let address = AppScreenAddress(rawURL: url("app://Testbench.Rover.io/a/Detail?id=1#frag"))
        XCTAssertEqual(address?.url.absoluteString, "https://testbench.rover.io/a/Detail")
    }

    func testCanonicalizationPreservesHTTPForLocalDev() {
        let address = AppScreenAddress(rawURL: url("http://localhost:4000/a/home?x=1"))
        XCTAssertEqual(address?.url.absoluteString, "http://localhost:4000/a/home")
    }

    func testCanonicalizationPreservesUppercaseHTTPSchemeForLocalDev() {
        let address = AppScreenAddress(rawURL: url("HTTP://localhost:4000/a/home?x=1"))
        XCTAssertEqual(address?.url.absoluteString, "http://localhost:4000/a/home")
    }

    func testSameTemplateDifferentQueryAreEqual() {
        let first = AppScreenAddress(rawURL: url("https://testbench.rover.io/a/detail?id=1"))
        let second = AppScreenAddress(rawURL: url("https://testbench.rover.io/a/detail?id=2"))
        XCTAssertEqual(first, second)
        XCTAssertEqual(first?.hashValue, second?.hashValue)
    }

    func testIsAppScreenURLIsHostAndPathAndCaseInsensitive() {
        let target = url("https://testbench.rover.io/a/home")
        XCTAssertTrue(target.isAppScreenURL(allowedHosts: ["testbench.rover.io"]))
        XCTAssertTrue(target.isAppScreenURL(allowedHosts: ["TESTBENCH.ROVER.IO"]))
        XCTAssertFalse(target.isAppScreenURL(allowedHosts: ["other.rover.io"]))
        XCTAssertFalse(url("https://testbench.rover.io/about").isAppScreenURL(allowedHosts: ["testbench.rover.io"]))
    }

    func testIsAppScreenURLAcceptsBareAppScreensRoot() {
        // The App Screens root `/a` is valid, matching ExperienceURLClassifier / AppScreenAddress.
        XCTAssertTrue(url("https://testbench.rover.io/a").isAppScreenURL(allowedHosts: ["testbench.rover.io"]))
        // A path merely starting with the letters "/a" (but not the `/a` component) is not.
        XCTAssertFalse(url("https://testbench.rover.io/about").isAppScreenURL(allowedHosts: ["testbench.rover.io"]))
    }

    func testNonAppScreenPathReturnsNil() {
        XCTAssertNil(AppScreenAddress(rawURL: url("https://testbench.rover.io/about")))
    }

    func testHostlessURLReturnsNil() {
        XCTAssertNil(AppScreenAddress(rawURL: URL(fileURLWithPath: "/a/home")))
    }
}
