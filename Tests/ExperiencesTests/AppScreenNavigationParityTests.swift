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

import SwiftUI
import UIKit
import XCTest

@testable import RoverData
@testable import RoverExperiences

/// The end-to-end sign-off for the Hub SwiftUI cutover (2a): drives the FULLY WIRED
/// production path — a real `AppScreensDriver`, a real `AppScreensContentView`,
/// and a `makeScreen` closure that routes `.root`/`.pushed`/`.sheetRoot` exactly the
/// way `AppScreensHostView` does — through a real `navigate` call, never a stub.
///
/// Unlike `AppScreenMakeHostTests`/`AppScreenRootFlowTests` (which drive `makeHost`/
/// `makeRootHost` directly against a hand-built `PendingNavigation`) and
/// `AppScreenDismantlePopTests` (which drives only the pop half against a
/// hand-installed session), this suite starts from a bridge-shaped `navigate(href:…)`
/// call and lets the real pipeline — resolve → select → enqueue → `pushScreen` →
/// SwiftUI materialize → `makeHost`/`makeRootHost` → attach + pipeline — run
/// unassisted, the seam the stubbed seam spikes could not prove end-to-end.
///
/// This suite targets the Hub SwiftUI path only: concurrent-flow isolation (test 4)
/// is proven with two flow tokens / two hosted `AppScreensContentView`s sharing one
/// navigator, rather than a Hub-vs-standalone pair.
@MainActor
final class AppScreenNavigationParityTests: XCTestCase {
    // MARK: - Test doubles

    private final class PathModel: ObservableObject {
        @Published var path = NavigationPath()
    }

    /// Mirrors `AppScreensHostView`'s production `makeScreen`/`onPopScreen` wiring
    /// verbatim, against an injected test navigator and a caller-supplied flow
    /// token, so the seam under test is byte-for-byte what the Hub ships.
    private struct ParityTestHost: View {
        @ObservedObject var model: PathModel
        let registry: AppScreensPageRegistry
        let rootURL: URL
        let token: AppScreensToken
        let navigator: AppScreensDriver

        var body: some View {
            NavigationStack(path: $model.path) {
                AppScreensContentView(
                    rootURL: rootURL,
                    path: $model.path,
                    registry: registry,
                    makeScreen: { [navigator] request in
                        switch request.role {
                        case .root:
                            return navigator.makeRootHost(
                                token: token,
                                url: request.targetRequest?.url ?? request.address.url,
                                navigating: request.navigating,
                                onDismiss: nil,
                                onOpenURL: nil
                            )
                        case .pushed:
                            return navigator.makeHost(
                                token: token,
                                address: request.address,
                                targetRequest: request.targetRequest,
                                navigating: request.navigating
                            )
                        case .sheetRoot:
                            return UIViewController()
                        }
                    },
                    onPopScreen: { [navigator] host in
                        navigator.handlePop(forHostedBy: host)
                    },
                    sheetCollapse: AppScreensSheetCollapseCoordinator()
                )
            }
        }
    }

    private var navigator: AppScreensDriver!
    private let configSuiteName = "io.rover.test.appscreens.navigationParity.config"

    override func setUp() {
        super.setUp()
        navigator = Self.makeNavigator(configSuiteName: configSuiteName)
    }

    override func tearDown() {
        navigator = nil
        UserDefaults(suiteName: configSuiteName)?.removePersistentDomain(forName: configSuiteName)
        super.tearDown()
    }

    /// Builds a real navigator with throwaway dependencies, mirroring every other
    /// `AppScreensDriver` integration test in this target.
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

    // MARK: - Helpers

    private func url(_ path: String) -> URL {
        URL(string: "https://testbench.rover.io/a/\(path)")!
    }

    private func address(_ path: String) -> AppScreenAddress {
        AppScreenAddress(rawURL: url(path))!
    }

    /// Spins the main run loop in small increments until `predicate` holds or the
    /// timeout elapses, so SwiftUI's make/dismantle transactions settle without a
    /// fixed sleep (matches `AppScreenDismantlePopTests`/`AppScreenHostVisibilitySpikeTests`).
    @discardableResult
    private func waitUntil(timeout: TimeInterval = 3.0, _ predicate: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        return predicate()
    }

    /// Hosts `ParityTestHost` in a real `UIWindow` under `flow`, wired to the shared
    /// `navigator`.
    private func makeWindow(
        model: PathModel,
        registry: AppScreensPageRegistry,
        rootURL: URL,
        token: AppScreensToken
    ) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(
            rootView: ParityTestHost(
                model: model,
                registry: registry,
                rootURL: rootURL,
                token: token,
                navigator: navigator
            )
        )
        window.makeKeyAndVisible()
        return window
    }

    // MARK: - 1. End-to-end bridge push → attach + pipeline

    /// Drives a real `navigate(href:…)` from a real `makeRootHost`-vended root and
    /// proves the whole seam fires unassisted: `navigate` enqueues a
    /// `PendingNavigation` and calls the real production `AppScreensNavigating`
    /// coordinator's `pushScreen`, which appends an `AppScreenDestination` onto the
    /// SwiftUI path; that render calls `makeScreen` with `.pushed`, which calls
    /// `makeHost`, which claims the record, attaches the host, and starts the load
    /// pipeline. This is the exact navigate→enqueue→pushScreen→render→makeHost→attach
    /// chain the stubbed seam spikes could not exercise.
    func testBridgePushAttachesHostAndStartsPipelineEndToEnd() throws {
        let model = PathModel()
        let registry = AppScreensPageRegistry()
        let token = AppScreensToken()
        let window = makeWindow(model: model, registry: registry, rootURL: url("home"), token: token)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        XCTAssertTrue(
            waitUntil { self.navigator.rootSessions.contains { $0.token == token } },
            "the stack root must render through the real makeScreen(.root) → makeRootHost and register under the flow"
        )
        let rootSession = try XCTUnwrap(navigator.rootSessions.first { $0.token == token })
        XCTAssertNotNil(
            rootSession.navigating,
            "makeRootHost must stamp the production AppScreensNavigating coordinator onto the root session"
        )

        let detailAddress = address("detail-bridge")
        navigator.navigate(
            href: detailAddress.url.absoluteString,
            optimisticDataJSON: nil,
            transition: .push,
            from: rootSession
        )

        let templateKey = try XCTUnwrap(AppScreensDriver.templateKey(from: detailAddress.url))
        XCTAssertTrue(
            waitUntil { self.navigator.sessions[templateKey]?.hostViewController != nil },
            "navigate must enqueue + call the real coordinator's pushScreen, driving the path append that renders the "
                + "navigationDestination and calls makeHost, which attaches a host"
        )
        let detailSession = try XCTUnwrap(navigator.sessions[templateKey])

        XCTAssertTrue(detailSession.isOnStack, "navigate sets isOnStack synchronously at resolve time")
        XCTAssertNotNil(
            detailSession.hostViewController,
            "makeHost must attach the claimed session's host at render time"
        )
        XCTAssertNotNil(detailSession.pipelineTask, "makeHost must start the navigate pipeline at render time")
    }

    // MARK: - 2. Pop → warm kept / ephemeral torn down

    /// A single push to a fresh template selects `.cold` (stored as the template's
    /// warm session). Resetting the path drives the pushed screen's real
    /// `dismantleUIViewController` → `onPopScreen` → `handlePop(forHostedBy:)`, which
    /// must take the warm session off the stack without tearing it down.
    func testPopKeepsWarmDetailSessionOffStackWithoutTearingDown() throws {
        let model = PathModel()
        let registry = AppScreensPageRegistry()
        let token = AppScreensToken()
        let window = makeWindow(model: model, registry: registry, rootURL: url("home"), token: token)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        XCTAssertTrue(waitUntil { self.navigator.rootSessions.contains { $0.token == token } })
        let rootSession = try XCTUnwrap(navigator.rootSessions.first { $0.token == token })

        let detailAddress = address("detail-warm")
        let templateKey = try XCTUnwrap(AppScreensDriver.templateKey(from: detailAddress.url))
        navigator.navigate(
            href: detailAddress.url.absoluteString,
            optimisticDataJSON: nil,
            transition: .push,
            from: rootSession
        )
        XCTAssertTrue(
            waitUntil { self.navigator.sessions[templateKey]?.hostViewController != nil },
            "the detail must render and attach before the pop under test can be meaningful"
        )
        let detailSession = try XCTUnwrap(navigator.sessions[templateKey])
        XCTAssertFalse(detailSession.isEphemeral, "a first push to a fresh template selects .cold, not .ephemeral")

        // Full reset — drives the real dismantleUIViewController teardown hook, never
        // a direct handlePop call.
        model.path = NavigationPath()

        XCTAssertTrue(
            waitUntil { !detailSession.isOnStack },
            "dismantle must drive handlePop(forHostedBy:), which takes a warm session off the stack"
        )
        XCTAssertNotEqual(detailSession.state, .dead, "a warm session kept off-stack must never be torn down")
        XCTAssertTrue(
            navigator.sessions[templateKey] === detailSession,
            "the warm session must remain the template's reusable slot after the pop"
        )
    }

    /// Pushing the same template a second time while the first is still on-stack
    /// forces `.ephemeral` (`selectSession(hasWarmReady:isOnStack:)`). Resetting the
    /// path must tear the ephemeral session down (dead, removed from
    /// `ephemeralSessions`) while the warm template session underneath it is merely
    /// kept off-stack — both outcomes driven by the same real dismantle hook.
    func testPopTearsDownEphemeralSessionWhileKeepingTheWarmOneBeneathItAlive() throws {
        let model = PathModel()
        let registry = AppScreensPageRegistry()
        let token = AppScreensToken()
        let window = makeWindow(model: model, registry: registry, rootURL: url("home"), token: token)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        XCTAssertTrue(waitUntil { self.navigator.rootSessions.contains { $0.token == token } })
        let rootSession = try XCTUnwrap(navigator.rootSessions.first { $0.token == token })

        let detailAddress = address("detail-repeat")
        let templateKey = try XCTUnwrap(AppScreensDriver.templateKey(from: detailAddress.url))

        // First push: selects .cold, becomes the template's warm session.
        navigator.navigate(
            href: detailAddress.url.absoluteString,
            optimisticDataJSON: nil,
            transition: .push,
            from: rootSession
        )
        XCTAssertTrue(waitUntil { self.navigator.sessions[templateKey]?.hostViewController != nil })
        let warmSession = try XCTUnwrap(navigator.sessions[templateKey])

        // Second push to the SAME template while the first is still on-stack: the
        // synchronous `session.isOnStack = true` navigate already set forces
        // `.ephemeral`, never `.reuse`.
        navigator.navigate(
            href: detailAddress.url.absoluteString,
            optimisticDataJSON: nil,
            transition: .push,
            from: rootSession
        )
        XCTAssertTrue(
            waitUntil {
                self.navigator.ephemeralSessions.contains {
                    $0.templateKey == templateKey && $0.hostViewController != nil
                }
            },
            "the detail→detail repeat push must render its own ephemeral session"
        )
        let ephemeralSession = try XCTUnwrap(
            navigator.ephemeralSessions.first { $0.templateKey == templateKey && $0.hostViewController != nil }
        )
        XCTAssertFalse(warmSession === ephemeralSession, "the ephemeral must be a distinct session from the warm one")

        // Full reset — dismantles both pushed destinations.
        model.path = NavigationPath()

        XCTAssertTrue(
            waitUntil { ephemeralSession.state == .dead },
            "dismantle must drive handlePop for the ephemeral, tearing it down"
        )
        XCTAssertFalse(
            navigator.ephemeralSessions.contains { $0 === ephemeralSession },
            "the torn-down ephemeral must be removed from ephemeralSessions"
        )
        XCTAssertTrue(
            waitUntil { !warmSession.isOnStack },
            "dismantle must also drive handlePop for the warm session, taking it off-stack"
        )
        XCTAssertNotEqual(warmSession.state, .dead, "the warm session beneath the ephemeral must never be torn down")
    }

    // MARK: - 3. Visibility from isVisible (integrated)

    /// Drives real navigation to move a rendered detail host through visible →
    /// occluded (a second detail pushed over it) → off-stack (popped), asserting
    /// `AppScreensDriver.visibility(of:)` at each real state — proving the Task-3
    /// `isVisible` flag drives visibility on a host that actually went through
    /// SwiftUI's appearance callbacks, not a manually-invoked one.
    func testVisibilityTracksRealPushOcclusionAndPop() throws {
        let model = PathModel()
        let registry = AppScreensPageRegistry()
        let token = AppScreensToken()
        let window = makeWindow(model: model, registry: registry, rootURL: url("home"), token: token)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        XCTAssertTrue(waitUntil { self.navigator.rootSessions.contains { $0.token == token } })
        let rootSession = try XCTUnwrap(navigator.rootSessions.first { $0.token == token })

        let firstAddress = address("detail-visible")
        let firstTemplateKey = try XCTUnwrap(AppScreensDriver.templateKey(from: firstAddress.url))
        navigator.navigate(
            href: firstAddress.url.absoluteString,
            optimisticDataJSON: nil,
            transition: .push,
            from: rootSession
        )
        XCTAssertTrue(waitUntil { self.navigator.sessions[firstTemplateKey]?.hostViewController != nil })
        let firstSession = try XCTUnwrap(navigator.sessions[firstTemplateKey])

        XCTAssertTrue(
            waitUntil { firstSession.hostViewController?.isVisible == true },
            "a freshly pushed, on-top host must appear (real viewDidAppear, not a stub)"
        )
        XCTAssertEqual(AppScreensDriver.visibility(of: firstSession), .visible)

        // Push a second detail on top of the first from the first session's own host
        // — this covers the first, driving its real viewDidDisappear.
        let secondAddress = address("detail-visible-2")
        navigator.navigate(
            href: secondAddress.url.absoluteString,
            optimisticDataJSON: nil,
            transition: .push,
            from: firstSession
        )
        XCTAssertTrue(
            waitUntil { firstSession.hostViewController?.isVisible == false },
            "covering the first detail with a second push must disappear it (real viewDidDisappear)"
        )
        XCTAssertEqual(
            AppScreensDriver.visibility(of: firstSession),
            .occluded,
            "on-stack but not the top reads as occluded"
        )

        // Full reset — pops both, taking the first off the stack entirely.
        model.path = NavigationPath()
        XCTAssertTrue(waitUntil { !firstSession.isOnStack })
        XCTAssertEqual(AppScreensDriver.visibility(of: firstSession), .offStack)
    }

    // MARK: - 4. Two concurrent flows don't cross-bind

    /// Hosts TWO `AppScreensContentView`s sharing one navigator, each under its own
    /// flow token, and navigates both roots to the SAME detail template. Because
    /// `selectSession` forces `.ephemeral` once a template is on-stack (independent of
    /// flow), the second flow's push can never reuse the first flow's warm session —
    /// each flow's render must claim and register its OWN session under its OWN flow,
    /// proving cross-flow isolation end-to-end (not just via the pending
    /// store's key structure in isolation).
    func testConcurrentFlowsToTheSameTemplateDoNotCrossBind() throws {
        let modelA = PathModel()
        let registryA = AppScreensPageRegistry()
        let tokenA = AppScreensToken()
        let windowA = makeWindow(model: modelA, registry: registryA, rootURL: url("home"), token: tokenA)

        let modelB = PathModel()
        let registryB = AppScreensPageRegistry()
        let tokenB = AppScreensToken()
        let windowB = makeWindow(model: modelB, registry: registryB, rootURL: url("home"), token: tokenB)

        defer {
            windowA.isHidden = true
            windowA.rootViewController = nil
            windowB.isHidden = true
            windowB.rootViewController = nil
        }

        XCTAssertTrue(waitUntil { self.navigator.rootSessions.contains { $0.token == tokenA } })
        XCTAssertTrue(waitUntil { self.navigator.rootSessions.contains { $0.token == tokenB } })
        let rootA = try XCTUnwrap(navigator.rootSessions.first { $0.token == tokenA })
        let rootB = try XCTUnwrap(navigator.rootSessions.first { $0.token == tokenB })

        let sharedAddress = address("detail-shared")
        let templateKey = try XCTUnwrap(AppScreensDriver.templateKey(from: sharedAddress.url))

        navigator.navigate(
            href: sharedAddress.url.absoluteString,
            optimisticDataJSON: nil,
            transition: .push,
            from: rootA
        )
        XCTAssertTrue(
            waitUntil { self.navigator.sessions[templateKey]?.hostViewController != nil },
            "flow A's push must render and claim the warm slot for the shared template"
        )
        let detailA = try XCTUnwrap(navigator.sessions[templateKey])

        navigator.navigate(
            href: sharedAddress.url.absoluteString,
            optimisticDataJSON: nil,
            transition: .push,
            from: rootB
        )
        XCTAssertTrue(
            waitUntil {
                self.navigator.ephemeralSessions.contains {
                    $0.templateKey == templateKey && $0.hostViewController != nil
                }
            },
            "flow B's push to the same, now on-stack template must render its OWN ephemeral session, never reuse flow A's"
        )
        let detailB = try XCTUnwrap(
            navigator.ephemeralSessions.first { $0.templateKey == templateKey && $0.hostViewController != nil }
        )

        XCTAssertFalse(detailA === detailB, "the two flows' detail sessions must be distinct objects")
        XCTAssertEqual(detailA.token, tokenA, "flow A's detail session must be stamped with flow A's token")
        XCTAssertEqual(detailB.token, tokenB, "flow B's detail session must be stamped with flow B's token")

        XCTAssertNotNil(
            navigator.sessionsByToken[tokenA]?[ObjectIdentifier(detailA)],
            "flow A must own its own detail session in sessionsByToken"
        )
        XCTAssertNotNil(
            navigator.sessionsByToken[tokenB]?[ObjectIdentifier(detailB)],
            "flow B must own its own detail session in sessionsByToken"
        )
        XCTAssertNil(
            navigator.sessionsByToken[tokenA]?[ObjectIdentifier(detailB)],
            "flow A must never claim flow B's detail session"
        )
        XCTAssertNil(
            navigator.sessionsByToken[tokenB]?[ObjectIdentifier(detailA)],
            "flow B must never claim flow A's detail session"
        )
        XCTAssertNotNil(
            navigator.sessionsByToken[tokenA]?[ObjectIdentifier(rootA)],
            "flow A's own root session must also be registered under flow A"
        )
        XCTAssertNotNil(
            navigator.sessionsByToken[tokenB]?[ObjectIdentifier(rootB)],
            "flow B's own root session must also be registered under flow B"
        )
    }
}
