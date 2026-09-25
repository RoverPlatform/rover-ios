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

/// Exercises `AppScreensDriver.openExternalURL(href:dismiss:from:)`: the
/// injected per-flow `openHandlersByToken` registry that replaced the
/// `transitionCoordinator`-based dismiss-then-open orchestration. Drives the method
/// directly — no SwiftUI render harness — since the handler lookup is by flow token,
/// not by walking any UIKit navigation controller.
@MainActor
final class AppScreenOpenExternalURLTests: XCTestCase {

    private var navigator: AppScreensDriver!
    private let configSuiteName = "io.rover.test.appscreens.openExternalURL.config"

    override func setUp() {
        super.setUp()
        navigator = Self.makeNavigator(configSuiteName: configSuiteName)
    }

    override func tearDown() {
        navigator = nil
        UserDefaults(suiteName: configSuiteName)?.removePersistentDomain(forName: configSuiteName)
        super.tearDown()
    }

    /// Builds a real navigator with throwaway dependencies. `openExternalURL` never
    /// touches the HTTP/config layers directly.
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

    /// A minimal `AppScreensNavigating` conformer: only ever stored as `session.navigating`
    /// by `makeHost`, so its method bodies are never exercised here (mirrors
    /// `AppScreenMakeHostTests.FakeNavigating`).
    private final class FakeNavigating: AppScreensNavigating {
        func pushScreen(address: AppScreenAddress, targetRequest: URLRequest?) {}
        func presentSheet(address: AppScreenAddress, targetRequest: URLRequest?, sheetToken: AppScreensToken) {}
        func presentWebsite(url: URL) {}
        func dismissRoot() {}
    }

    /// Builds a bare `AppScreenSession` with a `documentURL` set (so `openExternalURL`'s
    /// href-resolution guard passes), suitable as the posting `source` in these tests.
    private static func makeSource(
        documentURL: URL? = URL(string: "https://testbench.rover.io/a/home")
    ) -> AppScreenSession {
        let session = AppScreenSession(
            templateKey: "https://testbench.rover.io/a/home",
            webView: WKWebView(),
            state: .ready
        )
        session.documentURL = documentURL
        return session
    }

    func testOpenExternalURLDeliversToRegisteredHandlerWithDismissTrue() {
        let token = AppScreensToken()
        var captured: [(URL, Bool)] = []
        navigator.registerOpenHandler({ url, dismiss in captured.append((url, dismiss)) }, for: token)

        let source = Self.makeSource()
        source.token = token

        navigator.openExternalURL(href: "https://example.com/x", dismiss: true, from: source)

        XCTAssertEqual(captured.count, 1)
        XCTAssertTrue(captured[0].0.absoluteString.contains("example.com"))
        XCTAssertEqual(captured[0].1, true)
    }

    func testOpenExternalURLDeliversDismissFalse() {
        let token = AppScreensToken()
        var captured: [(URL, Bool)] = []
        navigator.registerOpenHandler({ url, dismiss in captured.append((url, dismiss)) }, for: token)

        let source = Self.makeSource()
        source.token = token

        navigator.openExternalURL(href: "https://example.com/x", dismiss: false, from: source)

        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured[0].1, false)
    }

    /// The handler resolves by flow token alone — a sheet flow (which shares no
    /// UIKit navigation controller with anything) delivers exactly like the root flow.
    func testOpenExternalURLFromSheetFlowTokenDelivers() {
        let sheetToken = AppScreensToken()
        var captured: [(URL, Bool)] = []
        navigator.registerOpenHandler({ url, dismiss in captured.append((url, dismiss)) }, for: sheetToken)

        let source = Self.makeSource()
        source.token = sheetToken

        navigator.openExternalURL(href: "https://example.com/sheet", dismiss: true, from: source)

        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured[0].1, true)
    }

    func testReleaseFlowClearsOpenHandler() throws {
        let token = AppScreensToken()
        var captured: [(URL, Bool)] = []
        navigator.registerOpenHandler({ url, dismiss in captured.append((url, dismiss)) }, for: token)

        // Give `release` a session to release: enqueue a pending record and claim it
        // via `makeHost`, as `AppScreenMakeHostTests` does.
        let address = try XCTUnwrap(
            AppScreenAddress(rawURL: URL(string: "https://testbench.rover.io/a/player-detail")!)
        )
        let session = AppScreenSession(
            templateKey: "https://testbench.rover.io/a/player-detail",
            webView: WKWebView(),
            state: .ready
        )
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
        _ = navigator.makeHost(token: token, address: address, targetRequest: nil, navigating: FakeNavigating())

        navigator.release(token)

        var inPlace: [URL] = []
        let source = Self.makeSource()
        source.token = token
        source.onOpenURL = { url in inPlace.append(url) }
        navigator.rootSessions.append(source)

        navigator.openExternalURL(href: "https://example.com/cleared", dismiss: false, from: source)

        XCTAssertTrue(captured.isEmpty)
        XCTAssertEqual(inPlace.count, 1)
    }

    func testOpenExternalURLNoHandlerFallsBackInPlace() {
        let token = AppScreensToken()

        let source = Self.makeSource()
        source.token = token

        var inPlace: [URL] = []
        source.onOpenURL = { url in inPlace.append(url) }
        navigator.rootSessions.append(source)

        navigator.openExternalURL(href: "https://example.com/fallback", dismiss: false, from: source)

        XCTAssertEqual(inPlace.count, 1)
    }

    func testOpenExternalURLDropsUnparseableHref() {
        let token = AppScreensToken()
        var captured: [(URL, Bool)] = []
        navigator.registerOpenHandler({ url, dismiss in captured.append((url, dismiss)) }, for: token)

        // No `documentURL` — the href-resolution guard cannot resolve against a base
        // URL, so this is dropped before the handler lookup even runs.
        let source = Self.makeSource(documentURL: nil)
        source.token = token

        navigator.openExternalURL(href: "https://example.com/dropped", dismiss: true, from: source)

        XCTAssertTrue(captured.isEmpty)
    }

    func testDismissTrueNeverDropsWhenNoHandlerAndNoRootSession() {
        // A sheet-like source: has a flow token but no registered handler, and is NOT
        // in rootSessions, so rootSession(owning:) returns nil. Previously dropped.
        var systemOpened: [URL] = []
        navigator.systemURLOpener = { systemOpened.append($0) }

        let source = Self.makeSource()
        source.token = AppScreensToken()  // no handler registered

        navigator.openExternalURL(href: "https://example.com/nodrop", dismiss: true, from: source)

        XCTAssertEqual(systemOpened.count, 1)
        XCTAssertTrue(systemOpened[0].absoluteString.contains("example.com"))
    }

    func testSynchronousDoubleDispatchOpensOnceThenAllowsLater() {
        var resets: [() -> Void] = []
        navigator.scheduleInFlightReset = { resets.append($0) }

        let token = AppScreensToken()
        var captured: [(URL, Bool)] = []
        navigator.registerOpenHandler({ url, dismiss in captured.append((url, dismiss)) }, for: token)

        let source = Self.makeSource()
        source.token = token

        // Two synchronous dismiss:true dispatches → only the first reaches the handler.
        navigator.openExternalURL(href: "https://example.com/a", dismiss: true, from: source)
        navigator.openExternalURL(href: "https://example.com/b", dismiss: true, from: source)
        XCTAssertEqual(captured.count, 1)

        // Fire the scheduled reset → a later dispatch proceeds.
        resets.forEach { $0() }
        navigator.openExternalURL(href: "https://example.com/c", dismiss: true, from: source)
        XCTAssertEqual(captured.count, 2)
    }

    func testDismissFalseIsNotBlockedByInFlightGuard() {
        navigator.scheduleInFlightReset = { _ in }  // never auto-reset
        let token = AppScreensToken()
        var captured: [(URL, Bool)] = []
        navigator.registerOpenHandler({ url, dismiss in captured.append((url, dismiss)) }, for: token)
        let source = Self.makeSource()
        source.token = token

        navigator.openExternalURL(href: "https://example.com/a", dismiss: true, from: source)
        navigator.openExternalURL(href: "https://example.com/b", dismiss: false, from: source)  // not guarded
        XCTAssertEqual(captured.count, 2)
    }

    func testDismissFalseNoHandlerNoRootDoesNotOpenBestEffort() {
        // dismiss:false is NOT a deep-link teardown — preserve the prior in-place/drop
        // behavior; the best-effort fallback is scoped to dismiss:true only.
        var systemOpened: [URL] = []
        navigator.systemURLOpener = { systemOpened.append($0) }
        let source = Self.makeSource()
        source.token = AppScreensToken()  // no handler, not in rootSessions

        navigator.openExternalURL(href: "https://example.com/x", dismiss: false, from: source)

        XCTAssertTrue(systemOpened.isEmpty)
    }

    func testSynchronousDoubleDispatchNoHandlerNoRootOpensOnce() {
        navigator.scheduleInFlightReset = { _ in }  // never auto-reset within the test
        var systemOpened: [URL] = []
        navigator.systemURLOpener = { systemOpened.append($0) }
        let source = Self.makeSource()
        source.token = AppScreensToken()  // no handler, not in rootSessions

        // Both take the never-drop best-effort path; the in-flight guard collapses them to one.
        navigator.openExternalURL(href: "https://example.com/a", dismiss: true, from: source)
        navigator.openExternalURL(href: "https://example.com/b", dismiss: true, from: source)

        XCTAssertEqual(systemOpened.count, 1)
    }
}
