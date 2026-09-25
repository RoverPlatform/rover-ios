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

/// Pins the timing contract between `HubHostingController.viewWillAppear`'s
/// dismiss-then-open handler flip and the driver's `openHandlersByToken` registry.
///
/// `HubHostingController` publishes `presentation.onOpenExternalURL` only at
/// `viewWillAppear` (it cannot know earlier whether the Hub is modal). The value is
/// threaded by value — `HubView.effectiveOpenExternalURL` → `HubContentView` →
/// `AppScreensHostView.makeScreen` → `makeRootHost(onOpenExternalURL:)` — and
/// `makeRootHost` registers it exactly once, when SwiftUI creates the root screen.
/// If the root screen is created while the published handler is still `nil` (the
/// host app preloads the controller's view before presenting, or renders the Hub
/// embedded and presents the same instance later), the flip must still reach the
/// registry, or a root-fired `openURL {dismiss:true}` opens without dismissing.
///
/// This suite mirrors that threading verbatim against an injected navigator (the
/// same pattern as `AppScreenNavigationParityTests`): one test covers the
/// device-matrix-verified ordering (flip lands before the root renders), the other
/// covers the late flip (root renders first, flip afterwards).
@MainActor
final class AppScreensLateOpenHandlerRegistrationTests: XCTestCase {
    /// Mirrors `HubPresentationState`: the handler starts `nil` (embedded default)
    /// and is published later, once the hosting controller resolves how it is hosted.
    private final class PresentationModel: ObservableObject {
        @Published var onOpenExternalURL: ((URL, Bool) -> Void)?
    }

    /// Mirrors the Hub's production wiring against an injected navigator: observes
    /// the presentation state and threads its current handler by value into
    /// `makeScreen`'s `.root` arm, exactly as `HubView` → `HubContentView` →
    /// `AppScreensHostView` do — including the production
    /// `syncAppScreensOpenHandler` modifier that propagates a late flip to the
    /// driver registry, so the mechanism under test is the shipped one.
    private struct LateHandlerTestHost: View {
        @ObservedObject var presentation: PresentationModel
        let rootURL: URL
        let token: AppScreensToken
        let registry: AppScreensPageRegistry
        let navigator: AppScreensDriver

        @State private var path = NavigationPath()

        var body: some View {
            let currentHandler = presentation.onOpenExternalURL
            NavigationStack(path: $path) {
                AppScreensContentView(
                    rootURL: rootURL,
                    path: $path,
                    registry: registry,
                    makeScreen: { [navigator] request in
                        switch request.role {
                        case .root:
                            return navigator.makeRootHost(
                                token: token,
                                url: request.targetRequest?.url ?? request.address.url,
                                navigating: request.navigating,
                                onDismiss: nil,
                                onOpenURL: nil,
                                onOpenExternalURL: currentHandler
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
                .syncAppScreensOpenHandler(currentHandler, for: token, on: navigator)
            }
        }
    }

    private var navigator: AppScreensDriver!
    private var window: UIWindow?
    private let configSuiteName = "io.rover.test.appscreens.lateOpenHandler.config"

    override func setUp() {
        super.setUp()
        navigator = Self.makeNavigator(configSuiteName: configSuiteName)
    }

    override func tearDown() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        // `makeRootHost` starts a real load pipeline on `URLSession.shared`; these
        // tests only assert handler registration, never pipeline completion. Cancel
        // any live pipeline so it cannot outlive the test and hit the network.
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

    private func hostInWindow(_ host: LateHandlerTestHost) {
        let hostWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        hostWindow.rootViewController = UIHostingController(rootView: host)
        hostWindow.makeKeyAndVisible()
        window = hostWindow
    }

    /// Spins the main run loop in small increments until `predicate` holds or the
    /// timeout elapses, so SwiftUI's make/update transactions settle without a fixed
    /// sleep (matches `AppScreensContentViewTests`/`AppScreenNavigationParityTests`).
    @discardableResult
    private func waitUntil(timeout: TimeInterval = 3.0, _ predicate: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        return predicate()
    }

    // MARK: - Tests

    /// The device-matrix-verified ordering (S2a × Deep-link): a plain
    /// `present(HubHostingController())` runs `viewWillAppear` before SwiftUI's first
    /// body evaluation, so the flip lands before the root screen is created and
    /// `makeRootHost` registers the real handler.
    func testHandlerPublishedBeforeFirstRenderIsRegisteredWithTheDriver() {
        let presentation = PresentationModel()
        presentation.onOpenExternalURL = { _, _ in }
        let token = AppScreensToken()

        hostInWindow(
            LateHandlerTestHost(
                presentation: presentation,
                rootURL: URL(string: "https://testbench.rover.io/a/home")!,
                token: token,
                registry: AppScreensPageRegistry(),
                navigator: navigator
            )
        )

        XCTAssertTrue(
            waitUntil { !self.navigator.rootSessions.isEmpty },
            "the root screen should render in the hosted window"
        )
        XCTAssertNotNil(
            navigator.openHandlersByToken[token],
            "a handler published before the root renders must be registered with the driver"
        )
    }

    /// The late flip: the root screen is created while the published handler is still
    /// `nil` (preloaded view, or an embedded Hub instance presented modally later),
    /// and `viewWillAppear` publishes the real handler afterwards. The flip must
    /// reach `openHandlersByToken`, or a root-fired `openURL {dismiss:true}` falls
    /// through to the best-effort system opener and never dismisses the Hub.
    func testHandlerPublishedAfterRootRenderReachesTheDriverRegistry() {
        let presentation = PresentationModel()
        let token = AppScreensToken()

        hostInWindow(
            LateHandlerTestHost(
                presentation: presentation,
                rootURL: URL(string: "https://testbench.rover.io/a/home")!,
                token: token,
                registry: AppScreensPageRegistry(),
                navigator: navigator
            )
        )

        XCTAssertTrue(
            waitUntil { !self.navigator.rootSessions.isEmpty },
            "the root screen should render in the hosted window"
        )
        XCTAssertNil(
            navigator.openHandlersByToken[token],
            "before the flip, no handler should be registered for the flow"
        )

        // The `viewWillAppear` flip: `HubHostingController` publishes the real
        // dismiss-then-open closure on the shared presentation state.
        presentation.onOpenExternalURL = { _, _ in }

        XCTAssertTrue(
            waitUntil { self.navigator.openHandlersByToken[token] != nil },
            "a handler published after the root renders must still reach the driver's "
                + "open-handler registry — otherwise openURL {dismiss:true} opens "
                + "without dismissing the Hub"
        )
    }
}
