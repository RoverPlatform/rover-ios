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

/// Exercises `AppScreensDriver.navigate`'s `.push` branch: a source session
/// carrying a flow token enqueues a `PendingNavigation` and calls
/// `AppScreensNavigating.pushScreen`, deferring host creation to render time. The
/// tokenized flow path is the only path — App Screens navigation always runs
/// through the SwiftUI host, with no tokenless/UIKit fallback.
@MainActor
final class AppScreenNavigatePushTests: XCTestCase {

    private var navigator: AppScreensDriver!
    private let configSuiteName = "io.rover.test.appscreens.navigatePush.config"

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

    /// A fake `AppScreensNavigating` that records every `pushScreen` call so the test
    /// can assert the new path drives the navigating seam instead of UIKit.
    private final class FakeNavigating: AppScreensNavigating {
        private(set) var pushedAddresses: [AppScreenAddress] = []
        private(set) var presentSheetCallCount = 0

        func pushScreen(address: AppScreenAddress, targetRequest: URLRequest?) {
            pushedAddresses.append(address)
        }

        func presentSheet(address: AppScreenAddress, targetRequest: URLRequest?, sheetToken: AppScreensToken) {
            presentSheetCallCount += 1
        }

        func presentWebsite(url: URL) {}

        func dismissRoot() {}
    }

    /// Builds a source session with a real web view and document URL, ready to
    /// originate a `navigate` bridge message.
    private func makeSourceSession(templateKey: String, documentURL: URL) -> AppScreenSession {
        let session = AppScreenSession(templateKey: templateKey, webView: WKWebView(), state: .ready)
        session.documentURL = documentURL
        // A screen that can post a bridge message is on a navigation stack: the
        // driver drops a `navigate` from an off-stack (popped-but-warm, or
        // prewarming) source, so the fixture must reflect a live screen.
        session.isOnStack = true
        return session
    }

    // MARK: - New path (source has a flow token)

    /// A single `.push` from a flow-tokened source enqueues exactly one pending
    /// record and calls `pushScreen` — without creating a host or starting a
    /// pipeline (both deferred to render-time `makeHost`).
    func testPushFromFlowTokenedSourceEnqueuesAndCallsPushScreenWithoutCreatingHost() {
        let homeURL = URL(string: "https://testbench.rover.io/a/home")!
        let source = makeSourceSession(templateKey: Self.key("home"), documentURL: homeURL)
        let token = AppScreensToken()
        source.token = token
        let fakeNavigating = FakeNavigating()
        source.navigating = fakeNavigating

        navigator.navigate(
            href: "https://testbench.rover.io/a/detail",
            optimisticDataJSON: nil,
            transition: .push,
            from: source
        )

        let detailSession = navigator.sessions[Self.key("detail")]
        XCTAssertNotNil(detailSession, "the warm session for the pushed template should exist")
        XCTAssertEqual(detailSession?.isOnStack, true, "isOnStack is set at navigate time, not render time")
        XCTAssertEqual(fakeNavigating.pushedAddresses.count, 1)
        XCTAssertNil(detailSession?.hostViewController, "host creation is deferred to makeHost")
        XCTAssertNil(detailSession?.pipelineTask, "the pipeline is deferred to makeHost")
    }

    /// Two rapid `.push` calls to the same template from the same flow-tokened
    /// source: the second selects an ephemeral session (because the first is
    /// already `isOnStack`), both push through `pushScreen`, and both records are
    /// enqueued FIFO for `(flow, address)` — the warm session first, the ephemeral
    /// session second.
    func testRapidSecondPushSelectsEphemeralSessionAndEnqueuesFIFO() throws {
        let homeURL = URL(string: "https://testbench.rover.io/a/home")!
        let source = makeSourceSession(templateKey: Self.key("home"), documentURL: homeURL)
        let token = AppScreensToken()
        source.token = token
        let fakeNavigating = FakeNavigating()
        source.navigating = fakeNavigating

        navigator.navigate(
            href: "https://testbench.rover.io/a/detail",
            optimisticDataJSON: nil,
            transition: .push,
            from: source
        )
        let warmSession = try XCTUnwrap(navigator.sessions[Self.key("detail")])

        navigator.navigate(
            href: "https://testbench.rover.io/a/detail",
            optimisticDataJSON: nil,
            transition: .push,
            from: source
        )

        XCTAssertEqual(navigator.ephemeralSessions.count, 1, "the second push must select a fresh ephemeral session")
        XCTAssertEqual(fakeNavigating.pushedAddresses.count, 2)

        let address = try XCTUnwrap(AppScreenAddress(rawURL: URL(string: "https://testbench.rover.io/a/detail")!))
        let firstClaim = try XCTUnwrap(navigator.pendingNavigations.claim(for: address, in: token))
        XCTAssertTrue(firstClaim.session === warmSession, "the warm session's record must claim first (FIFO)")

        let secondClaim = try XCTUnwrap(navigator.pendingNavigations.claim(for: address, in: token))
        XCTAssertTrue(
            secondClaim.session === navigator.ephemeralSessions.first,
            "the ephemeral session's record must claim second"
        )
    }

}
