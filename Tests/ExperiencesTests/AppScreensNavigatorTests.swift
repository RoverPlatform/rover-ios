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
final class AppScreensNavigatorTests: XCTestCase {
    private func address(_ string: String) -> AppScreenAddress {
        AppScreenAddress(rawURL: URL(string: string)!)!
    }

    func testPushForwardsAddressAndRequest() {
        var pushedAddresses: [AppScreenAddress] = []
        var pushedRequests: [URLRequest?] = []
        let navigator = AppScreensNavigator(
            push: { address, request in
                pushedAddresses.append(address)
                pushedRequests.append(request)
            },
            presentSheet: { _, _, _ in },
            dismissRoot: {}
        )
        let target = address("https://testbench.rover.io/a/detail")
        navigator.pushScreen(address: target, targetRequest: nil)

        XCTAssertEqual(pushedAddresses, [target])
        XCTAssertEqual(pushedRequests.count, 1)
        XCTAssertNil(pushedRequests.first ?? nil)
    }

    func testPresentSheetForwards() {
        var sheeted: [AppScreenAddress] = []
        let navigator = AppScreensNavigator(
            push: { _, _ in },
            presentSheet: { address, _, _ in sheeted.append(address) },
            dismissRoot: {}
        )
        let target = address("https://testbench.rover.io/a/sheet")
        navigator.presentSheet(address: target, targetRequest: nil, sheetToken: AppScreensToken())

        XCTAssertEqual(sheeted, [target])
    }

    func testDismissForwards() {
        var dismissed = false
        let navigator = AppScreensNavigator(
            push: { _, _ in },
            presentSheet: { _, _, _ in },
            dismissRoot: { dismissed = true }
        )
        navigator.dismissRoot()
        XCTAssertTrue(dismissed)
    }

    func testUpdatingHandlersRedirectsForwarding() {
        var first = 0
        var second = 0
        let navigator = AppScreensNavigator(
            push: { _, _ in first += 1 },
            presentSheet: { _, _, _ in },
            dismissRoot: {}
        )
        let target = address("https://testbench.rover.io/a/detail")
        navigator.pushScreen(address: target, targetRequest: nil)
        navigator.pushHandler = { _, _ in second += 1 }
        navigator.pushScreen(address: target, targetRequest: nil)

        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 1)
    }
}
