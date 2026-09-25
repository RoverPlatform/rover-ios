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

/// Exercises `AppScreensTokenBox`'s deinit-driven `release` — the load-bearing
/// mechanism `AppScreensHostView` relies on to release a Hub-hosted App
/// Screens flow only on TRUE removal (never on mere occlusion). Hub-level rendering
/// (the `.id(url)` wiring, the domain gate) is out of scope here; this file proves
/// the box itself behaves as designed.
@MainActor
final class AppScreenFlowHostTests: XCTestCase {

    private var navigator: AppScreensDriver!
    private let configSuiteName = "io.rover.test.appscreens.flowHost.config"

    override func setUp() {
        super.setUp()
        navigator = Self.makeNavigator(configSuiteName: configSuiteName)
    }

    override func tearDown() {
        navigator = nil
        UserDefaults(suiteName: configSuiteName)?.removePersistentDomain(forName: configSuiteName)
        super.tearDown()
    }

    /// Builds a real navigator with throwaway dependencies, mirroring
    /// `AppScreenRootFlowTests.makeNavigator(configSuiteName:)`.
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

    @discardableResult
    private func waitUntil(timeout: TimeInterval = 3.0, _ predicate: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        return predicate()
    }

    func testFlowBoxDeinitReleasesFlow() throws {
        let url = URL(string: "https://testbench.rover.io/a/home")!
        let templateKey = try XCTUnwrap(AppScreensDriver.templateKey(from: url))

        var box: AppScreensTokenBox? = AppScreensTokenBox(navigator: navigator)
        let token = try XCTUnwrap(box).token

        let host = navigator.makeRootHost(
            token: token,
            url: url,
            navigating: FakeNavigating(),
            onDismiss: nil,
            onOpenURL: nil,
            onOpenExternalURL: { _, _ in }
        )
        let session = try XCTUnwrap(
            navigator.rootSessions.first(where: { $0.hostViewController === host as? AppScreensPageViewController })
        )
        XCTAssertTrue(navigator.rootSessions.contains { $0 === session })
        XCTAssertNotNil(navigator.openHandlersByToken[token])

        // Force the box to deallocate — this is the ONLY release trigger; there is
        // deliberately no `.onDisappear` path.
        box = nil

        XCTAssertTrue(
            waitUntil { !self.navigator.rootSessions.contains { $0 === session } },
            "box deinit should have released the flow's root session"
        )
        XCTAssertNil(navigator.sessions[templateKey])
        XCTAssertNil(navigator.sessionsByToken[token])
        XCTAssertNil(navigator.openHandlersByToken[token])
    }

    func testRetainedFlowBoxDoesNotReleaseFlow() throws {
        let url = URL(string: "https://testbench.rover.io/a/other-home")!

        let box = AppScreensTokenBox(navigator: navigator)
        let token = box.token

        let host = navigator.makeRootHost(
            token: token,
            url: url,
            navigating: FakeNavigating(),
            onDismiss: nil,
            onOpenURL: nil,
            onOpenExternalURL: { _, _ in }
        )
        let session = try XCTUnwrap(
            navigator.rootSessions.first(where: { $0.hostViewController === host as? AppScreensPageViewController })
        )

        // Give any stray async teardown a chance to run — none should, since the box
        // (and therefore the flow) is still retained. This is the occlusion-vs-
        // teardown guarantee: mere retention (standing in for the view merely being
        // occluded, e.g. by a pushed inbox) must never release the flow.
        _ = waitUntil(timeout: 0.3) { false }

        XCTAssertTrue(
            navigator.rootSessions.contains { $0 === session },
            "retaining the flow box should keep the root session alive"
        )
        XCTAssertNotNil(navigator.sessionsByToken[token])
        XCTAssertNotNil(navigator.openHandlersByToken[token])

        // Keep `box` alive through the end of the test.
        withExtendedLifetime(box) {}
    }
}
