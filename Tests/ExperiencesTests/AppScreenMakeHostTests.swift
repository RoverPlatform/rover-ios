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

/// Exercises `AppScreensDriver.makeHost(flow:address:targetRequest:navigating:)`,
/// the render-time half of the SwiftUI cutover: it claims the `PendingNavigation`
/// `navigate` enqueued, builds the host, and starts the load pipeline.
@MainActor
final class AppScreenMakeHostTests: XCTestCase {

    private var navigator: AppScreensDriver!
    private let configSuiteName = "io.rover.test.appscreens.makeHost.config"

    override func setUp() {
        super.setUp()
        navigator = Self.makeNavigator(configSuiteName: configSuiteName)
    }

    override func tearDown() {
        // `makeHost` starts a real load pipeline on `URLSession.shared`; these tests
        // only assert the task was started, never routing through `release(_:)`/
        // `teardown(_:)`. Cancel any live pipeline so it cannot outlive the test and
        // hit the network.
        let sessions =
            navigator.rootSessions + navigator.ephemeralSessions
            + navigator.sessionsByToken.values.flatMap { $0.values }
        for session in sessions {
            session.pipelineTask?.cancel()
        }
        navigator = nil
        UserDefaults(suiteName: configSuiteName)?.removePersistentDomain(forName: configSuiteName)
        super.tearDown()
    }

    /// Builds a real navigator with throwaway dependencies. `makeHost` never touches
    /// the HTTP/config layers directly (the pipeline it starts would, but the test
    /// only asserts the task was started, not awaited to completion).
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

    /// A minimal `AppScreensNavigating` conformer: `makeHost` only stores this as
    /// `session.navigating`, so its method bodies are never exercised here.
    private final class FakeNavigating: AppScreensNavigating {
        func pushScreen(address: AppScreenAddress, targetRequest: URLRequest?) {}
        func presentSheet(address: AppScreenAddress, targetRequest: URLRequest?, sheetToken: AppScreensToken) {}
        func presentWebsite(url: URL) {}
        func dismissRoot() {}
    }

    func testMakeHostClaimsRecordBuildsHostAndStartsPipeline() throws {
        let address = try XCTUnwrap(
            AppScreenAddress(rawURL: URL(string: "https://testbench.rover.io/a/player-detail")!)
        )
        let token = AppScreensToken()

        let session = AppScreenSession(
            templateKey: "https://testbench.rover.io/a/player-detail",
            webView: WKWebView(),
            state: .ready
        )
        // Simulates what `navigate` does at resolve time — set here in the
        // test's own setup rather than asserted as a side effect of `makeHost`.
        session.isOnStack = true
        session.documentURL = address.url

        let record = PendingNavigation(
            session: session,
            resolvedURL: address.url,
            optimisticDataJSON: nil,
            isColdLoad: false,
            tapTime: .now()
        )
        navigator.pendingNavigations.enqueue(record, for: address, in: token)

        let fakeNavigating = FakeNavigating()
        let host = navigator.makeHost(
            token: token,
            address: address,
            targetRequest: nil,
            navigating: fakeNavigating
        )

        let hostViewController = try XCTUnwrap(host as? AppScreensPageViewController)
        XCTAssertTrue(session.hostViewController === hostViewController)
        XCTAssertTrue(session.isOnStack)
        XCTAssertTrue(session.navigating === fakeNavigating)
        XCTAssertEqual(session.token, token)
        XCTAssertNotNil(session.pipelineTask)
    }

    func testMakeHostColdLoadsWhenNoPendingRecordExists() throws {
        let address = try XCTUnwrap(AppScreenAddress(rawURL: URL(string: "https://testbench.rover.io/a/roster")!))
        let token = AppScreensToken()

        let host = navigator.makeHost(
            token: token,
            address: address,
            targetRequest: nil,
            navigating: FakeNavigating()
        )

        // No pending record: the destination was restored from a shared
        // `NavigationPath` into a fresh flow (e.g. presenting the Hub while its tab
        // already pushed a detail) rather than reached through `navigate`. Instead of
        // returning the blank placeholder host, `makeHost` cold-loads the address into
        // a fresh ephemeral session so the restored screen renders.
        let hostViewController = try XCTUnwrap(host as? AppScreensPageViewController)
        let session = try XCTUnwrap(navigator.ephemeralSessions.first { $0.hostViewController === hostViewController })
        XCTAssertEqual(session.token, token)
        XCTAssertTrue(session.isEphemeral)
        XCTAssertTrue(session.isOnStack)
        XCTAssertNotNil(session.webView, "cold-load fallback must build a real web view, not the blank placeholder")
        XCTAssertNotNil(session.pipelineTask)
        XCTAssertNotNil(
            navigator.sessionsByToken[token]?[ObjectIdentifier(session)],
            "the cold-loaded session must be registered under the flow so release tears it down"
        )
    }
}
