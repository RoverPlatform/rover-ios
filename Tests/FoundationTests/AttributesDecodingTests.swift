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

import RoverFoundation
import XCTest

final class AttributesDecodingTests: XCTestCase {
    func testDecimalReadsBackAsDoubleThroughJSON() throws {
        let decoded = try JSONDecoder().decode(Attributes.self, from: JSONEncoder().encode(Self.decimalAttributes))

        assertDecimalsReadBack(decoded)
    }

    func testDecimalReadsBackAsDoubleThroughPropertyList() throws {
        let data = try PropertyListEncoder().encode(Self.decimalAttributes)
        let decoded = try PropertyListDecoder().decode(Attributes.self, from: data)

        assertDecimalsReadBack(decoded)
    }

    // Int is tried before Double, so whole numbers keep the type they decoded as before.
    func testWholeNumbersStillReadBackAsInt() throws {
        let attributes: Attributes = ["count": 2, "rounded": 2.0]

        for decoded in try Self.roundTrips(attributes) {
            XCTAssertEqual(decoded.rawValue["count"] as? Int, 2)
            XCTAssertEqual(decoded.rawValue["rounded"] as? Int, 2)
        }
    }

    // A decimal used to fail the whole decode, so every other key was lost with it.
    func testDecimalDoesNotDropOtherKeys() throws {
        let attributes: Attributes = ["ticketmasterID": "abc123", "spend": 12.5, "isMember": true]

        for decoded in try Self.roundTrips(attributes) {
            XCTAssertEqual(decoded.rawValue["ticketmasterID"] as? String, "abc123")
            XCTAssertEqual(decoded.rawValue["spend"] as? Double, 12.5)
            XCTAssertEqual(decoded.rawValue["isMember"] as? Bool, true)
        }
    }

    private static let decimalAttributes: Attributes = ["price": 9.99, "nested": ["rate": 0.5]]

    private static func roundTrips(_ attributes: Attributes) throws -> [Attributes] {
        let json = try JSONDecoder().decode(Attributes.self, from: JSONEncoder().encode(attributes))
        let plist = try PropertyListDecoder().decode(Attributes.self, from: PropertyListEncoder().encode(attributes))
        return [json, plist]
    }

    private func assertDecimalsReadBack(_ decoded: Attributes, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(decoded.rawValue["price"] as? Double, 9.99, file: file, line: line)
        let nested = decoded.rawValue["nested"] as? Attributes
        XCTAssertEqual(nested?.rawValue["rate"] as? Double, 0.5, file: file, line: line)
    }
}
