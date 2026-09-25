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
import RoverFoundation
import XCTest

@_spi(BenchSupport) @testable import RoverExperiences

final class ToolbarItemCompatibilityTests: XCTestCase {
    func testBelowRedesignAlwaysUsesCompatibilityChrome() {
        for requiresCompatibility in [true, false] {
            for ignoresOptOut in [true, false] {
                XCTAssertTrue(
                    resolveToolbarItemsRequireCompatibilityChrome(
                        isRedesignAvailable: false,
                        requiresCompatibility: requiresCompatibility,
                        ignoresOptOut: ignoresOptOut
                    ),
                    "There is no native glass background below iOS 26"
                )
            }
        }
    }

    func testRedesignWithoutOptOutIsNative() {
        XCTAssertFalse(
            resolveToolbarItemsRequireCompatibilityChrome(
                isRedesignAvailable: true,
                requiresCompatibility: false,
                ignoresOptOut: false
            )
        )
    }

    func testOptOutPlistUsesCompatibilityChrome() {
        XCTAssertTrue(
            resolveToolbarItemsRequireCompatibilityChrome(
                isRedesignAvailable: true,
                requiresCompatibility: true,
                ignoresOptOut: false
            )
        )
    }

    func testIgnoreSolariumOptOutDefeatsTheOptOutPlist() {
        XCTAssertFalse(
            resolveToolbarItemsRequireCompatibilityChrome(
                isRedesignAvailable: true,
                requiresCompatibility: true,
                ignoresOptOut: true
            ),
            "The hidden default makes the frameworks ignore the plist opt-out"
        )
    }

    // MARK: - Bench SPI

    func testTheBenchSPIReportsTheSDKsOwnResolution() {
        // Rover Bench's Liquid Glass settings row shows the *effective* state of a setting
        // whose stored value is only a request, and it has to be the same answer the SDK's
        // own chrome is drawn from — not a second copy of a precedence rule that exists
        // because the real one is surprising. This asserts the SPI is a window onto the
        // module's value rather than a reimplementation of it.
        Rover.initialize(assemblers: [])
        defer { Rover.deinitialize() }

        XCTAssertEqual(
            Rover.shared.toolbarItemsRequireCompatibilityChrome,
            toolbarItemsRequireCompatibilityChrome
        )
    }
}
