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

import UIKit
import XCTest

@testable import RoverExperiences

/// Each `NavBarButton.Style` produces a `UIBarButtonItem` whose `primaryAction` fires the
/// supplied handler.
final class NavBarButtonItemTests: XCTestCase {
    private func makeItem(
        style: NavBarButton.Style,
        title: String? = nil,
        icon: NamedIcon? = nil,
        stringTable: StringTable = [:],
        onTap: @escaping () -> Void
    ) -> UIBarButtonItem {
        let navBarButton = NavBarButton(
            name: nil,
            placement: .trailing,
            style: style,
            title: title,
            icon: icon
        )
        return UIBarButtonItem(
            navBarButton: navBarButton,
            stringTable: stringTable,
            data: nil,
            urlParameters: [:],
            userInfo: [:],
            deviceContext: [:],
            onTap: onTap
        )
    }

    private func tap(_ item: UIBarButtonItem, file: StaticString = #filePath, line: UInt = #line) {
        guard let action = item.primaryAction else {
            XCTFail("Bar button item has no primaryAction to fire", file: file, line: line)
            return
        }
        action.performWithSender(item, target: nil)
    }

    func testDoneButtonFiresHandler() {
        var tapCount = 0
        let item = makeItem(style: .done) { tapCount += 1 }

        tap(item)

        XCTAssertEqual(tapCount, 1)
    }

    func testCloseButtonFiresHandler() {
        var tapCount = 0
        let item = makeItem(style: .close) { tapCount += 1 }

        tap(item)

        XCTAssertEqual(tapCount, 1)
    }

    func testCustomTitleButtonResolvesTitleAndFiresHandler() {
        var tapCount = 0
        let item = makeItem(
            style: .custom,
            title: "nav.reload",
            stringTable: ["en": ["nav.reload": "Reload"]]
        ) { tapCount += 1 }

        tap(item)

        XCTAssertEqual(item.title, "Reload")
        XCTAssertEqual(tapCount, 1)
    }

    func testCustomIconButtonFiresHandler() {
        var tapCount = 0
        let item = makeItem(
            style: .custom,
            icon: NamedIcon(symbolName: "arrow.clockwise", materialName: "refresh")
        ) { tapCount += 1 }

        tap(item)

        XCTAssertNotNil(item.image)
        XCTAssertEqual(tapCount, 1)
    }
}
