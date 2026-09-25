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
final class AppScreensPageRegistryTests: XCTestCase {
    private func address(_ path: String) -> AppScreenAddress {
        AppScreenAddress(rawURL: URL(string: "https://testbench.rover.io/a/\(path)")!)!
    }

    func testPushMarksOnStackAndNotEphemeral() {
        let registry = AppScreensPageRegistry()
        let detail = address("detail")

        XCTAssertFalse(registry.didPush(detail))
        XCTAssertTrue(registry.isOnStack(detail))
        XCTAssertFalse(registry.isWarm(detail))
    }

    func testPopOfWarmTemplateKeepsItWarmOffStack() {
        let registry = AppScreensPageRegistry()
        let detail = address("detail")
        registry.didPush(detail)

        XCTAssertEqual(registry.didPop(detail), .keptWarm)
        XCTAssertFalse(registry.isOnStack(detail))
        XCTAssertTrue(registry.isWarm(detail))
    }

    func testRepushReusesWarmSession() {
        let registry = AppScreensPageRegistry()
        let detail = address("detail")
        registry.didPush(detail)
        registry.didPop(detail)

        // Second push is a warm reuse, not ephemeral, and consumes the warm mark.
        XCTAssertFalse(registry.didPush(detail))
        XCTAssertFalse(registry.isWarm(detail))
        XCTAssertTrue(registry.isOnStack(detail))
    }

    func testDetailToSameDetailIsEphemeralAndTornDownOnPop() {
        let registry = AppScreensPageRegistry()
        let detail = address("detail")

        XCTAssertFalse(registry.didPush(detail))  // first, warm
        XCTAssertTrue(registry.didPush(detail))  // second onto same template -> ephemeral

        XCTAssertEqual(registry.didPop(detail), .tornDown)  // ephemeral top torn down
        XCTAssertTrue(registry.isOnStack(detail))  // underlying still on stack
        XCTAssertEqual(registry.didPop(detail), .keptWarm)  // underlying kept warm
    }

    func testPopOfUnknownAddressTearsDown() {
        let registry = AppScreensPageRegistry()
        XCTAssertEqual(registry.didPop(address("ghost")), .tornDown)
    }
}
