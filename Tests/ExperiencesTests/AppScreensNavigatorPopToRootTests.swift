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
        return AppScreensNavigator(
            httpClient: httpClient,
            configManager: configManager,
            associatedDomains: ["testbench.rover.io"]
        )
    }

    /// Registers a warm session against its origin-qualified template key and hands
    /// back its host.
    @discardableResult
    private func makeWarmSession(templateKey: String, isOnStack: Bool) -> AppScreenHostViewController {
        let session = AppScreenSession(templateKey: templateKey, webView: nil, state: .ready)
        session.isEphemeral = false
        session.isOnStack = isOnStack
        let host = AppScreenHostViewController(webView: nil, screenBackground: .systemBackground)
        session.hostViewController = host
        navigator.sessions[templateKey] = session
        return host
    }

    /// Registers a one-off ephemeral (detail→detail) session and hands back its host.
    @discardableResult
    private func makeEphemeralSession(templateKey: String) -> AppScreenHostViewController {
        let session = AppScreenSession(templateKey: templateKey, webView: nil, state: .ready)
        session.isEphemeral = true
        session.isOnStack = true
        let host = AppScreenHostViewController(webView: nil, screenBackground: .systemBackground)
        session.hostViewController = host
        navigator.ephemeralSessions.append(session)
        return host
    }

    /// Registers a live root (entry-point) session in `rootSessions`, wrapping its
    /// host in a `UINavigationController` (as `ExperienceViewController` does) so
    /// `releaseRootPresentation` can reach the child stack. Returns the session and
    /// its host. `webView` lets a test assert `liveSession(for:)` resolution.
    @discardableResult
    private func makeRootSession(
        templateKey: String,
        state: AppScreenSession.State = .ready,
        webView: WKWebView? = nil
    ) -> (session: AppScreenSession, host: AppScreenHostViewController) {
        let session = AppScreenSession(templateKey: templateKey, webView: webView, state: state)
        session.isEphemeral = false
        session.isOnStack = true
        let host = AppScreenHostViewController(webView: webView, screenBackground: .systemBackground)
        session.hostViewController = host
        navigator.rootSessions.append(session)
        // A root host lives at the root of its own child navigation controller.
        _ = UINavigationController(rootViewController: host)
        return (session, host)
    }

    /// The origin-qualified key for a template on the test's associated domain.
    private static func key(_ templatePath: String) -> String {
        "https://testbench.rover.io/a/\(templatePath)"
    }

    // MARK: - Tests

    func testPopToRootReleasesWarmAndEphemeralPushedSessions() {
        let rootHost = makeWarmSession(templateKey: Self.key("home"), isOnStack: true)
        let warmDetailHost = makeWarmSession(templateKey: Self.key("standings"), isOnStack: true)
        let ephemeralHost = makeEphemeralSession(templateKey: Self.key("player-detail"))

        let navigationController = UINavigationController()
        navigationController.setViewControllers([rootHost, warmDetailHost, ephemeralHost], animated: false)

        navigator.popToRoot(in: navigationController)

        // Warm on-stack pushed session: left the stack but stays live for reuse.
        let warmDetail = navigator.sessions[Self.key("standings")]
        XCTAssertNotNil(warmDetail)
        XCTAssertEqual(warmDetail?.isOnStack, false)
        XCTAssertNotEqual(warmDetail?.state, .dead)

        // Ephemeral pushed session: torn down and dropped.
        XCTAssertTrue(navigator.ephemeralSessions.isEmpty)

        // The root host remains the nav's only view controller; the master session
        // is untouched (still on the stack at the root).
        XCTAssertEqual(navigationController.viewControllers.count, 1)
        XCTAssertTrue(navigationController.viewControllers.first === rootHost)
        XCTAssertEqual(navigator.sessions[Self.key("home")]?.isOnStack, true)
    }

    func testEphemeralSessionIsMarkedDeadOnReset() {
        let rootHost = makeWarmSession(templateKey: Self.key("home"), isOnStack: true)
        let ephemeralHost = makeEphemeralSession(templateKey: Self.key("player-detail"))
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
        let rootHost = makeWarmSession(templateKey: Self.key("home"), isOnStack: true)
        let warmDetailHost = makeWarmSession(templateKey: Self.key("standings"), isOnStack: true)
        let ephemeralHost = makeEphemeralSession(templateKey: Self.key("player-detail"))

        let navigationController = UINavigationController()
        navigationController.setViewControllers([rootHost, warmDetailHost, ephemeralHost], animated: false)

        navigator.popToRoot(in: navigationController)
        // A second reset on an already-reset stack must not crash or corrupt state.
        navigator.popToRoot(in: navigationController)

        XCTAssertEqual(navigationController.viewControllers.count, 1)
        XCTAssertTrue(navigationController.viewControllers.first === rootHost)
        XCTAssertEqual(navigator.sessions[Self.key("standings")]?.isOnStack, false)
        XCTAssertNotEqual(navigator.sessions[Self.key("standings")]?.state, .dead)
        XCTAssertTrue(navigator.ephemeralSessions.isEmpty)
        XCTAssertEqual(navigator.sessions[Self.key("home")]?.isOnStack, true)
    }

    /// A popped warm template session cancels its in-flight pipeline: a late
    /// async response from the popped navigation must not morph over the record
    /// the session's next reuse renders into the same warm web view.
    func testPopCancelsWarmSessionPipeline() {
        let rootHost = makeWarmSession(templateKey: Self.key("home"), isOnStack: true)
        let warmDetailHost = makeWarmSession(templateKey: Self.key("standings"), isOnStack: true)
        let warmDetail = navigator.sessions[Self.key("standings")]!
        // Hold a strong reference so the cancellation flag stays observable after
        // `handlePop` clears the session's handle.
        let task = Task { _ = try? await Task.sleep(nanoseconds: 60 * 1_000_000_000) }
        warmDetail.pipelineTask = task

        let navigationController = UINavigationController()
        navigationController.setViewControllers([rootHost, warmDetailHost], animated: false)

        navigator.popToRoot(in: navigationController)

        XCTAssertTrue(task.isCancelled)
        XCTAssertNil(warmDetail.pipelineTask)
    }

    /// A popped ephemeral (detail→detail) session cancels its in-flight pipeline
    /// as it is torn down, so no late await can act on the dead session.
    func testPopCancelsEphemeralSessionPipeline() {
        let rootHost = makeWarmSession(templateKey: Self.key("home"), isOnStack: true)
        let ephemeralHost = makeEphemeralSession(templateKey: Self.key("player-detail"))
        let ephemeral = navigator.ephemeralSessions[0]
        let task = Task { _ = try? await Task.sleep(nanoseconds: 60 * 1_000_000_000) }
        ephemeral.pipelineTask = task

        let navigationController = UINavigationController()
        navigationController.setViewControllers([rootHost, ephemeralHost], animated: false)

        navigator.popToRoot(in: navigationController)

        XCTAssertTrue(task.isCancelled)
        XCTAssertEqual(ephemeral.state, .dead)
    }

    // MARK: - Root session tracking + release

    /// Two concurrent presentations of the same template each keep their own live
    /// root; neither evicts the other, and `liveSession(for:)` resolves each web view
    /// to its own session (the P2 "shared warm-session slot" bug).
    func testConcurrentRootsOfSameTemplateBothResolve() {
        let webView1 = WKWebView(frame: .zero)
        let webView2 = WKWebView(frame: .zero)
        let (session1, _) = makeRootSession(templateKey: Self.key("home"), webView: webView1)
        let (session2, _) = makeRootSession(templateKey: Self.key("home"), webView: webView2)

        XCTAssertEqual(navigator.rootSessions.count, 2)
        // Neither root landed in the shared keyed pool.
        XCTAssertNil(navigator.sessions[Self.key("home")])
        // Each web view resolves to its own session — no eviction.
        XCTAssertTrue(navigator.liveSession(for: webView1) === session1)
        XCTAssertTrue(navigator.liveSession(for: webView2) === session2)
    }

    /// Releasing a ready root whose keyed slot is free demotes it to an off-stack
    /// reusable warm session; a subsequent lookup finds it off-stack in the pool.
    func testReleaseRootPresentationDemotesReadyRootToWarmPool() {
        let (session, host) = makeRootSession(templateKey: Self.key("home"), state: .ready)

        navigator.releaseRootPresentation(host)

        let demoted = navigator.sessions[Self.key("home")]
        XCTAssertTrue(demoted === session)
        XCTAssertEqual(demoted?.isOnStack, false)
        XCTAssertNotEqual(demoted?.state, .dead)
        XCTAssertFalse(navigator.rootSessions.contains { $0 === session })
    }

    /// Releasing a root whose keyed slot is already occupied by a warm session tears
    /// the root down (its web view released) rather than clobbering the slot.
    func testReleaseRootPresentationTearsDownWhenSlotOccupied() {
        makeWarmSession(templateKey: Self.key("home"), isOnStack: false)
        let occupyingWarm = navigator.sessions[Self.key("home")]
        let (rootSession, rootHost) = makeRootSession(templateKey: Self.key("home"), state: .ready)

        navigator.releaseRootPresentation(rootHost)

        // The pre-existing warm session keeps the slot; the root is dead and gone.
        XCTAssertTrue(navigator.sessions[Self.key("home")] === occupyingWarm)
        XCTAssertEqual(rootSession.state, .dead)
        XCTAssertFalse(navigator.rootSessions.contains { $0 === rootSession })
    }

    /// A root that is not `.ready` (still loading) is torn down on release, never
    /// demoted into the warm pool.
    func testReleaseRootPresentationTearsDownUnhealthyRoot() {
        let (rootSession, rootHost) = makeRootSession(
            templateKey: Self.key("home"),
            state: .loadingDocument
        )

        navigator.releaseRootPresentation(rootHost)

        XCTAssertNil(navigator.sessions[Self.key("home")])
        XCTAssertEqual(rootSession.state, .dead)
        XCTAssertFalse(navigator.rootSessions.contains { $0 === rootSession })
    }

    /// A double release is a no-op: the second call finds nothing in `rootSessions`
    /// and must not crash or disturb the demoted session.
    func testReleaseRootPresentationIsIdempotent() {
        let (session, host) = makeRootSession(templateKey: Self.key("home"), state: .ready)

        navigator.releaseRootPresentation(host)
        // Second release on the same (now-released) host.
        navigator.releaseRootPresentation(host)

        let demoted = navigator.sessions[Self.key("home")]
        XCTAssertTrue(demoted === session)
        XCTAssertEqual(demoted?.isOnStack, false)
        XCTAssertNotEqual(demoted?.state, .dead)
        XCTAssertTrue(navigator.rootSessions.isEmpty)
    }

    /// Releasing a root also resets its child navigation stack: a pushed warm detail
    /// leaves the stack (kept warm), a pushed ephemeral is torn down — exactly as
    /// `popToRoot` does — before the root itself is demoted.
    func testReleaseRootPresentationResetsChildStack() {
        let (rootSession, rootHost) = makeRootSession(templateKey: Self.key("home"), state: .ready)
        let warmDetailHost = makeWarmSession(templateKey: Self.key("standings"), isOnStack: true)
        let ephemeralHost = makeEphemeralSession(templateKey: Self.key("player-detail"))
        // Push a detail + an ephemeral onto the root's own child navigation stack.
        let navigationController = rootHost.navigationController!
        navigationController.setViewControllers([rootHost, warmDetailHost, ephemeralHost], animated: false)

        navigator.releaseRootPresentation(rootHost)

        // Pushed warm detail: off the stack but kept warm; ephemeral: torn down.
        XCTAssertEqual(navigator.sessions[Self.key("standings")]?.isOnStack, false)
        XCTAssertNotEqual(navigator.sessions[Self.key("standings")]?.state, .dead)
        XCTAssertTrue(navigator.ephemeralSessions.isEmpty)
        // Root demoted; stack reset to just the root host.
        XCTAssertTrue(navigator.sessions[Self.key("home")] === rootSession)
        XCTAssertEqual(navigationController.viewControllers.count, 1)
    }

    func testPopToRootAtRootIsNoOp() {
        let rootHost = makeWarmSession(templateKey: Self.key("home"), isOnStack: true)

        let navigationController = UINavigationController()
        navigationController.setViewControllers([rootHost], animated: false)

        navigator.popToRoot(in: navigationController)

        XCTAssertEqual(navigationController.viewControllers.count, 1)
        XCTAssertTrue(navigationController.viewControllers.first === rootHost)
        XCTAssertEqual(navigator.sessions[Self.key("home")]?.isOnStack, true)
        XCTAssertNotEqual(navigator.sessions[Self.key("home")]?.state, .dead)
    }
}
