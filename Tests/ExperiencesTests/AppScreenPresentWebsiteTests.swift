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

@testable import RoverData
@testable import RoverExperiences

/// Exercises `AppScreensDriver.presentWebsite(href:from:)`, the bridge that routes a
/// flow-tokened (SwiftUI-hosted) source's `presentWebsite` message through the
/// `AppScreensNavigating` intent — rather than presenting an `SFSafariViewController`
/// directly — so the presenting screen shows the resolved URL via its own
/// `.fullScreenCover` + `SafariView` (parity with `ScreenView`). This is the only
/// path; there is no tokenless/UIKit fallback. Drives the bridge method directly —
/// no rendering, no `SFSafariViewController` presentation is awaited or asserted.
@MainActor
final class AppScreenPresentWebsiteTests: XCTestCase {

    private var navigator: AppScreensDriver!
    private let configSuiteName = "io.rover.test.appscreens.presentWebsite.config"

    override func setUp() {
        super.setUp()
        navigator = Self.makeNavigator(configSuiteName: configSuiteName)
    }

    override func tearDown() {
        navigator = nil
        UserDefaults(suiteName: configSuiteName)?.removePersistentDomain(forName: configSuiteName)
        super.tearDown()
    }

    /// Builds a real navigator with throwaway dependencies. `presentWebsite` never
    /// touches the HTTP/config layers.
    private static func makeNavigator(configSuiteName: String) -> AppScreensDriver {
        let authContext = AuthenticationContext(userDefaults: UserDefaults())
        let httpClient = HTTPClient(
            accountToken: "test-token",
            endpoint: URL(string: "https://testbench.rover.io")!,
            engageEndpoint: URL(string: "https://engage.rover.io")!,
            session: .shared,
            authContext: authContext
        )
        let configManager = ConfigManager(userDefaults: UserDefaults(suiteName: configSuiteName)!)
        return AppScreensDriver(
            httpClient: httpClient,
            configManager: configManager,
            associatedDomains: ["testbench.rover.io"],
            eventQueue: nil
        )
    }

    /// A minimal `AppScreensNavigating` conformer that captures `presentWebsite(url:)`
    /// calls so a test can assert the intent path (as opposed to the legacy UIKit
    /// present) was taken.
    private final class FakeNavigating: AppScreensNavigating {
        private(set) var capturedURLs: [URL] = []

        func pushScreen(address: AppScreenAddress, targetRequest: URLRequest?) {}
        func presentSheet(address: AppScreenAddress, targetRequest: URLRequest?, sheetToken: AppScreensToken) {}
        func presentWebsite(url: URL) {
            capturedURLs.append(url)
        }
        func dismissRoot() {}
    }

    private func makeSourceSession(documentURL: URL) -> AppScreenSession {
        let session = AppScreenSession(
            templateKey: "https://testbench.rover.io/a/home",
            webView: WKWebView(),
            state: .ready
        )
        session.documentURL = documentURL
        return session
    }

    func testPresentWebsiteFromFlowTokenedSourceRoutesToIntent() {
        let fake = FakeNavigating()
        let source = makeSourceSession(documentURL: URL(string: "https://testbench.rover.io/a/home")!)
        source.token = AppScreensToken()
        source.navigating = fake

        navigator.presentWebsite(href: "https://example.com/x", from: source)

        XCTAssertEqual(fake.capturedURLs.count, 1)
        XCTAssertEqual(fake.capturedURLs.first?.scheme, "https")
        XCTAssertTrue(fake.capturedURLs.first?.absoluteString.contains("example.com") ?? false)
    }

    func testPresentWebsiteDropsUnparseableHref() {
        let fake = FakeNavigating()
        let source = makeSourceSession(documentURL: URL(string: "https://testbench.rover.io/a/home")!)
        source.token = AppScreensToken()
        source.navigating = fake

        // `mailto:` has no host, so `safariPresentableURL` rejects it.
        navigator.presentWebsite(href: "mailto:foo@bar.com", from: source)

        XCTAssertTrue(fake.capturedURLs.isEmpty)
    }
}
