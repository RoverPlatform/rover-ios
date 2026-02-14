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

import SwiftUI
import XCTest

@testable import RoverNotifications

final class ColorHexTests: XCTestCase {

    func testValidHexWithHash() {
        let color = Color(hex: "#FF5733")
        XCTAssertNotNil(color)
    }

    func testValidHexWithoutHash() {
        let color = Color(hex: "FF5733")
        XCTAssertNotNil(color)
    }

    func testBlackColor() {
        let color = Color(hex: "#000000")
        XCTAssertNotNil(color)
    }

    func testWhiteColor() {
        let color = Color(hex: "#FFFFFF")
        XCTAssertNotNil(color)
    }

    func testLowercaseHex() {
        let color = Color(hex: "#ff5733")
        XCTAssertNotNil(color)
    }

    func testInvalidHexTooShort() {
        let color = Color(hex: "#FFF")
        XCTAssertNil(color)
    }

    func testInvalidHexTooLong() {
        let color = Color(hex: "#FF5733AA")
        XCTAssertNil(color)
    }

    func testInvalidHexCharacters() {
        let color = Color(hex: "#GGGGGG")
        XCTAssertNil(color)
    }

    func testEmptyString() {
        let color = Color(hex: "")
        XCTAssertNil(color)
    }
}
