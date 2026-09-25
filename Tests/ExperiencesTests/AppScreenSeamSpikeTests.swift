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

@testable import RoverExperiences

/// Spike coverage for the resolve-to-render seam: `AppScreenPendingNavigationStore`
/// enqueues/claims `PendingNavigation` records per `(AppScreensToken, AppScreenAddress)`,
/// and the `AppScreensContentView` render pipeline claims the correct record —
/// in FIFO order — as each destination materializes. Two layers are exercised:
/// (a) the store in isolation, and (b) the store driven through a real `NavigationStack`
/// render harness, which is the only way to falsify enqueue-before-render timing and
/// flow-scoped isolation.
@MainActor
final class AppScreenSeamSpikeTests: XCTestCase {
    // MARK: - Test doubles

    private final class PathModel: ObservableObject {
        @Published var path = NavigationPath()
    }

    private struct SeamTestHost: View {
        @ObservedObject var model: PathModel
        let registry: AppScreensPageRegistry
        let rootURL: URL
        let makeScreen: (AppScreensPageRequest) -> UIViewController

        var body: some View {
            NavigationStack(path: $model.path) {
                AppScreensContentView(
                    rootURL: rootURL,
                    path: $model.path,
                    registry: registry,
                    makeScreen: makeScreen,
                    sheetCollapse: AppScreensSheetCollapseCoordinator()
                )
            }
        }
    }

    // MARK: - Helpers

    private func url(_ path: String) -> URL {
        URL(string: "https://testbench.rover.io/a/\(path)")!
    }

    private func address(_ path: String) -> AppScreenAddress {
        AppScreenAddress(rawURL: url(path))!
    }

    private func makeSession(templateKey: String) -> AppScreenSession {
        AppScreenSession(templateKey: templateKey)
    }

    /// Spins the main run loop in small increments until `predicate` holds or the timeout
    /// elapses — so SwiftUI's make/dismantle transactions settle without a fixed sleep.
    /// Returns the final value of `predicate`.
    @discardableResult
    private func waitUntil(timeout: TimeInterval = 3.0, _ predicate: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        return predicate()
    }

    // MARK: - (a) Store unit tests

    func testDistinctFlowTokensAreNeverEqual() {
        XCTAssertNotEqual(AppScreensToken(), AppScreensToken())

        let token = AppScreensToken()
        XCTAssertEqual(token, token, "a token must equal itself")
    }

    func testClaimReturnsRecordsFIFOForASingleFlowAndAddress() {
        let store = AppScreenPendingNavigationStore()
        let token = AppScreensToken()
        let detailAddress = address("detail")

        let firstSession = makeSession(templateKey: "detail")
        let secondSession = makeSession(templateKey: "detail")
        let firstRecord = PendingNavigation(
            session: firstSession,
            resolvedURL: url("detail?id=1"),
            optimisticDataJSON: nil,
            isColdLoad: false,
            tapTime: .now()
        )
        let secondRecord = PendingNavigation(
            session: secondSession,
            resolvedURL: url("detail?id=2"),
            optimisticDataJSON: nil,
            isColdLoad: false,
            tapTime: .now()
        )

        store.enqueue(firstRecord, for: detailAddress, in: token)
        store.enqueue(secondRecord, for: detailAddress, in: token)

        let claimedFirst = store.claim(for: detailAddress, in: token)
        let claimedSecond = store.claim(for: detailAddress, in: token)

        XCTAssertTrue(
            claimedFirst?.session === firstSession,
            "the first claim must return the first-enqueued record (FIFO), not LIFO"
        )
        XCTAssertTrue(
            claimedSecond?.session === secondSession,
            "the second claim must return the second-enqueued record"
        )
    }

    func testClaimDoesNotCrossFlowsSharingTheSameAddress() {
        let store = AppScreenPendingNavigationStore()
        let tokenA = AppScreensToken()
        let tokenB = AppScreensToken()
        let detailAddress = address("detail")

        let tokenASession = makeSession(templateKey: "detail")
        let tokenBSession = makeSession(templateKey: "detail")

        store.enqueue(
            PendingNavigation(
                session: tokenASession,
                resolvedURL: url("detail?id=1"),
                optimisticDataJSON: nil,
                isColdLoad: false,
                tapTime: .now()
            ),
            for: detailAddress,
            in: tokenA
        )
        store.enqueue(
            PendingNavigation(
                session: tokenBSession,
                resolvedURL: url("detail?id=2"),
                optimisticDataJSON: nil,
                isColdLoad: false,
                tapTime: .now()
            ),
            for: detailAddress,
            in: tokenB
        )

        let claimedFromTokenA = store.claim(for: detailAddress, in: tokenA)

        XCTAssertTrue(
            claimedFromTokenA?.session === tokenASession,
            "claiming in tokenA must never return tokenB's record for the same address"
        )

        let claimedFromTokenB = store.claim(for: detailAddress, in: tokenB)
        XCTAssertTrue(
            claimedFromTokenB?.session === tokenBSession,
            "tokenB's own record must still be intact after tokenA claimed its own"
        )
    }

    func testClaimReturnsNilWhenEmptyOrExhausted() {
        let store = AppScreenPendingNavigationStore()
        let token = AppScreensToken()
        let detailAddress = address("detail")

        XCTAssertNil(
            store.claim(for: detailAddress, in: token),
            "claiming against a key with nothing enqueued must return nil"
        )

        store.enqueue(
            PendingNavigation(
                session: makeSession(templateKey: "detail"),
                resolvedURL: url("detail"),
                optimisticDataJSON: nil,
                isColdLoad: false,
                tapTime: .now()
            ),
            for: detailAddress,
            in: token
        )
        XCTAssertNotNil(store.claim(for: detailAddress, in: token))
        XCTAssertNil(
            store.claim(for: detailAddress, in: token),
            "claiming again after the single enqueued record is consumed must return nil"
        )
    }

    // MARK: - (b) Render-harness integration test

    /// Drives the actual seam: two `PendingNavigation`s are enqueued for the SAME
    /// `(flow, address)` before either destination renders (simulating a rapid
    /// detail→detail tap sequence where both navigations are dispatched before the first
    /// screen materializes), then the two destinations are appended to the path
    /// INCREMENTALLY — append, wait for the render/claim, append the next — mirroring
    /// Phase 1's proven behavior that `NavigationStack` only materializes the top
    /// destination of a single transaction. `makeScreen` is a stub (not the real
    /// navigate/selectSession pipeline): it claims from the store for the rendered
    /// address and records which session it attached to, in order.
    func testIncrementalPushesClaimPendingNavigationsFIFOAndRespectFlowIsolation() {
        let store = AppScreenPendingNavigationStore()
        let token = AppScreensToken()
        let otherToken = AppScreensToken()
        let detailAddress = address("detail")

        let firstSession = makeSession(templateKey: "detail")
        let secondSession = makeSession(templateKey: "detail")
        let otherTokenSession = makeSession(templateKey: "detail")

        // Both same-flow records are enqueued BEFORE either destination is appended —
        // this is the enqueue-before-render timing a bare store test cannot exercise.
        store.enqueue(
            PendingNavigation(
                session: firstSession,
                resolvedURL: url("detail?id=1"),
                optimisticDataJSON: nil,
                isColdLoad: false,
                tapTime: .now()
            ),
            for: detailAddress,
            in: token
        )
        store.enqueue(
            PendingNavigation(
                session: secondSession,
                resolvedURL: url("detail?id=2"),
                optimisticDataJSON: nil,
                isColdLoad: false,
                tapTime: .now()
            ),
            for: detailAddress,
            in: token
        )
        // A second flow's record for the identical address must never be claimed by
        // this flow's renders.
        store.enqueue(
            PendingNavigation(
                session: otherTokenSession,
                resolvedURL: url("detail?id=99"),
                optimisticDataJSON: nil,
                isColdLoad: false,
                tapTime: .now()
            ),
            for: detailAddress,
            in: otherToken
        )

        var claimedSessionIdentifiers: [ObjectIdentifier] = []
        let registry = AppScreensPageRegistry()
        let model = PathModel()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(
            rootView: SeamTestHost(
                model: model,
                registry: registry,
                rootURL: url("home"),
                makeScreen: { screenRequest in
                    guard screenRequest.address == detailAddress,
                        let claimed = store.claim(for: detailAddress, in: token)
                    else {
                        return UIViewController()
                    }
                    claimedSessionIdentifiers.append(ObjectIdentifier(claimed.session))
                    return UIViewController()
                }
            )
        )
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        model.path.append(AppScreenDestination(url: url("detail?id=1"))!)
        XCTAssertTrue(
            waitUntil { claimedSessionIdentifiers.count >= 1 },
            "the first appended destination should render and claim a pending navigation"
        )

        model.path.append(AppScreenDestination(url: url("detail?id=2"))!)
        XCTAssertTrue(
            waitUntil { claimedSessionIdentifiers.count >= 2 },
            "the second appended destination should render and claim a pending navigation"
        )

        XCTAssertEqual(claimedSessionIdentifiers.count, 2, "both hosts rendered and claimed exactly once")
        XCTAssertEqual(
            claimedSessionIdentifiers.first,
            ObjectIdentifier(firstSession),
            "the first-appended destination must claim the first-enqueued session (FIFO)"
        )
        XCTAssertEqual(
            claimedSessionIdentifiers.last,
            ObjectIdentifier(secondSession),
            "the second-appended destination must claim the second-enqueued session (FIFO)"
        )
        XCTAssertFalse(
            claimedSessionIdentifiers.contains(ObjectIdentifier(otherTokenSession)),
            "a different flow's identical-address record must never be claimed by this flow's renders"
        )

        // The other flow's record was never touched by this flow's renders — it is still
        // there, intact, for its own flow to claim.
        let otherTokenClaim = store.claim(for: detailAddress, in: otherToken)
        XCTAssertTrue(
            otherTokenClaim?.session === otherTokenSession,
            "the isolated flow's record must remain claimable on its own flow after the test flow's renders"
        )
    }
}
