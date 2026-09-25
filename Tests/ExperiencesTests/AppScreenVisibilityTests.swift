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
import WebKit
import XCTest

@testable import RoverExperiences

@MainActor
final class AppScreenVisibilityTests: XCTestCase {
    func testVisibleWhenHostFlagSetAndInWindow() {
        let session = AppScreenSession(templateKey: "k", webView: WKWebView(), state: .ready)
        session.isOnStack = true
        let host = AppScreensPageViewController(
            webView: session.webView,
            screenBackground: .black,
            showsSkeleton: false
        )
        session.hostViewController = host
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        host.viewDidAppear(false)
        XCTAssertEqual(AppScreensDriver.visibility(of: session), .visible)
        host.viewDidDisappear(false)
        XCTAssertEqual(AppScreensDriver.visibility(of: session), .occluded)
    }
    func testOffStackWhenNotOnStack() {
        let session = AppScreenSession(templateKey: "k", webView: WKWebView(), state: .ready)
        session.isOnStack = false
        XCTAssertEqual(AppScreensDriver.visibility(of: session), .offStack)
    }
}
