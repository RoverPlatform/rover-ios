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

/// Exercises `AppScreensDriver.makeRootHost(flow:url:navigating:onDismiss:onOpenURL:)`
/// and `release(_:)` — the flow-scoped root lifecycle that the SwiftUI-hosted App
/// Screens path uses to create and tear down a root, with no UIKit navigation
/// controller involved.
@MainActor
final class AppScreenRootFlowTests: XCTestCase {

    private var navigator: AppScreensDriver!
    private let configSuiteName = "io.rover.test.appscreens.rootToken.config"

    override func setUp() {
        super.setUp()
        navigator = Self.makeNavigator(configSuiteName: configSuiteName)
    }

    override func tearDown() {
        navigator = nil
        UserDefaults(suiteName: configSuiteName)?.removePersistentDomain(forName: configSuiteName)
        super.tearDown()
    }

    /// Builds a real navigator with throwaway dependencies. Neither `makeRootHost` nor
    /// `release` touches the HTTP/config layers directly (the master pipeline
    /// `makeRootHost` starts would, but the tests only assert the task was started,
    /// not awaited to completion).
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

    /// A minimal `AppScreensNavigating` conformer: the code under test only stores this
    /// as `session.navigating`, so its method bodies are never exercised here.
    private final class FakeNavigating: AppScreensNavigating {
        func pushScreen(address: AppScreenAddress, targetRequest: URLRequest?) {}
        func presentSheet(address: AppScreenAddress, targetRequest: URLRequest?, sheetToken: AppScreensToken) {}
        func presentWebsite(url: URL) {}
        func dismissRoot() {}
    }

    func testMakeRootHostCreatesFlowScopedRootAndStartsMasterPipeline() throws {
        let url = URL(string: "https://testbench.rover.io/a/home")!
        let token = AppScreensToken()
        let fakeNavigating = FakeNavigating()
        let rootCountBefore = navigator.rootSessions.count

        let host = navigator.makeRootHost(
            token: token,
            url: url,
            navigating: fakeNavigating,
            onDismiss: nil,
            onOpenURL: nil
        )

        XCTAssertEqual(navigator.rootSessions.count, rootCountBefore + 1)
        let session = try XCTUnwrap(
            navigator.rootSessions.first(where: { $0.hostViewController === host as? AppScreensPageViewController })
        )
        XCTAssertTrue(session.isOnStack)
        XCTAssertEqual(session.token, token)
        XCTAssertTrue(session.navigating === fakeNavigating)
        XCTAssertNotNil(session.pipelineTask)

        // Verify the session was registered under the flow (not just created) by
        // confirming `release` — which only acts on `sessionsByToken[flow]` — can
        // find and release it.
        navigator.release(token)
        XCTAssertFalse(navigator.rootSessions.contains { $0 === session })
        XCTAssertNil(navigator.sessionsByToken[token])
    }

    func testReleaseFlowReleasesRootWithoutANavigationController() throws {
        let url = URL(string: "https://testbench.rover.io/a/home")!
        let token = AppScreensToken()
        let templateKey = try XCTUnwrap(AppScreensDriver.templateKey(from: url))

        let host = navigator.makeRootHost(
            token: token,
            url: url,
            navigating: FakeNavigating(),
            onDismiss: nil,
            onOpenURL: nil
        )
        let session = try XCTUnwrap(
            navigator.rootSessions.first(where: { $0.hostViewController === host as? AppScreensPageViewController })
        )
        // Path-neutrality: the host is never embedded in a navigation
        // controller here, confirming `release` doesn't depend on any
        // `navigationController` walk to tear the root down.
        XCTAssertNil(host.navigationController)

        navigator.release(token)

        // The freshly created root is still `.loadingDocument` (never reached
        // `.ready`), so `releaseRootSession` tears it down rather than demoting it
        // into the warm pool — either outcome proves the release happened, but this
        // is the deterministic one for a root whose pipeline never resolved.
        XCTAssertFalse(navigator.rootSessions.contains { $0 === session })
        XCTAssertNil(navigator.sessions[templateKey])
        XCTAssertEqual(session.state, .dead)
        XCTAssertNil(navigator.sessionsByToken[token])
    }

    func testReleaseFlowTearsDownPushedDetailAndUnclaimedPending() throws {
        let token = AppScreensToken()

        // A rendered root, so the flow owns a real root to release last.
        _ = navigator.makeRootHost(
            token: token,
            url: URL(string: "https://testbench.rover.io/a/home")!,
            navigating: FakeNavigating(),
            onDismiss: nil,
            onOpenURL: nil
        )

        // Session A: enqueued but never claimed by a rendered destination — proves
        // the still-unclaimed-pending cohort is torn down.
        let addressA = try XCTUnwrap(
            AppScreenAddress(rawURL: URL(string: "https://testbench.rover.io/a/unclaimed-detail")!)
        )
        let sessionA = AppScreenSession(
            templateKey: "https://testbench.rover.io/a/unclaimed-detail",
            webView: WKWebView(),
            state: .ready
        )
        navigator.pendingNavigations.enqueue(
            PendingNavigation(
                session: sessionA,
                resolvedURL: addressA.url,
                optimisticDataJSON: nil,
                isColdLoad: false,
                tapTime: .now()
            ),
            for: addressA,
            in: token
        )

        // Session B: enqueued and then claimed via `makeHost`, simulating a rendered
        // pushed detail — an ephemeral one, so its teardown outcome (`.dead`) is
        // unambiguous rather than the warm "kept off stack" branch.
        let addressB = try XCTUnwrap(
            AppScreenAddress(rawURL: URL(string: "https://testbench.rover.io/a/pushed-detail")!)
        )
        let sessionB = AppScreenSession(
            templateKey: "https://testbench.rover.io/a/pushed-detail",
            webView: WKWebView(),
            state: .ready
        )
        sessionB.isEphemeral = true
        sessionB.isOnStack = true
        sessionB.documentURL = addressB.url
        navigator.pendingNavigations.enqueue(
            PendingNavigation(
                session: sessionB,
                resolvedURL: addressB.url,
                optimisticDataJSON: nil,
                isColdLoad: false,
                tapTime: .now()
            ),
            for: addressB,
            in: token
        )
        _ = navigator.makeHost(
            token: token,
            address: addressB,
            targetRequest: nil,
            navigating: FakeNavigating()
        )
        XCTAssertEqual(sessionB.token, token)

        navigator.release(token)

        // The unclaimed pending session (A) was drained and torn down.
        XCTAssertEqual(sessionA.state, .dead)
        // The rendered pushed detail (B), being ephemeral, was torn down by
        // `handlePop(of:)`.
        XCTAssertEqual(sessionB.state, .dead)
        // The flow's registry entry (and its pending records) are fully purged.
        XCTAssertNil(navigator.sessionsByToken[token])
    }
}
