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

@testable import RoverData

final class EventCacheDecodingTests: XCTestCase {
    // The event cache is read back as one [Event] array with PropertyListDecoder, so a
    // single event that fails to decode used to drop every queued event.
    func testCacheWithADecimalAttributeKeepsEveryEvent() throws {
        let context = try JSONDecoder().decode(Context.self, from: Data("{}".utf8))
        let events = [
            Event(name: "Purchase", context: context, attributes: ["price": 9.99]),
            Event(name: "App Opened", context: context)
        ]

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode(events)
        let restored = try PropertyListDecoder().decode([Event].self, from: data)

        XCTAssertEqual(restored.map(\.name), ["Purchase", "App Opened"])
        XCTAssertEqual(restored.first?.attributes?.rawValue["price"] as? Double, 9.99)
    }
}
