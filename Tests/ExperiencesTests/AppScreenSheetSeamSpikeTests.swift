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

import WebKit
import XCTest

@testable import RoverData
@testable import RoverExperiences

/// De-risks the sheet-root handoff seam `AppScreensSheetHostView` wires: a flow token minted before a
/// `.sheet` presentation must claim its own `PendingNavigation` via the existing `makeHost`
/// — never a different flow's record queued at the same address. This is exercised
/// render-free, by calling `makeHost` directly, exactly like the reliable
/// `AppScreenMakeHostTests` does — no `UIWindow`, no `UIHostingController`, no `.sheet`, no
/// `waitUntil`. That render-free approach is deliberate: an earlier version of this spike
/// hosted a real `.sheet` in a `UIWindow` and polled with `waitUntil` for SwiftUI's view
/// lifecycle to fire, which requires a hosted `UIApplication` and was flaky in this test
/// environment (it would pass under one `test_sim` run and fail under another, logging
/// "This process does not have a UIApplication object and will not receive events!").
/// `@StateObject` initialize-once identity across a `.sheet` presentation and across body
/// re-evaluations is a SwiftUI framework guarantee, not something this SDK needs to
/// re-verify with a flaky render harness; that guarantee, along with actual sheet
/// presentation, is validated end-to-end in Testbench instead.
@MainActor
final class AppScreenSheetSeamSpikeTests: XCTestCase {
    // MARK: - Test doubles

    /// A minimal `AppScreensNavigating` conformer: `makeHost` only stores this as
    /// `session.navigating`, so its method bodies are never exercised here.
    private final class FakeNavigating: AppScreensNavigating {
        func pushScreen(address: AppScreenAddress, targetRequest: URLRequest?) {}
        func presentSheet(address: AppScreenAddress, targetRequest: URLRequest?, sheetToken: AppScreensToken) {}
        func presentWebsite(url: URL) {}
        func dismissRoot() {}
    }

    // MARK: - Helpers

    /// Builds a real navigator with throwaway dependencies, matching
    /// `AppScreenMakeHostTests.makeNavigator`. `makeHost` never touches the HTTP/config
    /// layers directly (the pipeline it starts would, but the test only asserts the task
    /// was started, not awaited to completion).
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

    // MARK: - Sheet-root FIFO claim via `makeHost`

    func testSheetRootMakeHostClaimsOwnFlowTokenPendingAndIsolatesOtherFlows() throws {
        let configSuiteName = "io.rover.test.appscreens.sheetSeamSpike.config"
        let navigator = Self.makeNavigator(configSuiteName: configSuiteName)
        defer {
            UserDefaults(suiteName: configSuiteName)?.removePersistentDomain(forName: configSuiteName)
        }

        let sheetAddress = try XCTUnwrap(
            AppScreenAddress(rawURL: URL(string: "https://testbench.rover.io/a/player-detail")!)
        )
        let sheetToken = AppScreensToken()
        let otherToken = AppScreensToken()

        let sheetSession = AppScreenSession(
            templateKey: "https://testbench.rover.io/a/player-detail",
            webView: WKWebView(),
            state: .ready
        )
        sheetSession.isOnStack = true
        sheetSession.documentURL = sheetAddress.url

        let otherTokenSession = AppScreenSession(
            templateKey: "https://testbench.rover.io/a/player-detail",
            webView: WKWebView(),
            state: .ready
        )
        otherTokenSession.isOnStack = true
        otherTokenSession.documentURL = sheetAddress.url

        // Enqueue the other flow's record first so an address-only-FIFO regression (i.e. one
        // that ignored the flow token entirely) would claim the wrong session here and fail
        // the ownership assertions below.
        navigator.pendingNavigations.enqueue(
            PendingNavigation(
                session: otherTokenSession,
                resolvedURL: sheetAddress.url,
                optimisticDataJSON: nil,
                isColdLoad: false,
                tapTime: .now()
            ),
            for: sheetAddress,
            in: otherToken
        )
        navigator.pendingNavigations.enqueue(
            PendingNavigation(
                session: sheetSession,
                resolvedURL: sheetAddress.url,
                optimisticDataJSON: nil,
                isColdLoad: false,
                tapTime: .now()
            ),
            for: sheetAddress,
            in: sheetToken
        )

        let host = navigator.makeHost(
            token: sheetToken,
            address: sheetAddress,
            targetRequest: nil,
            navigating: FakeNavigating()
        )

        let hostViewController = try XCTUnwrap(host as? AppScreensPageViewController)
        XCTAssertTrue(
            sheetSession.hostViewController === hostViewController,
            "the sheet's own flow token must claim its own pre-selected session's record"
        )
        XCTAssertEqual(
            sheetSession.token,
            sheetToken,
            "makeHost must stamp the claimed session with the sheet's own flow token"
        )
        XCTAssertNotNil(
            sheetSession.pipelineTask,
            "makeHost must start the navigate pipeline for the claimed session"
        )

        let untouchedOtherTokenRecord = navigator.pendingNavigations.claim(for: sheetAddress, in: otherToken)
        XCTAssertNotNil(
            untouchedOtherTokenRecord,
            "the sheet root claiming under its own flow token must leave the other flow's same-address record still queued"
        )
        XCTAssertTrue(
            untouchedOtherTokenRecord?.session === otherTokenSession,
            "the still-queued record must be the other flow's own pre-selected session, not a cross-claimed one"
        )
    }
}
