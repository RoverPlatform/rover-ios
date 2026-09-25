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

/// Exercises `AppScreensDriver.navigate`'s `.sheet` branch: a source session
/// carrying a flow token mints a FRESH sheet flow token, enqueues a
/// `PendingNavigation`, and calls `AppScreensNavigating.presentSheet`, deferring
/// host creation to render time. The tokenized flow path is the only path —
/// App Screens navigation always runs through the SwiftUI host, with no
/// tokenless/UIKit fallback.
@MainActor
final class AppScreenNavigateSheetTests: XCTestCase {

    private var navigator: AppScreensDriver!
    private let configSuiteName = "io.rover.test.appscreens.navigateSheet.config"

    override func setUp() {
        super.setUp()
        navigator = Self.makeNavigator(configSuiteName: configSuiteName)
    }

    override func tearDown() {
        navigator = nil
        UserDefaults(suiteName: configSuiteName)?.removePersistentDomain(forName: configSuiteName)
        super.tearDown()
    }

    /// Builds a real navigator with throwaway dependencies. `navigate` never touches
    /// the HTTP/config layers directly (the pipeline it may start would, but these
    /// tests only assert the task was started, not awaited to completion).
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

    /// The origin-qualified key for a template on the test's associated domain.
    private static func key(_ templatePath: String) -> String {
        "https://testbench.rover.io/a/\(templatePath)"
    }

    /// A fake `AppScreensNavigating` that records every `presentSheet` call so the
    /// test can assert the new path drives the navigating seam (with a fresh flow
    /// token) instead of UIKit.
    private final class FakeNavigating: AppScreensNavigating {
        private(set) var capturedSheetTokens: [AppScreensToken] = []

        func pushScreen(address: AppScreenAddress, targetRequest: URLRequest?) {}

        func presentSheet(address: AppScreenAddress, targetRequest: URLRequest?, sheetToken: AppScreensToken) {
            capturedSheetTokens.append(sheetToken)
        }

        func presentWebsite(url: URL) {}

        func dismissRoot() {}
    }

    /// Builds a source session with a real web view and document URL, optionally
    /// carrying a flow token and a navigating seam, ready to originate a `navigate`
    /// bridge message.
    private func makeSourceSession(
        templateKey: String,
        documentURL: URL,
        token: AppScreensToken?,
        navigating: AppScreensNavigating?
    ) -> AppScreenSession {
        let session = AppScreenSession(templateKey: templateKey, webView: WKWebView(), state: .ready)
        session.documentURL = documentURL
        session.token = token
        session.navigating = navigating
        // A screen that can post a bridge message is on a navigation stack: the
        // driver drops a `navigate` from an off-stack (popped-but-warm, or
        // prewarming) source, so the fixture must reflect a live screen.
        session.isOnStack = true
        return session
    }

    // MARK: - New path (source has a flow token)

    /// A `.sheet` navigation from a flow-tokened source mints a fresh sheet flow
    /// token (distinct from the source's own), enqueues exactly one pending record
    /// under `(address, freshToken)`, and calls `presentSheet` — without creating a
    /// host (both deferred to render-time `makeHost`).
    func testSheetFromFlowTokenedSourceEnqueuesPendingAndCallsPresentSheetIntent() throws {
        let homeURL = URL(string: "https://testbench.rover.io/a/home")!
        let sourceToken = AppScreensToken()
        let fakeNavigating = FakeNavigating()
        let source = makeSourceSession(
            templateKey: Self.key("home"),
            documentURL: homeURL,
            token: sourceToken,
            navigating: fakeNavigating
        )

        navigator.navigate(
            href: "https://testbench.rover.io/a/detail",
            optimisticDataJSON: nil,
            transition: .sheet,
            from: source
        )

        XCTAssertEqual(fakeNavigating.capturedSheetTokens.count, 1)
        let sheetToken = try XCTUnwrap(fakeNavigating.capturedSheetTokens.first)
        XCTAssertNotEqual(sheetToken, sourceToken, "a sheet opens a NEW flow, not the source's")

        let detailURL = URL(string: "https://testbench.rover.io/a/detail")!
        let detailSession = try XCTUnwrap(
            navigator.sessions[Self.key("detail")] ?? navigator.sessions.values.first { $0.documentURL == detailURL },
            "the warm session for the sheeted template should exist"
        )
        XCTAssertEqual(detailSession.isOnStack, true, "isOnStack is set at navigate time, not render time")
        XCTAssertNil(detailSession.hostViewController, "host creation is deferred to makeHost")

        let address = try XCTUnwrap(AppScreenAddress(rawURL: detailURL))
        let firstClaim = navigator.pendingNavigations.claim(for: address, in: sheetToken)
        XCTAssertNotNil(firstClaim, "exactly one record must be enqueued for the fresh sheet token")

        let secondClaim = navigator.pendingNavigations.claim(for: address, in: sheetToken)
        XCTAssertNil(secondClaim, "only one record should have been enqueued")
    }

}
