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
import WebKit
import XCTest

@testable import RoverData
@testable import RoverExperiences

/// Exercises the production pop hook end to end: `AppScreensContentView`'s
/// `onPopScreen` is wired to `AppScreensDriver.handlePop(forHostedBy:)`, which
/// must fire from the real SwiftUI `dismantleUIViewController` teardown — not from a
/// direct call — when a pushed App Screen leaves the `NavigationPath`. An ephemeral
/// (detail→detail) session must be torn down; a warm template session must merely
/// leave the stack (kept warm off-stack) for reuse.
@MainActor
final class AppScreenDismantlePopTests: XCTestCase {
    // MARK: - Test doubles

    private final class PathModel: ObservableObject {
        @Published var path = NavigationPath()
    }

    private struct DismantlePopTestHost: View {
        @ObservedObject var model: PathModel
        let registry: AppScreensPageRegistry
        let rootURL: URL
        let makeScreen: (AppScreensPageRequest) -> UIViewController
        let onPopScreen: (UIViewController) -> Void

        var body: some View {
            NavigationStack(path: $model.path) {
                AppScreensContentView(
                    rootURL: rootURL,
                    path: $model.path,
                    registry: registry,
                    makeScreen: makeScreen,
                    onPopScreen: onPopScreen,
                    sheetCollapse: AppScreensSheetCollapseCoordinator()
                )
            }
        }
    }

    /// A minimal `AppScreensNavigating` conformer: `makeHost` only stores this as
    /// `session.navigating`, so its method bodies are never exercised here.
    private final class FakeNavigating: AppScreensNavigating {
        func pushScreen(address: AppScreenAddress, targetRequest: URLRequest?) {}
        func presentSheet(address: AppScreenAddress, targetRequest: URLRequest?, sheetToken: AppScreensToken) {}
        func presentWebsite(url: URL) {}
        func dismissRoot() {}
    }

    private var navigator: AppScreensDriver!
    private let configSuiteName = "io.rover.test.appscreens.dismantlePop.config"

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
    /// `AppScreenMakeHostTests.makeNavigator(configSuiteName:)`.
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

    /// Spins the main run loop in small increments until `predicate` holds or the timeout
    /// elapses — so SwiftUI's make/dismantle transactions settle without a fixed sleep.
    @discardableResult
    private func waitUntil(timeout: TimeInterval = 3.0, _ predicate: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        return predicate()
    }

    /// Hosts `DismantlePopTestHost` in a real `UIWindow`, driving the detail address
    /// through `AppScreensDriver.makeHost` (like production render-time host
    /// creation) and the root address through a plain placeholder host (root pop is
    /// out of scope for this test — its teardown is owned by `release`).
    private func makeWindow(
        model: PathModel,
        registry: AppScreensPageRegistry,
        detailAddress: AppScreenAddress,
        token: AppScreensToken,
        fakeNavigating: FakeNavigating
    ) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(
            rootView: DismantlePopTestHost(
                model: model,
                registry: registry,
                rootURL: url("home"),
                makeScreen: { [navigator] screenRequest in
                    guard screenRequest.address == detailAddress else {
                        return UIViewController()
                    }
                    return navigator!.makeHost(
                        token: token,
                        address: detailAddress,
                        targetRequest: screenRequest.targetRequest,
                        navigating: fakeNavigating
                    )
                },
                onPopScreen: { [navigator] host in
                    navigator!.handlePop(forHostedBy: host)
                }
            )
        )
        window.makeKeyAndVisible()
        return window
    }

    // MARK: - Ephemeral teardown

    func testDismantleTearsDownAnEphemeralSession() {
        let registry = AppScreensPageRegistry()
        let model = PathModel()
        let token = AppScreensToken()
        let detailAddress = address("detail-ephemeral")
        let fakeNavigating = FakeNavigating()

        let session = AppScreenSession(
            templateKey: detailAddress.url.absoluteString,
            webView: WKWebView(),
            state: .ready
        )
        session.isEphemeral = true
        session.documentURL = detailAddress.url
        navigator.ephemeralSessions.append(session)

        let record = PendingNavigation(
            session: session,
            resolvedURL: detailAddress.url,
            optimisticDataJSON: nil,
            isColdLoad: false,
            tapTime: .now()
        )
        navigator.pendingNavigations.enqueue(record, for: detailAddress, in: token)

        let window = makeWindow(
            model: model,
            registry: registry,
            detailAddress: detailAddress,
            token: token,
            fakeNavigating: fakeNavigating
        )
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        model.path.append(AppScreenDestination(url: detailAddress.url)!)
        XCTAssertTrue(
            waitUntil { session.hostViewController != nil },
            "the detail destination must render and claim the pending navigation, attaching a host"
        )
        XCTAssertTrue(
            waitUntil { navigator.sessionsByToken[token]?[ObjectIdentifier(session)] != nil },
            "makeHost must register the claimed session under the flow"
        )

        // Full reset of the path — this drives SwiftUI's `dismantleUIViewController`
        // teardown hook on the detail representable, which is the ONLY thing that
        // should trigger the pop below (no direct `handlePop` call here).
        model.path = NavigationPath()

        XCTAssertTrue(
            waitUntil { session.state == .dead },
            "dismantle must drive handlePop, which tears an ephemeral session down"
        )
        XCTAssertFalse(
            navigator.ephemeralSessions.contains { $0 === session },
            "the torn-down ephemeral session must be removed from ephemeralSessions"
        )
        XCTAssertNil(
            navigator.sessionsByToken[token]?[ObjectIdentifier(session)],
            "handlePop(forHostedBy:) must de-register the session from its flow"
        )
    }

    // MARK: - Warm keep-off-stack

    func testDismantleKeepsAWarmSessionOffStackWithoutTearingItDown() {
        let registry = AppScreensPageRegistry()
        let model = PathModel()
        let token = AppScreensToken()
        let detailAddress = address("detail-warm")
        let fakeNavigating = FakeNavigating()

        let session = AppScreenSession(
            templateKey: detailAddress.url.absoluteString,
            webView: WKWebView(),
            state: .ready
        )
        session.isEphemeral = false
        session.isOnStack = true
        session.documentURL = detailAddress.url
        navigator.sessions[session.templateKey] = session

        let record = PendingNavigation(
            session: session,
            resolvedURL: detailAddress.url,
            optimisticDataJSON: nil,
            isColdLoad: false,
            tapTime: .now()
        )
        navigator.pendingNavigations.enqueue(record, for: detailAddress, in: token)

        let window = makeWindow(
            model: model,
            registry: registry,
            detailAddress: detailAddress,
            token: token,
            fakeNavigating: fakeNavigating
        )
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        model.path.append(AppScreenDestination(url: detailAddress.url)!)
        XCTAssertTrue(
            waitUntil { session.hostViewController != nil },
            "the detail destination must render and claim the pending navigation, attaching a host"
        )
        XCTAssertTrue(
            waitUntil { navigator.sessionsByToken[token]?[ObjectIdentifier(session)] != nil },
            "makeHost must register the claimed session under the flow"
        )

        // Full reset of the path — drives the real `dismantleUIViewController` hook.
        model.path = NavigationPath()

        XCTAssertTrue(
            waitUntil { !session.isOnStack },
            "dismantle must drive handlePop, which takes a warm session off the stack"
        )
        XCTAssertEqual(session.state, .ready, "a warm session kept off-stack must never be torn down")
        XCTAssertNotNil(session.webView, "a warm session's web view must survive the pop")
        XCTAssertNil(
            navigator.sessionsByToken[token]?[ObjectIdentifier(session)],
            "handlePop(forHostedBy:) must de-register the session from its flow"
        )
    }
}
