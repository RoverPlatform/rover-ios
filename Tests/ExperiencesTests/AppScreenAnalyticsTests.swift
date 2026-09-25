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

/// Exercises which App Screens bridge messages and lifecycle events emit analytics,
/// driving `AppScreensDriver` directly (no SwiftUI render harness) the way the
/// sibling `AppScreenNavigatePushTests` / `AppScreenOpenExternalURLTests` do.
///
/// The seam is a real `EventQueue` subclass that records `addEvent` instead of
/// queueing it — the navigator takes the concrete `EventQueue`, so this is the
/// cheapest honest double.
@MainActor
final class AppScreenAnalyticsTests: XCTestCase {

    private var navigator: AppScreensDriver!
    private var eventQueue: RecordingEventQueue!
    private let configSuiteName = "io.rover.test.appscreens.analytics.config"

    override func setUp() {
        super.setUp()
        eventQueue = Self.makeRecordingEventQueue()
        navigator = Self.makeNavigator(configSuiteName: configSuiteName, eventQueue: eventQueue)
    }

    override func tearDown() {
        navigator = nil
        eventQueue = nil
        UserDefaults(suiteName: configSuiteName)?.removePersistentDomain(forName: configSuiteName)
        super.tearDown()
    }

    // MARK: - Doubles

    /// Records every `addEvent` rather than queueing it, so no context provider,
    /// serial queue, or cache is involved.
    private final class RecordingEventQueue: EventQueue {
        private(set) var events: [EventInfo] = []

        override func addEvent(_ info: EventInfo) {
            events.append(info)
        }

        /// Drops what a fixture's own setup recorded, so a test asserts only on what
        /// the action under test emitted.
        func reset() {
            events.removeAll()
        }

        var viewedEvents: [EventInfo] {
            events.filter { $0.name == "App Screen Viewed" }
        }
    }

    /// The `EventsClient` the recording queue is constructed with. Never reached —
    /// `addEvent` is overridden and nothing flushes.
    private struct UnusedEventsClient: EventsClient {
        func sendEvents(with events: [Event]) async -> HTTPResult {
            .error(error: nil, isRetryable: false)
        }
    }

    private static func makeRecordingEventQueue() -> RecordingEventQueue {
        RecordingEventQueue(
            client: UnusedEventsClient(),
            flushAt: 1,
            flushInterval: 60,
            maxBatchSize: 1,
            maxQueueSize: 1
        )
    }

    private static func makeNavigator(configSuiteName: String, eventQueue: EventQueue) -> AppScreensDriver {
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
            eventQueue: eventQueue
        )
    }

    /// Records the navigation intents the driver hands up, so a test can prove a
    /// navigation happened (or did not) and can drive the real sheet lifecycle for a
    /// sheet flow the driver just minted.
    private final class FakeNavigating: AppScreensNavigating {
        private(set) var pushedAddresses: [AppScreenAddress] = []
        private(set) var presentedSheetTokens: [AppScreensToken] = []

        func pushScreen(address: AppScreenAddress, targetRequest: URLRequest?) {
            pushedAddresses.append(address)
        }

        func presentSheet(address: AppScreenAddress, targetRequest: URLRequest?, sheetToken: AppScreensToken) {
            presentedSheetTokens.append(sheetToken)
        }

        func presentWebsite(url: URL) {}
        func dismissRoot() {}
    }

    // MARK: - Fixtures

    /// A source session with a document URL and a flow token, ready to originate a
    /// bridge message.
    private func makeSource(
        documentURL: URL = URL(string: "https://testbench.rover.io/a/home?tab=news")!
    ) -> (session: AppScreenSession, navigating: FakeNavigating) {
        let session = AppScreenSession(
            templateKey: "https://testbench.rover.io/a/home",
            webView: WKWebView(),
            state: .ready
        )
        session.documentURL = documentURL
        // A screen that can post a bridge message is, by construction, on a
        // navigation stack — every production path sets this before a host exists.
        session.isOnStack = true
        let navigating = FakeNavigating()
        session.navigating = navigating
        session.token = AppScreensToken()
        return (session, navigating)
    }

    /// A flow as `makeVisibleFlow` vends it.
    private struct VisibleFlow {
        let token: AppScreensToken
        let session: AppScreenSession
        let window: UIWindow
        let navigating: FakeNavigating
    }

    /// A flow with one on-stack screen whose host is in a real window and has
    /// appeared, so `visibility(of:)` reads `.visible`. Registered in the navigator's
    /// per-flow registry through the production `makeHost` claim, which is what the
    /// dismissal reveal scans — a bare session in the warm pool is not a flow member.
    private func makeVisibleFlow(url: String) throws -> VisibleFlow {
        let screenURL = try XCTUnwrap(URL(string: url))
        let address = try XCTUnwrap(AppScreenAddress(rawURL: screenURL))
        let token = AppScreensToken()

        let session = AppScreenSession(
            templateKey: try XCTUnwrap(AppScreensDriver.templateKey(from: screenURL)),
            webView: WKWebView(),
            state: .ready
        )
        // What `navigate` does at resolve time, as `AppScreenMakeHostTests` sets up.
        session.isOnStack = true
        session.documentURL = screenURL

        navigator.pendingNavigations.enqueue(
            PendingNavigation(
                session: session,
                resolvedURL: screenURL,
                optimisticDataJSON: nil,
                isColdLoad: false,
                tapTime: .now()
            ),
            for: address,
            in: token
        )
        let navigating = FakeNavigating()
        let host = navigator.makeHost(
            token: token,
            address: address,
            targetRequest: URLRequest(url: screenURL),
            navigating: navigating
        )

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.viewDidAppear(false)
        XCTAssertEqual(
            AppScreensDriver.visibility(of: session),
            .visible,
            "precondition: the flow's screen must read as visible"
        )
        // That appearance is the production Viewed path doing its job; these tests
        // assert on what happens next, so start them from a clean recorder.
        eventQueue.reset()
        return VisibleFlow(token: token, session: session, window: window, navigating: navigating)
    }

    /// Presents a sheet over `flow` the way a bridge `navigate(transition: .sheet)`
    /// does, and hands back the sheet flow token the navigator minted for it (captured
    /// from the navigating seam).
    @discardableResult
    private func presentSheet(over flow: VisibleFlow, from source: AppScreenSession? = nil) throws -> AppScreensToken {
        navigator.navigate(
            href: "/a/sheet-detail",
            optimisticDataJSON: nil,
            transition: .sheet,
            from: source ?? flow.session
        )
        return try XCTUnwrap(
            flow.navigating.presentedSheetTokens.last,
            "navigate(.sheet) should have minted a sheet flow token"
        )
    }

    /// Drives the full dismissal sequence a real sheet goes through, in production
    /// order: the presenting screen's `.sheet(onDismiss:)` fires first (once the
    /// dismissal transition is done), then SwiftUI tears the sheet's
    /// `AppScreensTokenBox` down, which is `release`.
    ///
    /// Awaits `release`'s deferred fallback rather than spinning the run loop for it:
    /// the fallback is a main-actor continuation, and a run-loop spin is a window, not
    /// a guarantee that it ran. Without the await these tests would still pass when the
    /// fallback never ran at all — the assertions here are "exactly once", so an
    /// undrained hop is a vacuous pass rather than a failure.
    private func presentAndDismissSheet(over flow: VisibleFlow) async throws {
        let sheetToken = try presentSheet(over: flow)
        navigator.sheetFlowDidDismiss(sheetToken)
        navigator.release(sheetToken)
        await navigator.drainPendingDismissalFallbacks()
    }

    /// Pushes a second screen into `flow` the way a rendered `navigate(.push)` does:
    /// a pending record, the production `makeHost` claim under the SAME flow token,
    /// then the appearance sequence a push delivers — detail on screen, root behind
    /// it. Leaves the recorder clean, like ``makeVisibleFlow``.
    @discardableResult
    private func pushScreen(into flow: VisibleFlow, url: String) throws -> AppScreenSession {
        let screenURL = try XCTUnwrap(URL(string: url))
        let address = try XCTUnwrap(AppScreenAddress(rawURL: screenURL))

        let session = AppScreenSession(
            templateKey: try XCTUnwrap(AppScreensDriver.templateKey(from: screenURL)),
            webView: WKWebView(),
            state: .ready
        )
        session.isOnStack = true
        session.documentURL = screenURL

        navigator.pendingNavigations.enqueue(
            PendingNavigation(
                session: session,
                resolvedURL: screenURL,
                optimisticDataJSON: nil,
                isColdLoad: false,
                tapTime: .now()
            ),
            for: address,
            in: flow.token
        )
        let host = navigator.makeHost(
            token: flow.token,
            address: address,
            targetRequest: URLRequest(url: screenURL),
            navigating: flow.navigating
        )
        // The push, in the terms `visibility(of:)` actually reads: the detail's view is
        // in the window and it has appeared; the root has disappeared behind it. Done by
        // parking the view rather than by swapping `rootViewController`, which delivers
        // appearance callbacks of its own and would fire the root's Viewed path at a
        // moment no production push does.
        flow.window.addSubview(host.view)
        try XCTUnwrap(flow.session.hostViewController).viewDidDisappear(false)
        host.viewDidAppear(false)
        XCTAssertEqual(
            AppScreensDriver.visibility(of: session),
            .visible,
            "precondition: the pushed detail is the screen on top"
        )
        XCTAssertEqual(
            AppScreensDriver.visibility(of: flow.session),
            .occluded,
            "precondition: the flow root is behind it"
        )
        eventQueue.reset()
        return session
    }

    private func teardownWindow(_ window: UIWindow) {
        window.isHidden = true
        window.rootViewController = nil
    }

    /// The event's attributes as a whole `[String: String]`, so the tests can pin
    /// the exact key set rather than spot-checking values.
    private func attributes(_ event: EventInfo) -> [String: String]? {
        guard let attributes = event.attributes else {
            return nil
        }
        return attributes.rawValue as? [String: String]
    }

    // MARK: - navigate

    /// A `navigate` that clears the associated-domain gate emits exactly one
    /// "App Screen Link Clicked", carrying the posting screen's URL and the resolved
    /// target.
    func testAuthorizedNavigateEmitsLinkClicked() throws {
        let (source, navigating) = makeSource()

        navigator.navigate(
            href: "/a/player-detail?id=dez-carter",
            optimisticDataJSON: nil,
            transition: .push,
            from: source
        )

        XCTAssertEqual(navigating.pushedAddresses.count, 1, "the navigation itself should have gone through")
        XCTAssertEqual(eventQueue.events.count, 1)
        let event = try XCTUnwrap(eventQueue.events.first)
        XCTAssertEqual(event.name, "App Screen Link Clicked")
        XCTAssertEqual(event.namespace, "rover")
        XCTAssertEqual(
            attributes(event),
            [
                "screenURL": "https://testbench.rover.io/a/home?tab=news",
                "linkURL": "https://testbench.rover.io/a/player-detail?id=dez-carter"
            ]
        )
    }

    /// A navigation rejected by the associated-domain gate is not a click: nothing
    /// is emitted (and nothing is pushed).
    func testUnauthorizedNavigateEmitsNothing() {
        let (source, navigating) = makeSource()

        navigator.navigate(
            href: "https://attacker.example/a/player-detail",
            optimisticDataJSON: nil,
            transition: .push,
            from: source
        )

        XCTAssertEqual(navigating.pushedAddresses.count, 0)
        XCTAssertTrue(eventQueue.events.isEmpty)
    }

    /// A popped-but-warm session keeps its web view, and therefore its bridge, alive,
    /// so its runtime can post a `navigate` long after the user left that screen.
    /// Acting on it would push into whatever is on screen now and report a tap the
    /// user never made: the message is dropped, and nothing is emitted.
    func testNavigateFromOffStackSourceEmitsNothing() {
        let (source, navigating) = makeSource()
        // Exactly what `handlePop(of:)` leaves behind for a warm template session:
        // off the stack, but otherwise fully live.
        source.isOnStack = false

        navigator.navigate(
            href: "/a/player-detail?id=dez-carter",
            optimisticDataJSON: nil,
            transition: .push,
            from: source
        )

        XCTAssertEqual(navigating.pushedAddresses.count, 0, "an off-stack source must not push")
        XCTAssertTrue(eventQueue.events.isEmpty)
        XCTAssertNil(
            navigator.sessions["https://testbench.rover.io/a/player-detail"],
            "and must not spin up a session for the target"
        )
    }

    // MARK: - links

    /// `links` hints are prewarm candidates, not taps. Scheduling a real, authorized
    /// hint (one that genuinely reserves prewarm work) must emit nothing.
    func testLinksHintEmitsNothing() {
        let (source, _) = makeSource()

        navigator.schedulePrewarms(
            fromLinks: ["/a/player-detail?id=dez-carter", "/a/standings"],
            source: source
        )

        XCTAssertFalse(
            navigator.inflightPrewarms.isEmpty,
            "the hint should have reserved prewarm work, so this is not a vacuous pass"
        )
        XCTAssertTrue(eventQueue.events.isEmpty)
    }

    // MARK: - presentWebsite

    func testPresentWebsiteEmitsLinkClicked() throws {
        let (source, _) = makeSource()

        navigator.presentWebsite(href: "https://example.com/promo?utm=1", from: source)

        XCTAssertEqual(eventQueue.events.count, 1)
        let event = try XCTUnwrap(eventQueue.events.first)
        XCTAssertEqual(event.name, "App Screen Link Clicked")
        XCTAssertEqual(
            attributes(event),
            [
                "screenURL": "https://testbench.rover.io/a/home?tab=news",
                "linkURL": "https://example.com/promo?utm=1"
            ]
        )
    }

    // MARK: - openURL

    func testOpenURLEmitsLinkClicked() throws {
        let (source, _) = makeSource()
        let token = try XCTUnwrap(source.token)
        navigator.registerOpenHandler({ _, _ in }, for: token)

        navigator.openExternalURL(href: "https://example.com/x", dismiss: false, from: source)

        XCTAssertEqual(eventQueue.events.count, 1)
        let event = try XCTUnwrap(eventQueue.events.first)
        XCTAssertEqual(event.name, "App Screen Link Clicked")
        XCTAssertEqual(
            attributes(event),
            [
                "screenURL": "https://testbench.rover.io/a/home?tab=news",
                "linkURL": "https://example.com/x"
            ]
        )
    }

    /// A popped or prewarming session keeps its bridge alive, so it can post a late
    /// `openURL`. The link is still honoured here — a tap on a screen the user left is
    /// not a click, so only the event is withheld. Dropping the action too (which
    /// Android already does, in `handlerForActivePresentation`) is SDK-462; this test
    /// pins today's iOS behaviour and is expected to change with it.
    func testOffStackOpenURLOpensButEmitsNothing() throws {
        let (source, _) = makeSource()
        let token = try XCTUnwrap(source.token)
        var opened: [URL] = []
        navigator.registerOpenHandler({ url, _ in opened.append(url) }, for: token)
        source.isOnStack = false

        navigator.openExternalURL(href: "https://example.com/x", dismiss: false, from: source)

        XCTAssertEqual(
            opened.map(\.absoluteString),
            ["https://example.com/x"],
            "the deep link must still be honoured"
        )
        XCTAssertTrue(eventQueue.events.isEmpty, "but it must not be recorded as a click")
    }

    /// The `dismiss: true` double-dispatch guard collapses a duplicate burst into one
    /// open, and the analytics follow it: one click, not two.
    func testDuplicateDismissOpenEmitsOnce() {
        let (source, _) = makeSource()
        // Swallow the reset so the second call is still "in flight".
        navigator.scheduleInFlightReset = { _ in }
        if let token = source.token {
            navigator.registerOpenHandler({ _, _ in }, for: token)
        }

        navigator.openExternalURL(href: "https://example.com/x", dismiss: true, from: source)
        navigator.openExternalURL(href: "https://example.com/x", dismiss: true, from: source)

        XCTAssertEqual(eventQueue.events.count, 1)
    }

    // MARK: - Viewed: only the exposed screen

    /// A sheet dismissal exposes the screen beneath it, which receives no appearance
    /// callback of its own (a page sheet never made it disappear), so the reveal is
    /// reported from the dismissal hook.
    func testDismissalRevealEmitsViewedForTheExposedScreen() async throws {
        let flow = try makeVisibleFlow(url: "https://testbench.rover.io/a/home?tab=news")
        defer { teardownWindow(flow.window) }

        try await presentAndDismissSheet(over: flow)

        XCTAssertEqual(eventQueue.viewedEvents.count, 1)
        XCTAssertEqual(
            attributes(try XCTUnwrap(eventQueue.viewedEvents.first)),
            ["screenURL": "https://testbench.rover.io/a/home?tab=news"]
        )
    }

    /// The reveal is scoped to the flow the dismissed sheet was presented over.
    /// `rootSessions` supports concurrent presentations, so a process-wide search
    /// would see two visible screens and — under the fail-closed rule — report
    /// nothing at all. Only the flow whose sheet was dismissed is reported.
    func testDismissalRevealIsScopedToThePresentingFlow() async throws {
        let flowA = try makeVisibleFlow(url: "https://testbench.rover.io/a/home?tab=news")
        defer { teardownWindow(flowA.window) }
        let flowB = try makeVisibleFlow(url: "https://testbench.rover.io/a/standings")
        defer { teardownWindow(flowB.window) }
        XCTAssertEqual(
            AppScreensDriver.visibility(of: flowA.session),
            .visible,
            "precondition: both flows are on screen at once"
        )
        XCTAssertEqual(AppScreensDriver.visibility(of: flowB.session), .visible)

        try await presentAndDismissSheet(over: flowA)

        XCTAssertEqual(
            eventQueue.viewedEvents.count,
            1,
            "a second visible flow must not suppress the reveal"
        )
        XCTAssertEqual(
            attributes(try XCTUnwrap(eventQueue.viewedEvents.first)),
            ["screenURL": "https://testbench.rover.io/a/home?tab=news"],
            "and must not be reported instead of it"
        )
    }

    /// The last-viewed identity is per flow, so a view reported in one flow does not
    /// suppress the reveal in another.
    func testViewInOneFlowDoesNotSuppressRevealInAnother() async throws {
        let flowA = try makeVisibleFlow(url: "https://testbench.rover.io/a/home?tab=news")
        defer { teardownWindow(flowA.window) }
        let flowB = try makeVisibleFlow(url: "https://testbench.rover.io/a/standings")
        defer { teardownWindow(flowB.window) }

        try await presentAndDismissSheet(over: flowB)
        XCTAssertEqual(eventQueue.viewedEvents.count, 1)

        try await presentAndDismissSheet(over: flowA)

        XCTAssertEqual(eventQueue.viewedEvents.count, 2)
        XCTAssertEqual(
            attributes(try XCTUnwrap(eventQueue.viewedEvents.last)),
            ["screenURL": "https://testbench.rover.io/a/home?tab=news"]
        )
    }

    /// The identity guard: if the exposed screen is the one already reported in that
    /// flow — which is what happens when a presentation style *does* deliver
    /// `viewDidAppear` on reveal — the dismissal hook stays quiet rather than
    /// double-counting.
    func testDismissalRevealDoesNotRepeatTheLastViewedScreen() throws {
        let flow = try makeVisibleFlow(url: "https://testbench.rover.io/a/home?tab=news")
        defer { teardownWindow(flow.window) }

        // Stand in for a presentation style that DOES deliver `viewDidAppear` on
        // reveal: the appearance path reports the screen, then the hook runs.
        try XCTUnwrap(flow.session.hostViewController).viewDidAppear(false)
        XCTAssertEqual(
            eventQueue.viewedEvents.count,
            1,
            "precondition: the appearance path reported it once"
        )

        navigator.trackScreenExposedByDismissal(inFlowOf: flow.token)

        XCTAssertEqual(
            eventQueue.viewedEvents.count,
            1,
            "the same screen must not be reported twice"
        )
    }

    /// Nothing is reported while the hierarchy is still unwinding: a host that has
    /// left the screen reads as `.occluded`, not `.visible`, so the hook fails closed
    /// rather than guessing which screen was exposed.
    func testDismissalRevealEmitsNothingWhenNoScreenIsVisible() throws {
        let flow = try makeVisibleFlow(url: "https://testbench.rover.io/a/home?tab=news")
        defer { teardownWindow(flow.window) }
        try XCTUnwrap(flow.session.hostViewController).viewDidDisappear(false)
        XCTAssertEqual(AppScreensDriver.visibility(of: flow.session), .occluded)

        navigator.trackScreenExposedByDismissal(inFlowOf: flow.token)

        XCTAssertTrue(eventQueue.viewedEvents.isEmpty)
    }

    // MARK: - Viewed: the dismissal hook

    /// The production signal: the presenting screen's `.sheet(onDismiss:)` calls this
    /// with the dismissed sheet's flow token, after the transition finished. On its own
    /// — with no flow teardown behind it — it reports the exposed screen.
    func testSheetDismissalHookEmitsViewedForTheExposedScreen() throws {
        let flow = try makeVisibleFlow(url: "https://testbench.rover.io/a/home?tab=news")
        defer { teardownWindow(flow.window) }
        let sheetToken = try presentSheet(over: flow)

        navigator.sheetFlowDidDismiss(sheetToken)

        XCTAssertEqual(eventQueue.viewedEvents.count, 1)
        XCTAssertEqual(
            attributes(try XCTUnwrap(eventQueue.viewedEvents.first)),
            ["screenURL": "https://testbench.rover.io/a/home?tab=news"]
        )
    }

    /// The hook is the reveal's one-shot ticket: a repeat call for the same sheet flow
    /// finds it redeemed and reports nothing.
    func testSheetDismissalHookIsIdempotent() throws {
        let flow = try makeVisibleFlow(url: "https://testbench.rover.io/a/home?tab=news")
        defer { teardownWindow(flow.window) }
        let sheetToken = try presentSheet(over: flow)

        navigator.sheetFlowDidDismiss(sheetToken)
        navigator.sheetFlowDidDismiss(sheetToken)

        XCTAssertEqual(eventQueue.viewedEvents.count, 1)
    }

    /// Both dismissal signals fire for a real sheet — `onDismiss` first, then the flow
    /// teardown SwiftUI drives through `AppScreensTokenBox.deinit`. The dismissal is
    /// still worth exactly one view.
    func testSheetDismissalHookFollowedByReleaseEmitsViewedOnce() async throws {
        let flow = try makeVisibleFlow(url: "https://testbench.rover.io/a/home?tab=news")
        defer { teardownWindow(flow.window) }
        let sheetToken = try presentSheet(over: flow)

        navigator.sheetFlowDidDismiss(sheetToken)
        navigator.release(sheetToken)
        await navigator.drainPendingDismissalFallbacks()

        XCTAssertEqual(eventQueue.viewedEvents.count, 1)
    }

    /// The fallback: a sheet flow torn down with no `onDismiss` behind it (the
    /// presenting screen going away, say) still reports the reveal from `release` —
    /// one main-actor turn later, and only if the hierarchy has settled by then.
    ///
    /// This is the one test whose subject IS that hop, so it awaits the driver's own
    /// fallback task. It used to spin the run loop for 0.3 s instead, which is a
    /// window rather than a guarantee that a main-actor continuation has run, and it
    /// duly failed three times in a row on a cold, loaded machine.
    func testReleaseWithoutTheDismissalHookStillReportsTheReveal() async throws {
        let flow = try makeVisibleFlow(url: "https://testbench.rover.io/a/home?tab=news")
        defer { teardownWindow(flow.window) }
        let sheetToken = try presentSheet(over: flow)

        navigator.release(sheetToken)
        await navigator.drainPendingDismissalFallbacks()

        XCTAssertEqual(eventQueue.viewedEvents.count, 1)
        XCTAssertEqual(
            attributes(try XCTUnwrap(eventQueue.viewedEvents.first)),
            ["screenURL": "https://testbench.rover.io/a/home?tab=news"]
        )
    }

    /// The hook reports the flow the dismissed sheet was presented over, not whatever
    /// else is on screen: with two flows up at once, only the presenting one is
    /// reported.
    func testSheetDismissalHookIsScopedToThePresentingFlow() throws {
        let flowA = try makeVisibleFlow(url: "https://testbench.rover.io/a/home?tab=news")
        defer { teardownWindow(flowA.window) }
        let flowB = try makeVisibleFlow(url: "https://testbench.rover.io/a/standings")
        defer { teardownWindow(flowB.window) }
        XCTAssertEqual(AppScreensDriver.visibility(of: flowB.session), .visible)
        let sheetToken = try presentSheet(over: flowA)

        navigator.sheetFlowDidDismiss(sheetToken)

        XCTAssertEqual(eventQueue.viewedEvents.count, 1)
        XCTAssertEqual(
            attributes(try XCTUnwrap(eventQueue.viewedEvents.first)),
            ["screenURL": "https://testbench.rover.io/a/home?tab=news"]
        )
    }

    /// A token that never presented a sheet — a flow the hook has no record of — is
    /// not a reveal, so nothing is reported for whatever happens to be on screen.
    func testDismissalHookForAnUnknownFlowEmitsNothing() throws {
        let flow = try makeVisibleFlow(url: "https://testbench.rover.io/a/home?tab=news")
        defer { teardownWindow(flow.window) }

        navigator.sheetFlowDidDismiss(AppScreensToken())

        XCTAssertTrue(eventQueue.viewedEvents.isEmpty)
    }

    /// Nothing is reported when the dismissal has not settled: a presenting host that
    /// is still presenting reads `.occluded`, so the hook fails closed. This is the
    /// state the old teardown-driven timing could land in, and why the hook is called
    /// from `onDismiss` instead.
    func testSheetDismissalHookEmitsNothingWhileTheSheetIsStillPresented() throws {
        let flow = try makeVisibleFlow(url: "https://testbench.rover.io/a/home?tab=news")
        defer { teardownWindow(flow.window) }
        let sheetToken = try presentSheet(over: flow)
        let host = try XCTUnwrap(flow.session.hostViewController)
        host.present(UIViewController(), animated: false)
        XCTAssertEqual(
            AppScreensDriver.visibility(of: flow.session),
            .occluded,
            "precondition: a host that is still presenting is not exposed"
        )

        navigator.sheetFlowDidDismiss(sheetToken)

        XCTAssertTrue(eventQueue.viewedEvents.isEmpty)
    }

    /// A coordinator-driven path reset — a `HubCoordinator` config change, or a
    /// conversation deep link, assigning a fresh `NavigationPath` — dismisses any sheet
    /// the flow has open: `AppScreensContentView`'s `.onChange(of: path)` nils the
    /// presenting screen's `sheetDestination`, which is a real dismissal and runs
    /// `.sheet(onDismiss:)`, hence this hook. The same reset pops the detail that
    /// presented the sheet, so the screen the user is left looking at is the flow's
    /// **root** — and it is reported exactly once, by whichever of the two signals sees
    /// it uncovered first.
    ///
    /// At the driver's seam the reset is the same pair of calls a swipe-down makes, so
    /// this asserts nothing the hook tests above do not already cover mechanically. It
    /// is here for the scenario, and for the answer: the root, once, not the popped
    /// detail that presented the sheet. The other half of the ordering — the root's
    /// re-appearance landing while the sheet still covers it, which reports nothing —
    /// is pinned by `testSheetDismissalHookEmitsNothingWhileTheSheetIsStillPresented`.
    func testPathResetWhileASheetIsOpenReportsTheRevealedRootOnce() throws {
        let flow = try makeVisibleFlow(url: "https://testbench.rover.io/a/home?tab=news")
        defer { teardownWindow(flow.window) }
        let detail = try pushScreen(into: flow, url: "https://testbench.rover.io/a/player-detail?id=dez-carter")
        let sheetToken = try presentSheet(over: flow, from: detail)

        // The reset: the detail is popped and the sheet dismissed in one transaction.
        detail.isOnStack = false
        let detailHost = try XCTUnwrap(detail.hostViewController)
        detailHost.viewDidDisappear(false)
        detailHost.view.removeFromSuperview()
        try XCTUnwrap(flow.session.hostViewController).viewDidAppear(false)
        XCTAssertEqual(
            AppScreensDriver.visibility(of: flow.session),
            .visible,
            "precondition: the root is what the reset leaves on screen"
        )

        // SwiftUI then runs `.sheet(onDismiss:)` for the sheet the reset closed.
        navigator.sheetFlowDidDismiss(sheetToken)

        XCTAssertEqual(
            eventQueue.viewedEvents.count,
            1,
            "one view for the reveal — the hook must not add a second"
        )
        XCTAssertEqual(
            attributes(try XCTUnwrap(eventQueue.viewedEvents.first)),
            ["screenURL": "https://testbench.rover.io/a/home?tab=news"],
            "the revealed root, not the popped detail that presented the sheet"
        )
    }
}
