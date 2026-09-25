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

/// The 2b direct-logic sign-off for the whole sheet seam: `navigate(transition:
/// .sheet)` minting a fresh flow token and enqueuing without a UIKit host,
/// `makeHost` claiming that record at render time, an in-sheet `.push` scoping to
/// the same sheet token, `release` returning/tearing down the flow's owned
/// sessions, flow-token isolation between two concurrent sheets, and the injected
/// open-handler seam clearing on release. Rendering a real
/// `.sheet`/`fullScreenCover` and observing
/// `.onAppear`/`@StateObject` teardown is flaky in this headless SPM bundle, so
/// every test here drives the navigator's logic directly — no `UIWindow`, no
/// `.sheet`, no `waitUntil`. The genuine modal lifecycle (present, swipe-dismiss,
/// sheet-on-sheet transitive teardown, `onChange(of: path)` auto-dismiss,
/// `fullScreenCover`, dismiss-then-open ordering) is validated manually in
/// Testbench, not by this suite.
@MainActor
final class AppScreenSheetParityTests: XCTestCase {

    private var navigator: AppScreensDriver!
    private let configSuiteName = "io.rover.test.appscreens.sheetParity.config"

    override func setUp() {
        super.setUp()
        navigator = Self.makeNavigator(configSuiteName: configSuiteName)
    }

    override func tearDown() {
        navigator = nil
        UserDefaults(suiteName: configSuiteName)?.removePersistentDomain(forName: configSuiteName)
        super.tearDown()
    }

    /// Builds a real navigator with throwaway dependencies. Mirrors
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

    /// The origin-qualified key for a template on the test's associated domain.
    private static func key(_ templatePath: String) -> String {
        "https://testbench.rover.io/a/\(templatePath)"
    }

    /// Builds a source session with a real web view and document URL, ready to
    /// originate a `navigate`/`openURL` bridge message.
    private func makeSourceSession(templateKey: String, documentURL: URL) -> AppScreenSession {
        let session = AppScreenSession(templateKey: templateKey, webView: WKWebView(), state: .ready)
        session.documentURL = documentURL
        // A screen that can post a bridge message is on a navigation stack: the
        // driver drops a `navigate` from an off-stack (popped-but-warm, or
        // prewarming) source, so the fixture must reflect a live screen.
        session.isOnStack = true
        return session
    }

    /// A fake `AppScreensNavigating` that records every `pushScreen`/`presentSheet`
    /// call so tests can assert the sheet seam drives the navigating protocol
    /// instead of UIKit, and capture the minted sheet token.
    private final class FakeNavigating: AppScreensNavigating {
        private(set) var pushedAddresses: [AppScreenAddress] = []
        private(set) var capturedSheetTokens: [AppScreensToken] = []

        func pushScreen(address: AppScreenAddress, targetRequest: URLRequest?) {
            pushedAddresses.append(address)
        }

        func presentSheet(address: AppScreenAddress, targetRequest: URLRequest?, sheetToken: AppScreensToken) {
            capturedSheetTokens.append(sheetToken)
        }

        func presentWebsite(url: URL) {}

        func dismissRoot() {}
    }

    // MARK: - (a) navigate(.sheet) mints a fresh token and enqueues without a host

    /// A `.sheet` navigate from a flow-tokened source mints a fresh sheet token
    /// (never the source's own), enqueues exactly one pending record under
    /// `(address, mintedToken)`, marks the target session `isOnStack`, and never
    /// builds a UIKit host — host creation is deferred to render-time `makeHost`.
    func testNavigateSheetEnqueuesAndCallsPresentSheetWithoutUIKitHost() throws {
        let homeURL = URL(string: "https://testbench.rover.io/a/home")!
        let source = makeSourceSession(templateKey: Self.key("home"), documentURL: homeURL)
        let sourceToken = AppScreensToken()
        source.token = sourceToken
        let fakeNavigating = FakeNavigating()
        source.navigating = fakeNavigating

        navigator.navigate(
            href: "https://testbench.rover.io/a/sheet-detail",
            optimisticDataJSON: nil,
            transition: .sheet,
            from: source
        )

        XCTAssertEqual(fakeNavigating.capturedSheetTokens.count, 1)
        let sheetToken = try XCTUnwrap(fakeNavigating.capturedSheetTokens.first)
        XCTAssertNotEqual(
            sheetToken,
            sourceToken,
            "a sheet always mints a fresh flow token, never reusing the source's"
        )

        let detailSession = try XCTUnwrap(navigator.sessions[Self.key("sheet-detail")])
        XCTAssertTrue(detailSession.isOnStack, "isOnStack is set at navigate time, not render time")
        XCTAssertNil(detailSession.hostViewController, "no UIKit host is built on the flow-tokened sheet path")

        let address = try XCTUnwrap(
            AppScreenAddress(rawURL: URL(string: "https://testbench.rover.io/a/sheet-detail")!)
        )
        let firstClaim = try XCTUnwrap(navigator.pendingNavigations.claim(for: address, in: sheetToken))
        XCTAssertTrue(firstClaim.session === detailSession)
        XCTAssertNil(
            navigator.pendingNavigations.claim(for: address, in: sheetToken),
            "the pending record is consumed by the first claim"
        )
    }

    // MARK: - (b) makeHost claims the sheet root under the minted token

    /// What `AppScreensSheetHostView` does at render: claims the pending record
    /// under the minted sheet token, stamps `token`/`hostViewController`, and
    /// starts the load pipeline.
    func testSheetRootMakeHostClaimsUnderMintedTokenAndStartsPipeline() throws {
        let templateKey = Self.key("sheet-root")
        let address = try XCTUnwrap(AppScreenAddress(rawURL: URL(string: templateKey)!))
        let sheetToken = AppScreensToken()

        let session = AppScreenSession(templateKey: templateKey, webView: WKWebView(), state: .ready)
        session.isOnStack = true
        session.documentURL = address.url

        let record = PendingNavigation(
            session: session,
            resolvedURL: address.url,
            optimisticDataJSON: nil,
            isColdLoad: false,
            tapTime: .now()
        )
        navigator.pendingNavigations.enqueue(record, for: address, in: sheetToken)

        let host = navigator.makeHost(
            token: sheetToken,
            address: address,
            targetRequest: nil,
            navigating: FakeNavigating()
        )

        let hostViewController = try XCTUnwrap(host as? AppScreensPageViewController)
        XCTAssertTrue(session.hostViewController === hostViewController)
        XCTAssertEqual(session.token, sheetToken)
        XCTAssertNotNil(session.pipelineTask)
    }

    // MARK: - (c) an in-sheet push scopes to the same sheet token

    /// A `.push` originating from a sheet-root session (already carrying the sheet's
    /// flow token, stamped by `makeHost`) enqueues its pending record under that SAME
    /// token — proving in-sheet pushes stay scoped to the sheet's own flow rather
    /// than starting a new one.
    func testInSheetPushEnqueuesUnderSameSheetToken() throws {
        let templateKey = Self.key("sheet-root-push")
        let address = try XCTUnwrap(AppScreenAddress(rawURL: URL(string: templateKey)!))
        let sheetToken = AppScreensToken()

        let sheetRootSession = AppScreenSession(templateKey: templateKey, webView: WKWebView(), state: .ready)
        sheetRootSession.isOnStack = true
        sheetRootSession.documentURL = address.url

        let record = PendingNavigation(
            session: sheetRootSession,
            resolvedURL: address.url,
            optimisticDataJSON: nil,
            isColdLoad: false,
            tapTime: .now()
        )
        navigator.pendingNavigations.enqueue(record, for: address, in: sheetToken)

        let fakeNavigating = FakeNavigating()
        _ = navigator.makeHost(token: sheetToken, address: address, targetRequest: nil, navigating: fakeNavigating)

        navigator.navigate(
            href: "https://testbench.rover.io/a/sheet-pushed-detail",
            optimisticDataJSON: nil,
            transition: .push,
            from: sheetRootSession
        )

        XCTAssertEqual(fakeNavigating.pushedAddresses.count, 1, "the in-sheet push must drive the navigating seam")

        let pushedAddress = try XCTUnwrap(
            AppScreenAddress(rawURL: URL(string: "https://testbench.rover.io/a/sheet-pushed-detail")!)
        )
        let claimed = try XCTUnwrap(navigator.pendingNavigations.claim(for: pushedAddress, in: sheetToken))
        XCTAssertNotNil(claimed.session)
        XCTAssertNil(
            navigator.pendingNavigations.claim(for: pushedAddress, in: sheetToken),
            "only one record should have been enqueued for the pushed address under the sheet token"
        )
    }

    // MARK: - (d) release pools a warm session and tears down an ephemeral one

    /// A sheet flow has no `rootSessions` entry, so `release` must treat
    /// every owned session as a non-root "pushed" detail: a warm/template session
    /// returns to the shared `sessions` pool (off-stack, retained); an ephemeral
    /// session is torn down and removed. Both are registered into `sessionsByToken`
    /// via `makeHost`, mirroring how `AppScreensSheetHostView` would attach them.
    func testReleaseFlowReturnsWarmSheetSessionAndTearsDownEphemeral() throws {
        let sheetToken = AppScreensToken()

        let warmTemplateKey = Self.key("sheet-warm-detail")
        let warmAddress = try XCTUnwrap(AppScreenAddress(rawURL: URL(string: warmTemplateKey)!))
        let warmSession = AppScreenSession(templateKey: warmTemplateKey, webView: WKWebView(), state: .ready)
        warmSession.isOnStack = true
        warmSession.documentURL = warmAddress.url
        warmSession.isEphemeral = false
        navigator.sessions[warmTemplateKey] = warmSession

        let warmRecord = PendingNavigation(
            session: warmSession,
            resolvedURL: warmAddress.url,
            optimisticDataJSON: nil,
            isColdLoad: false,
            tapTime: .now()
        )
        navigator.pendingNavigations.enqueue(warmRecord, for: warmAddress, in: sheetToken)
        _ = navigator.makeHost(
            token: sheetToken,
            address: warmAddress,
            targetRequest: nil,
            navigating: FakeNavigating()
        )

        let ephemeralTemplateKey = Self.key("sheet-ephemeral-detail")
        let ephemeralAddress = try XCTUnwrap(AppScreenAddress(rawURL: URL(string: ephemeralTemplateKey)!))
        let ephemeralSession = AppScreenSession(templateKey: ephemeralTemplateKey, webView: WKWebView(), state: .ready)
        ephemeralSession.isOnStack = true
        ephemeralSession.documentURL = ephemeralAddress.url
        ephemeralSession.isEphemeral = true
        navigator.ephemeralSessions.append(ephemeralSession)

        let ephemeralRecord = PendingNavigation(
            session: ephemeralSession,
            resolvedURL: ephemeralAddress.url,
            optimisticDataJSON: nil,
            isColdLoad: true,
            tapTime: .now()
        )
        navigator.pendingNavigations.enqueue(ephemeralRecord, for: ephemeralAddress, in: sheetToken)
        _ = navigator.makeHost(
            token: sheetToken,
            address: ephemeralAddress,
            targetRequest: nil,
            navigating: FakeNavigating()
        )

        let registeredSessions = try XCTUnwrap(navigator.sessionsByToken[sheetToken])
        XCTAssertTrue(registeredSessions.values.contains { $0 === warmSession })
        XCTAssertTrue(registeredSessions.values.contains { $0 === ephemeralSession })
        XCTAssertFalse(navigator.rootSessions.contains { $0 === warmSession || $0 === ephemeralSession })

        navigator.release(sheetToken)

        XCTAssertFalse(warmSession.isOnStack)
        XCTAssertTrue(navigator.sessions[warmTemplateKey] === warmSession, "the warm session stays pooled, off-stack")
        XCTAssertFalse(
            navigator.ephemeralSessions.contains { $0 === ephemeralSession },
            "the ephemeral session must be torn down and removed"
        )
        XCTAssertNil(navigator.sessionsByToken[sheetToken])
    }

    // MARK: - (e) two concurrent sheet flows don't cross-bind

    /// Two flows queue a pending record for the SAME address (tokenA enqueued
    /// first, then tokenB — an address-only-FIFO regression would wrongly hand
    /// tokenB's `makeHost` the tokenA record). `makeHost(flow: tokenB, …)` must claim
    /// only tokenB's own record; tokenA's stays claimable and its session unstamped.
    func testTwoConcurrentSheetFlowsDoNotCrossBind() throws {
        let templateKey = Self.key("sheet-shared-detail")
        let address = try XCTUnwrap(AppScreenAddress(rawURL: URL(string: templateKey)!))

        let tokenA = AppScreensToken()
        let tokenB = AppScreensToken()

        let sessionA = AppScreenSession(templateKey: templateKey, webView: WKWebView(), state: .ready)
        sessionA.isOnStack = true
        sessionA.documentURL = address.url

        let sessionB = AppScreenSession(templateKey: templateKey, webView: WKWebView(), state: .ready)
        sessionB.isOnStack = true
        sessionB.documentURL = address.url

        let recordA = PendingNavigation(
            session: sessionA,
            resolvedURL: address.url,
            optimisticDataJSON: nil,
            isColdLoad: false,
            tapTime: .now()
        )
        navigator.pendingNavigations.enqueue(recordA, for: address, in: tokenA)

        let recordB = PendingNavigation(
            session: sessionB,
            resolvedURL: address.url,
            optimisticDataJSON: nil,
            isColdLoad: false,
            tapTime: .now()
        )
        navigator.pendingNavigations.enqueue(recordB, for: address, in: tokenB)

        let host = navigator.makeHost(token: tokenB, address: address, targetRequest: nil, navigating: FakeNavigating())
        let hostViewController = try XCTUnwrap(host as? AppScreensPageViewController)

        XCTAssertTrue(
            sessionB.hostViewController === hostViewController,
            "makeHost(flow: tokenB) must claim tokenB's own record"
        )
        XCTAssertEqual(sessionB.token, tokenB)

        let stillClaimableForA = try XCTUnwrap(navigator.pendingNavigations.claim(for: address, in: tokenA))
        XCTAssertTrue(
            stillClaimableForA.session === sessionA,
            "tokenA's record must survive, untouched by tokenB's makeHost"
        )
        XCTAssertNil(sessionA.hostViewController, "tokenA's session must not be stamped by tokenB's makeHost")
    }

    // MARK: - (f) registerOpenHandler delivers, release clears it

    /// A handler registered for a sheet's flow token receives `openExternalURL`'s
    /// `(url, dismiss)` for a same-token source; after `release` clears the
    /// registry entry, a later post from the same token no longer reaches it.
    func testOpenHandlerRegisteredForSheetFlowDeliversAndReleaseClears() throws {
        let sheetToken = AppScreensToken()
        var captured: [(URL, Bool)] = []
        navigator.registerOpenHandler({ url, dismiss in captured.append((url, dismiss)) }, for: sheetToken)

        let source = makeSourceSession(
            templateKey: Self.key("sheet-open-source"),
            documentURL: URL(string: "https://testbench.rover.io/a/sheet-open-source")!
        )
        source.token = sheetToken

        navigator.openExternalURL(href: "https://example.com/x", dismiss: true, from: source)

        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured.first?.1, true)

        // Give release a session to release, mirroring how a real sheet flow
        // always owns at least its root session before it is torn down.
        let templateKey = Self.key("sheet-open-root")
        let address = try XCTUnwrap(AppScreenAddress(rawURL: URL(string: templateKey)!))
        let rootSession = AppScreenSession(templateKey: templateKey, webView: WKWebView(), state: .ready)
        rootSession.isOnStack = true
        rootSession.documentURL = address.url
        navigator.sessions[templateKey] = rootSession

        let record = PendingNavigation(
            session: rootSession,
            resolvedURL: address.url,
            optimisticDataJSON: nil,
            isColdLoad: false,
            tapTime: .now()
        )
        navigator.pendingNavigations.enqueue(record, for: address, in: sheetToken)
        _ = navigator.makeHost(token: sheetToken, address: address, targetRequest: nil, navigating: FakeNavigating())

        navigator.release(sheetToken)

        navigator.openExternalURL(href: "https://example.com/y", dismiss: false, from: source)

        XCTAssertEqual(
            captured.count,
            1,
            "release must clear the flow's open handler so a later post does not reach it"
        )
    }
}
