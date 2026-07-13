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

@testable import RoverData
@testable import RoverExperiences

/// Exercises `AppScreensNavigator.popToRoot(in:)`, the reset that a Hub-driven
/// navigation triggers to release a stale pushed App Screens detail.
@MainActor
final class AppScreensNavigatorPopToRootTests: XCTestCase {

    private var navigator: AppScreensNavigator!
    private let configSuiteName = "io.rover.test.appscreens.popToRoot.config"

    override func setUp() {
        super.setUp()
        navigator = Self.makeNavigator(configSuiteName: configSuiteName)
    }

    override func tearDown() {
        navigator = nil
        UserDefaults(suiteName: configSuiteName)?.removePersistentDomain(forName: configSuiteName)
        super.tearDown()
    }

    /// Builds a real navigator with throwaway dependencies. `popToRoot` never
    /// touches the HTTP/config layers, so scratch instances suffice.
    private static func makeNavigator(configSuiteName: String) -> AppScreensNavigator {
        let authContext = AuthenticationContext(userDefaults: UserDefaults())
        let httpClient = HTTPClient(
            accountToken: "test-token",
            endpoint: URL(string: "https://testbench.rover.io")!,
            engageEndpoint: URL(string: "https://engage.rover.io")!,
            session: .shared,
            authContext: authContext
        )
        let configManager = ConfigManager(userDefaults: UserDefaults(suiteName: configSuiteName)!)
        return AppScreensNavigator(httpClient: httpClient, configManager: configManager)
    }

    /// Registers a warm session against its template path and hands back its host.
    @discardableResult
    private func makeWarmSession(templatePath: String, isOnStack: Bool) -> AppScreenHostViewController {
        let session = AppScreenSession(templatePath: templatePath, webView: nil, state: .ready)
        session.isEphemeral = false
        session.isOnStack = isOnStack
        let host = AppScreenHostViewController(webView: nil, screenBackground: .systemBackground)
        session.hostViewController = host
        navigator.sessions[templatePath] = session
        return host
    }

    /// Registers a one-off ephemeral (detail→detail) session and hands back its host.
    @discardableResult
    private func makeEphemeralSession(templatePath: String) -> AppScreenHostViewController {
        let session = AppScreenSession(templatePath: templatePath, webView: nil, state: .ready)
        session.isEphemeral = true
        session.isOnStack = true
        let host = AppScreenHostViewController(webView: nil, screenBackground: .systemBackground)
        session.hostViewController = host
        navigator.ephemeralSessions.append(session)
        return host
    }

    // MARK: - Tests

    func testPopToRootReleasesWarmAndEphemeralPushedSessions() {
        let rootHost = makeWarmSession(templatePath: "home", isOnStack: true)
        let warmDetailHost = makeWarmSession(templatePath: "standings", isOnStack: true)
        let ephemeralHost = makeEphemeralSession(templatePath: "player-detail")

        let navigationController = UINavigationController()
        navigationController.setViewControllers([rootHost, warmDetailHost, ephemeralHost], animated: false)

        navigator.popToRoot(in: navigationController)

        // Warm on-stack pushed session: left the stack but stays live for reuse.
        let warmDetail = navigator.sessions["standings"]
        XCTAssertNotNil(warmDetail)
        XCTAssertEqual(warmDetail?.isOnStack, false)
        XCTAssertNotEqual(warmDetail?.state, .dead)

        // Ephemeral pushed session: torn down and dropped.
        XCTAssertTrue(navigator.ephemeralSessions.isEmpty)

        // The root host remains the nav's only view controller; the master session
        // is untouched (still on the stack at the root).
        XCTAssertEqual(navigationController.viewControllers.count, 1)
        XCTAssertTrue(navigationController.viewControllers.first === rootHost)
        XCTAssertEqual(navigator.sessions["home"]?.isOnStack, true)
    }

    func testEphemeralSessionIsMarkedDeadOnReset() {
        let rootHost = makeWarmSession(templatePath: "home", isOnStack: true)
        let ephemeralHost = makeEphemeralSession(templatePath: "player-detail")
        // Hold a strong reference to the session so we can assert its state after
        // it has been removed from the navigator's ephemeral list.
        let ephemeralSession = navigator.ephemeralSessions[0]

        let navigationController = UINavigationController()
        navigationController.setViewControllers([rootHost, ephemeralHost], animated: false)

        navigator.popToRoot(in: navigationController)

        XCTAssertEqual(ephemeralSession.state, .dead)
        XCTAssertFalse(navigator.ephemeralSessions.contains { $0 === ephemeralSession })
    }

    func testPopToRootIsIdempotent() {
        let rootHost = makeWarmSession(templatePath: "home", isOnStack: true)
        let warmDetailHost = makeWarmSession(templatePath: "standings", isOnStack: true)
        let ephemeralHost = makeEphemeralSession(templatePath: "player-detail")

        let navigationController = UINavigationController()
        navigationController.setViewControllers([rootHost, warmDetailHost, ephemeralHost], animated: false)

        navigator.popToRoot(in: navigationController)
        // A second reset on an already-reset stack must not crash or corrupt state.
        navigator.popToRoot(in: navigationController)

        XCTAssertEqual(navigationController.viewControllers.count, 1)
        XCTAssertTrue(navigationController.viewControllers.first === rootHost)
        XCTAssertEqual(navigator.sessions["standings"]?.isOnStack, false)
        XCTAssertNotEqual(navigator.sessions["standings"]?.state, .dead)
        XCTAssertTrue(navigator.ephemeralSessions.isEmpty)
        XCTAssertEqual(navigator.sessions["home"]?.isOnStack, true)
    }

    func testPopToRootAtRootIsNoOp() {
        let rootHost = makeWarmSession(templatePath: "home", isOnStack: true)

        let navigationController = UINavigationController()
        navigationController.setViewControllers([rootHost], animated: false)

        navigator.popToRoot(in: navigationController)

        XCTAssertEqual(navigationController.viewControllers.count, 1)
        XCTAssertTrue(navigationController.viewControllers.first === rootHost)
        XCTAssertEqual(navigator.sessions["home"]?.isOnStack, true)
        XCTAssertNotEqual(navigator.sessions["home"]?.state, .dead)
    }
}
