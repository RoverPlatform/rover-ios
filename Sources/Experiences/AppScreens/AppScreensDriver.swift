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

import RoverData
import UIKit
import WebKit
import os.log

/// The App Screens driver: an internal SDK singleton that owns the persistent
/// per-template web view sessions and vends host view controllers for the
/// experience entry points.
///
/// The master pipeline creates the session + web view, fetches the anonymous
/// document natively (capturing the `ETag`), `loadHTMLString`s it, awaits the
/// runtime `loaded` message, and reveals on resolution. The identified `.json`
/// fetch (via `HTTPClient`'s authenticated request path) runs the hash handshake
/// against `session.documentETag` and morphs its data over the SSR body via
/// `show()`. Navigation (`navigate`/`links`), prewarm, and liveness
/// recover-and-replay (WebContent process death → reload once + replay the last
/// `show()` payload for a visible session; tear down an idle warm one) build on
/// the same machinery.
@MainActor
final class AppScreensDriver: NSObject {
    let httpClient: HTTPClient
    private let configManager: ConfigManager

    /// The SDK event queue that "App Screen Viewed" / "App Screen Link Clicked"
    /// analytics events are posted to. Optional so the many tests that exercise only
    /// navigation and hosting can build a navigator without standing one up; the
    /// assembler always injects the real queue.
    private let eventQueue: EventQueue?

    /// The app's associated domains, lowercased for case-insensitive host
    /// comparison. Every bridge-driven navigation target and prewarm candidate must
    /// resolve to one of these hosts (mirroring the entry point's `router.isValidDomain`
    /// gate), so a screen can never steer the authenticated data channel or the
    /// bridge-bearing web view to an attacker-controlled origin. Resolved at assembly
    /// time from the router's `associatedDomains`.
    let associatedDomains: Set<String>

    /// Live *reusable* warm sessions keyed by origin-qualified template key. The key
    /// (``templateKey(from:)``) folds in scheme + host + explicit port, so the same
    /// bare `/a/{path}` on two associated domains occupies two distinct slots and
    /// never reuses one another's warm web view. Root (entry-point) sessions are NOT
    /// stored here — they are tracked separately in ``rootSessions`` so two
    /// concurrent presentations of the same template never evict one another from
    /// this shared, single-slot pool. A root demoted at presentation end
    /// (``releaseRootSession(_:)``) may be moved *into* this pool as an
    /// off-stack reusable session when its slot is free.
    var sessions: [String: AppScreenSession] = [:]

    /// The live root (entry-point) sessions, one per active
    /// ``ExperienceViewController`` App Screens presentation. Tracked as an
    /// independent list rather than in ``sessions`` because the keyed pool holds a
    /// single warm session per template: two scenes (or two presentations) showing
    /// the same `/a/home` must each keep their own live root, and neither may evict
    /// the other from ``liveSession(for:)``. A root leaves this list only when its
    /// owning presentation ends (``releaseRootSession(_:)``), which either
    /// demotes it into ``sessions`` as an off-stack reusable session or tears it
    /// down. Mirrors ``ephemeralSessions`` in shape.
    var rootSessions: [AppScreenSession] = []

    /// One-off detail→detail sessions, not keyed by template (their template slot
    /// is occupied by the on-stack warm session behind them). Retained here so the
    /// bridge can route their messages and pop can tear them down.
    var ephemeralSessions: [AppScreenSession] = []

    /// Sessions that are currently prewarming (document fetch + runtime boot) off a
    /// `links` hint but have not yet been promoted into `sessions`. Kept here so the
    /// bridge can route their `loaded` message while they boot; a session is
    /// promoted to the warm `sessions` dict once its runtime is `ready` (if the slot
    /// is still free), or torn down if it fails or the slot was taken meanwhile.
    var prewarmingSessions: [AppScreenSession] = []

    /// Origin-qualified template keys reserved by prewarm — either queued or booting
    /// — so a repeated `links` hint coalesces and never schedules duplicate work. A
    /// key is reserved at schedule time and released when its prewarm finishes
    /// (success or failure) or the scheduler is cancelled.
    var inflightPrewarms: Set<String> = []

    /// Prewarm candidates awaiting their staggered start, drained by
    /// `prewarmSchedulerTask` 300 ms apart. New `links` hints append here and the
    /// single running drain picks them up (coalescing).
    var pendingPrewarms: [PrewarmCandidate] = []

    /// The single task draining `pendingPrewarms` on a stagger. `nil` when idle. A
    /// new `links` hint appends candidates and, only if this is `nil`, starts a
    /// fresh drain — so at most one stagger loop runs at a time. Cancelled on
    /// `deinit` (cheap guard for the singleton ever dying).
    var prewarmSchedulerTask: Task<Void, Never>?

    /// The independent per-template prewarm worker tasks the stagger loop launches.
    /// Each is its own `Task` so a prewarm's document fetch + runtime boot never
    /// blocks the stagger clock (or the main navigation pipeline). Tracked only so
    /// `deinit` can cancel any in flight. Inherently bounded: a template is
    /// prewarmed at most once (once warm it leaves the candidate set forever), so
    /// this holds at most one entry per distinct template over the session.
    var prewarmWorkerTasks: [Task<Void, Never>] = []

    /// Holds ``PendingNavigation`` records between `navigate`'s resolve (which
    /// enqueues) and ``makeHost(flow:address:targetRequest:navigating:)``'s render-time
    /// claim. The navigator owns the single instance both sides share; `package` (not
    /// `private`) only so `AppScreenMakeHostTests` can enqueue directly without a
    /// bespoke test-only seam.
    package let pendingNavigations = AppScreenPendingNavigationStore()

    /// Live sessions grouped by the ``AppScreensToken`` that owns them, populated by
    /// ``makeRootHost(flow:url:navigating:onDismiss:onOpenURL:)`` and
    /// ``makeHost(flow:address:targetRequest:navigating:)`` as each screen in a flow
    /// renders. Keyed secondarily by ``ObjectIdentifier`` so the same session is never
    /// double-registered under its flow. Consumed by ``release(_:)``. `private(set)`:
    /// all mutation stays inside this file; the internal getter only exists so
    /// `AppScreenRootFlowTests` can assert the registry is purged after release
    /// (via `@testable import`), without a bespoke test-only seam.
    private(set) var sessionsByToken: [AppScreensToken: [ObjectIdentifier: AppScreenSession]] = [:]

    /// Per-flow injected external-URL open handlers (the completion-capable
    /// dismiss-then-open the owner controls). Keyed by flow token: the Hub root flow and
    /// every sheet flow of that experience register the SAME owner handler, so an
    /// `openURL` posted by any of them resolves by the posting session's `token`
    /// without walking UIKit ancestry. Cleared by `release`. `private(set)`: mutation
    /// stays in this file (via `registerOpenHandler`/`release`); the internal getter
    /// only exists so `AppScreenFlowHostTests` can assert teardown (via `@testable import`).
    private(set) var openHandlersByToken: [AppScreensToken: (URL, Bool) -> Void] = [:]

    /// Opens an external/deep-link URL through the OS. Injectable so tests can assert
    /// the never-silently-drop fallback without invoking UIKit. The default preserves the
    /// prior completion-based failure logging.
    var systemURLOpener: (URL) -> Void = { url in
        UIApplication.shared.open(url) { success in
            if !success {
                os_log(
                    "openURL failed to open %{private}@",
                    log: .appScreens,
                    type: .error,
                    url.absoluteString
                )
            }
        }
    }

    /// Schedules the reset of `openInFlight`. Injectable for deterministic tests.
    var scheduleInFlightReset: (@escaping () -> Void) -> Void = { work in
        Task { @MainActor in work() }
    }

    /// The session most recently reported as an "App Screen Viewed", **per flow**, so
    /// the sheet-dismissal reveal never re-reports a screen the appearance path
    /// already counted. Keyed by flow because ``rootSessions`` explicitly supports
    /// concurrent presentations (two scenes on iPad, or a standalone presentation over
    /// an embedded Hub home): a view in one flow must not suppress the reveal in
    /// another. Identity only — no session is retained.
    private var lastViewedSessionIdentityByFlow: [AppScreensToken: ObjectIdentifier] = [:]

    /// The flow that presented each sheet flow, recorded when `navigate` mints the
    /// sheet's token. On dismissal this is what scopes the reveal accounting to the
    /// stack the sheet was covering, rather than searching process-wide and finding
    /// another flow's visible screen. Nested sheets chain through it. Cleared with the
    /// sheet flow in ``release(_:)``.
    private var presentingFlowBySheetFlow: [AppScreensToken: AppScreensToken] = [:]

    /// The deferred reveal check ``release(_:)`` schedules when a sheet flow is torn
    /// down without an `onDismiss` behind it, keyed by the sheet flow it speaks for.
    /// Held so it can be awaited (``drainPendingDismissalFallbacks()``) rather than
    /// waited *at*; each task clears its own entry as it runs.
    private var pendingDismissalFallbacks: [AppScreensToken: Task<Void, Never>] = [:]

    /// Guards against a single bridge burst dispatching `openURL {dismiss:true}` twice
    /// near-simultaneously (double `open`). Not a completion-accurate mutex — a genuinely
    /// later deep link (after reset) proceeds.
    private var openInFlight = false

    #if DEBUG
        /// TEST HOOK (DEBUG only): when the host process is launched with
        /// `-appScreensDisablePrewarm`, `links`-hint prewarming is skipped. Lets a
        /// UI test exercise the deterministic cold → optimistic → warm-reuse paths without
        /// a prewarm racing (and satisfying) the first navigation. No effect in
        /// release builds or normal use.
        let prewarmDisabledForTesting =
            ProcessInfo.processInfo.arguments.contains("-appScreensDisablePrewarm")
    #endif

    /// Forwards `WKScriptMessageHandler` callbacks weakly so a web view's content
    /// controller never retains the navigator.
    private let messageProxy = WeakScriptMessageProxy()

    /// Web view navigation delegate. Forwards
    /// `webViewWebContentProcessDidTerminate` back to the navigator for liveness
    /// recovery (visible → recover-and-replay; idle warm → tear down).
    private let navigationDelegate = AppScreenNavigationDelegate()

    /// The `willEnterForegroundNotification` observer, registered once in `init`.
    /// On foreground it refetches+shows the visible live session(s), restarting the
    /// runtime poll loop the OS stalled while the app was backgrounded. Removed in
    /// `deinit` for the singleton's tidy teardown.
    private var willEnterForegroundObserver: NSObjectProtocol?

    /// The anonymous document channel's own `URLSession` + `URLCache`. Kept
    /// separate from `HTTPClient` and from the process's shared storages so the
    /// channel carries no identifying state: no account token, no
    /// `Authorization` header, no identifier query items, no cookies, and no
    /// stored credentials. Document caching (`max-age`/`ETag`) is likewise
    /// isolated from all other traffic in its own dedicated cache.
    let documentSession: URLSession

    /// Bounds for the master pipeline's awaits (seconds), so a stalled load can
    /// never present an infinite skeleton.
    static let documentTimeout: Double = 12
    static let loadedTimeout: Double = 10
    static let showTimeout: Double = 12
    private static let jsonTimeout: Double = 12

    init(
        httpClient: HTTPClient,
        configManager: ConfigManager,
        associatedDomains: [String],
        eventQueue: EventQueue?
    ) {
        self.httpClient = httpClient
        self.configManager = configManager
        self.associatedDomains = Set(associatedDomains.map { $0.lowercased() })
        self.eventQueue = eventQueue

        let cacheDirectory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("io.rover.appscreens.documents", isDirectory: true)
        let cache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024,
            directory: cacheDirectory
        )
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        configuration.requestCachePolicy = .useProtocolCachePolicy
        // Keep the channel bare: no cookies and no credentials may ride along on
        // the anonymous HTML fetch or the PUBLIC `.json` fetch, so a session
        // cookie set elsewhere can never make public content user-specific.
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCredentialStorage = nil
        self.documentSession = URLSession(configuration: configuration)

        super.init()
        messageProxy.delegate = self
        navigationDelegate.navigator = self

        // Refresh-now on app foreground: both OSes throttle/suspend hidden-app timers,
        // so a live screen's runtime poll loop stalls while backgrounded. Registered
        // once (the navigator is a singleton). The block is delivered on `.main`, where
        // it is already actor-isolated in practice.
        willEnterForegroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshVisibleLiveSessions()
            }
        }
    }

    deinit {
        // Cheap guard for the singleton ever being torn down: stop the stagger loop
        // and any in-flight prewarm workers. They also hold weak references and
        // unwind on their own once `self` is gone.
        prewarmSchedulerTask?.cancel()
        for worker in prewarmWorkerTasks {
            worker.cancel()
        }
        if let willEnterForegroundObserver {
            NotificationCenter.default.removeObserver(willEnterForegroundObserver)
        }
    }

    /// Builds the session + host for the App Screens root-hosting entry point,
    /// marks the session on-stack, applies the dismiss/open-URL overrides, and wires
    /// host callbacks. Stops short of starting the master pipeline and of the
    /// flow-token bookkeeping ``makeRootHost(flow:url:navigating:onDismiss:onOpenURL:)``
    /// does after calling this.
    private func buildRootSession(
        for url: URL,
        onDismissButtonPressed: (() -> Void)?,
        onOpenURL: ((URL) -> Void)?
    ) -> (session: AppScreenSession, host: AppScreensPageViewController) {
        // The entry URL is pre-gated upstream (ExperienceViewController normalizes +
        // domain-checks), so `templateKey` succeeds in practice; the fallback stays
        // origin-qualified so even a contract-violating non-`/a/` entry can never
        // collide across domains.
        let templateKey = Self.templateKey(from: url) ?? Self.fallbackTemplateKey(for: url)
        let screenBackground = Self.defaultScreenBackground
        let webView = makeWebView(screenBackground: screenBackground)

        let session = AppScreenSession(
            templateKey: templateKey,
            webView: webView,
            state: .loadingDocument
        )
        // The root is on the stack (at its navigation controller's root) for the
        // whole presentation. It is tracked in `rootSessions`, NOT the keyed
        // `sessions` pool: a second concurrent presentation of the same template
        // must not evict this one from `liveSession(for:)`. Its owning
        // presentation releases it via `releaseRootSession(_:)`.
        session.documentURL = url
        session.isOnStack = true
        // Host overrides for external links, set only on the root session: the
        // dismissal tears down the enclosing Experience for an `openURL` carrying
        // `dismiss: true`, and the opener (when supplied) handles `openURL` targets
        // in place of `UIApplication.shared.open`. Both are `nil` for an embedded
        // presentation that opted into neither.
        session.onDismissButtonPressed = onDismissButtonPressed
        session.onOpenURL = onOpenURL
        rootSessions.append(session)

        let host = AppScreensPageViewController(
            webView: webView,
            screenBackground: screenBackground,
            showsSkeleton: true
        )
        session.hostViewController = host
        // The root can be occluded by a pushed detail; wire its visibility callback
        // so a recovery deferred while occluded fires when the user pops back to it.
        // The root's teardown is driven by ``release(_:)``.
        wireHostCallbacks(to: host, for: session)

        return (session, host)
    }

    /// Vends the flow-scoped root host view controller for an App Screens entry URL,
    /// for SwiftUI hosting: builds the root session/host via
    /// ``buildRootSession(for:onDismissButtonPressed:onOpenURL:)``, additionally
    /// stamping the owning ``AppScreensToken`` and ``AppScreensNavigating``
    /// coordinator on the session and registering it in ``sessionsByToken`` so
    /// ``release(_:)`` can find and release it later without any UIKit
    /// navigation controller to walk. Called by the view for the `.root` role —
    /// never inferred from record absence the way pushed screens are.
    package func makeRootHost(
        token: AppScreensToken,
        url: URL,
        navigating: AppScreensNavigating,
        onDismiss: (() -> Void)?,
        onOpenURL: ((URL) -> Void)?,
        onOpenExternalURL: ((URL, Bool) -> Void)? = nil
    ) -> UIViewController {
        os_log(
            "Creating flow-scoped App Screens root host for %{public}@",
            log: .appScreens,
            type: .info,
            url.absoluteString
        )

        let (session, host) = buildRootSession(
            for: url,
            onDismissButtonPressed: onDismiss,
            onOpenURL: onOpenURL
        )
        session.token = token
        session.navigating = navigating
        sessionsByToken[token, default: [:]][ObjectIdentifier(session)] = session
        registerOpenHandler(onOpenExternalURL, for: token)

        runMasterPipeline(entryURL: url, session: session, host: host)
        return host
    }

    /// Registers (or, with `nil`, clears) the owner's dismiss-then-open handler for a
    /// flow. Called by `makeRootHost` for the root flow and by `AppScreensSheetHostView`
    /// for each sheet flow.
    package func registerOpenHandler(_ handler: ((URL, Bool) -> Void)?, for token: AppScreensToken) {
        openHandlersByToken[token] = handler
    }

    // MARK: - Master pipeline

    /// Cold-loads the master: fetch the anonymous document → `loadHTMLString` →
    /// await the runtime `loaded` message → `show()` → reveal. Every await is
    /// time-bounded; any failure surfaces a retry affordance instead of an
    /// infinite skeleton. (Full recover-and-replay lives in the liveness path.)
    private func runMasterPipeline(
        entryURL: URL,
        session: AppScreenSession,
        host: AppScreensPageViewController
    ) {
        session.state = .loadingDocument
        session.runtimeDidLoad = false
        // A fresh navigation into the session restores its single recovery budget.
        session.didAttemptRecovery = false

        // Supersede any previous pipeline still writing into this session's web
        // view (a warm reuse legitimately replaces the prior navigation).
        session.pipelineTask?.cancel()
        session.pipelineTask = Task { [weak self, weak host] in
            guard let self, let host else {
                return
            }

            do {
                // The `.json` request now derives from the document: the document
                // response header carries the screen's data scope, which decides
                // whether the data fetch attaches identifiers. So await the document
                // first (it drives `loadHTMLString` + runtime boot AND supplies the
                // scope), then start the `.json` fetch with that effective scope.
                // Kicking `.json` off here — after the document lands but before the
                // runtime boot + SSR reveal — still overlaps it with that work; only
                // the pure network overlap on a cold start is forfeit, which the
                // scope dependency requires.
                let (html, etag, dataScope) = try await withTimeout(seconds: Self.documentTimeout) {
                    try await self.fetchDocument(url: entryURL)
                }
                session.documentETag = etag
                session.dataScope = dataScope
                os_log(
                    "document loaded [%{public}@] etag=%{public}@ scope=%{public}@",
                    log: .appScreens,
                    type: .info,
                    session.templateKey,
                    etag ?? "(none)",
                    Self.effectiveScope(dataScope).rawValue
                )

                let effectiveScope = Self.effectiveScope(session.dataScope)
                async let jsonResult = withTimeout(seconds: Self.jsonTimeout) {
                    try await self.fetchScreenData(for: entryURL, scope: effectiveScope)
                }

                session.state = .awaitingRuntime
                // The fresh document re-announces its own liveness by ticking again,
                // so clear the flag the previous document may have set.
                session.isLive = false
                session.webView?.loadHTMLString(html, baseURL: entryURL)

                try await withTimeout(seconds: Self.loadedTimeout) {
                    try await self.awaitRuntimeLoaded(session)
                }
                session.state = .ready

                // The master's Phase 1 visual is the anonymous SSR body that
                // `loadHTMLString` already painted (roster rows + gray `PHASE 1 ·
                // SSR` banner). Reveal it now — the reveal must NOT be blocked on the
                // identified `.json` fetch, which needs a JWT and can take seconds on
                // a cold token: gating reveal on the morph would strand a ready SSR
                // body behind the skeleton shimmer for that whole window. The SSR
                // body is already a valid render, so reveal it as soon as the runtime
                // has booted, then morph Phase 3 over it in place when `.json` lands.
                // Bail if this pipeline was superseded while the runtime booted — a
                // popped/reused session must not reveal over the new record.
                guard !Task.isCancelled else {
                    return
                }
                host.reveal()

                // Await the concurrently-started `.json` fetch, run the hash
                // handshake against `session.documentETag` (skew can never render),
                // then `show({href, response})` to morph in the full data. A failed
                // `.json` fetch is non-fatal: the SSR body is already revealed, so
                // warn and leave it (fail open on the data channel).
                let href = Self.relativeHref(for: entryURL)

                // The `.json` fetch failing is non-fatal — the SSR body is already a
                // valid render, so fail open on the data channel and leave it.
                let jsonResponse: (rawJSON: String, templateHash: String?, responseScope: AppScreenDataScope?)
                do {
                    jsonResponse = try await jsonResult
                } catch {
                    os_log(
                        "json channel unavailable [%{public}@]: %{public}@ — leaving SSR revealed",
                        log: .appScreens,
                        type: .error,
                        session.templateKey,
                        error.localizedDescription
                    )
                    return
                }

                // Freshen the session's scope from the `.json` response header, but
                // only when it is present — a `nil` never overwrites the scope the
                // document already established.
                if let responseScope = jsonResponse.responseScope {
                    session.dataScope = responseScope
                }

                // The morph itself failing (a `show()` rejection or a document reload
                // failing) is the liveness signal: the SSR was revealed but the
                // process is compromised, so recover-and-replay rather than leaving a
                // frozen screen. `recover` guards itself against looping and against
                // the concurrent `webViewWebContentProcessDidTerminate` trigger.
                do {
                    try await self.runHashHandshakeAndMorph(
                        session: session,
                        entryURL: entryURL,
                        href: href,
                        rawJSON: jsonResponse.rawJSON,
                        templateHash: jsonResponse.templateHash
                    )
                } catch {
                    // A cancelled pipeline (pop/reuse/teardown) surfaces here as a
                    // cancellation error from an aborted await — it must not trigger
                    // recovery on a superseded session.
                    guard !Task.isCancelled else {
                        return
                    }
                    os_log(
                        "morph failed [%{public}@]: %{public}@ — recovering",
                        log: .appScreens,
                        type: .error,
                        session.templateKey,
                        error.localizedDescription
                    )
                    self.recover(session: session, reason: "show rejected")
                }
            } catch {
                // A cancelled pipeline (superseded by a pop/reuse/teardown) unwinds
                // through here — never paint the load-failure UI for it.
                guard !Task.isCancelled else {
                    return
                }
                // The document fetch or first runtime boot failed — this is a cold
                // load failure, not a liveness signal (the web view was never ready),
                // so re-run the whole master pipeline behind the retry error state.
                // Skip if a concurrent termination signal already started a recovery,
                // so the failure UI never paints over an in-flight recover.
                guard !session.isRecovering else {
                    return
                }
                os_log(
                    "master pipeline failed [%{public}@]: %{public}@",
                    log: .appScreens,
                    type: .error,
                    session.templateKey,
                    error.localizedDescription
                )
                host.showLoadFailure { [weak self, weak host] in
                    guard let self, let host else {
                        return
                    }
                    self.runMasterPipeline(entryURL: entryURL, session: session, host: host)
                }
            }
        }
    }

    /// Awaits the runtime `loaded` message. Checks `runtimeDidLoad` first so a
    /// message that already arrived is not missed; otherwise suspends on a
    /// continuation the routed message resumes. Cancellation (e.g. the timeout)
    /// resumes the continuation so the awaiting task can unwind.
    func awaitRuntimeLoaded(_ session: AppScreenSession) async throws {
        guard !session.runtimeDidLoad else {
            return
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                session.runtimeLoadedContinuation = continuation
            }
        } onCancel: {
            Task { @MainActor in
                guard let continuation = session.runtimeLoadedContinuation else {
                    return
                }
                session.runtimeLoadedContinuation = nil
                continuation.resume(throwing: CancellationError())
            }
        }
    }

    // MARK: - Analytics

    /// Posts an App Screens analytics event to the SDK event queue. A navigator
    /// built without a queue (tests) silently records nothing.
    private func track(_ event: EventInfo) {
        guard let eventQueue else {
            return
        }
        os_log(
            "tracking %{public}@",
            log: .appScreens,
            type: .debug,
            event.name
        )
        eventQueue.addEvent(event)
    }

    /// Emits "App Screen Link Clicked" for a tap that resolved to `linkURL` on
    /// `source`'s screen. The event does not record which bridge message carried the
    /// tap — a click is a click, whether it navigated, opened externally, or
    /// presented a website. No-ops when the posting session has no document URL (it
    /// has no screen identity to report), which the callers' own resolution guards
    /// already rule out in practice.
    ///
    /// An off-stack source records nothing. A popped-but-warm or prewarming session
    /// keeps its bridge alive and can post a late message, and a tap on a screen the
    /// user is no longer looking at is not a click.
    ///
    /// For `navigate` the message itself is dropped upstream of this, so the gate here
    /// is redundant for that path. For `openExternalURL` and `presentWebsite` it is
    /// analytics-only: an off-stack source still opens the link or presents the site,
    /// and only the event is withheld. That is a known divergence from Android, whose
    /// `AppScreenNavigator.handlerForActivePresentation` drops all three messages
    /// before the action — tracked as SDK-462
    /// (https://linear.app/rover/issue/SDK-462), not left open here.
    private func trackLinkClicked(from source: AppScreenSession, linkURL: URL) {
        guard let screenURL = source.documentURL, Self.visibility(of: source) != .offStack else {
            return
        }
        track(.appScreenLinkClicked(screenURL: screenURL, linkURL: linkURL))
    }

    /// Emits "App Screen Viewed" for `session` and remembers it as the last screen
    /// reported **in its own flow**, so the sheet-dismissal reveal below cannot report
    /// it twice.
    private func trackViewed(of session: AppScreenSession) {
        guard let screenURL = session.documentURL else {
            return
        }
        if let token = session.token {
            lastViewedSessionIdentityByFlow[token] = ObjectIdentifier(session)
        }
        track(.appScreenViewed(screenURL: screenURL))
    }

    /// Emits "App Screen Viewed" for the screen a dismissed sheet just exposed, within
    /// `presentingFlow` — the flow the sheet was presented over.
    ///
    /// A page sheet never made the stack underneath it disappear, so revealing it
    /// delivers no `viewDidAppear` and the appearance path above cannot see it. This
    /// is the reveal's only signal (the analogue of Android's `onSheetDismissed`),
    /// called from ``release(_:)`` once the sheet flow is torn down.
    ///
    /// Scoped to one flow on purpose. ``rootSessions`` supports concurrent
    /// presentations, so a process-wide search would find two visible screens whenever
    /// two flows are on screen (iPad multi-scene, or a standalone presentation over an
    /// embedded Hub home) and the fail-closed rule would then silently drop every
    /// reveal. Within the flow, exactly one screen is visible.
    ///
    /// Fail-closed within that flow: it reports the single session that reads
    /// `.visible`, and if the dismissal has not settled — nothing visible yet, or
    /// more than one candidate — it reports nothing rather than guessing. A missing
    /// view is a better failure than a wrong one. The identity check covers the
    /// other direction: if a presentation style *did* deliver `viewDidAppear` to the
    /// revealed screen, that path already reported it and this one stays quiet. The
    /// flow's entry is cleared when the sheet is presented, so the check only ever
    /// speaks to the reveal, never to a view from before the sheet covered it.
    func trackScreenExposedByDismissal(inFlowOf presentingFlow: AppScreensToken) {
        let flowSessions = sessionsByToken[presentingFlow].map { Array($0.values) } ?? []
        let exposed = flowSessions.filter { Self.visibility(of: $0) == .visible }
        guard
            exposed.count == 1,
            let session = exposed.first,
            ObjectIdentifier(session) != lastViewedSessionIdentityByFlow[presentingFlow]
        else {
            return
        }
        trackViewed(of: session)
    }

    // MARK: - Message routing

    /// Routes a decoded bridge message to its owning session (matched by web view
    /// identity).
    private func handle(_ message: AppScreenMessage, from webView: WKWebView?, frameInfo: WKFrameInfo) {
        guard
            let webView,
            let session = liveSession(for: webView)
        else {
            return
        }

        // Authenticate the message before routing it. WebKit adds the bridge handler
        // to the default (page) content world, so any subframe — including a
        // cross-origin iframe or an externally navigated page — can post to it.
        // Accept only the expected main frame at the session's authorized origin; a
        // rejection is a security signal, so it is logged at `.error`.
        let origin = frameInfo.securityOrigin
        guard
            let documentURL = session.documentURL,
            Self.bridgeMessageAllowed(
                isMainFrame: frameInfo.isMainFrame,
                originProtocol: origin.`protocol`,
                originHost: origin.host,
                originPort: origin.port,
                documentURL: documentURL
            )
        else {
            os_log(
                "Rejecting unauthorized App Screens bridge message for [%{public}@]: mainFrame=%{public}@ origin=%{public}@://%{public}@:%d",
                log: .appScreens,
                type: .error,
                session.templateKey,
                frameInfo.isMainFrame ? "true" : "false",
                origin.`protocol`,
                origin.host,
                origin.port
            )
            return
        }

        switch message {
        case .loaded:
            session.runtimeDidLoad = true
            guard let continuation = session.runtimeLoadedContinuation else {
                return
            }
            session.runtimeLoadedContinuation = nil
            continuation.resume()
        case .navigate(let href, let optimisticDataJSON, let transition):
            navigate(href: href, optimisticDataJSON: optimisticDataJSON, transition: transition, from: session)
        case .links(let hrefs):
            // Record the latest DOM-ordered prewarm hints on the source session,
            // then schedule staggered prewarms of any templates not already live or
            // in flight.
            session.latestLinkHrefs = hrefs
            os_log(
                "links hint [%{public}@] (%d hrefs)",
                log: .appScreens,
                type: .debug,
                session.templateKey,
                hrefs.count
            )
            schedulePrewarms(fromLinks: hrefs, source: session)
        case .openURL(let href, let dismiss):
            openExternalURL(href: href, dismiss: dismiss, from: session)
        case .presentWebsite(let href):
            presentWebsite(href: href, from: session)
        case .refresh:
            refreshScreen(session: session)
        }
    }

    /// Finds the live session owning `webView`, searching the live root sessions,
    /// the keyed warm sessions, the one-off ephemeral sessions, and sessions still
    /// booting via prewarm (so a prewarming web view's `loaded` message routes to its
    /// continuation before the session is promoted into `sessions`). Roots are
    /// searched independently of the keyed pool so two concurrent presentations of
    /// the same template both resolve to their own session.
    func liveSession(for webView: WKWebView) -> AppScreenSession? {
        if let root = rootSessions.first(where: { $0.webView === webView }) {
            return root
        }
        if let warm = sessions.values.first(where: { $0.webView === webView }) {
            return warm
        }
        if let ephemeral = ephemeralSessions.first(where: { $0.webView === webView }) {
            return ephemeral
        }
        return prewarmingSessions.first(where: { $0.webView === webView })
    }

    // MARK: - Render-time host creation

    /// Claims the ``PendingNavigation`` `navigate` queued for `(flow, address)`, builds
    /// its ``AppScreensPageViewController``, and starts the load pipeline. This is the
    /// render-time half of the SwiftUI cutover: `navigate` resolves a tap into a
    /// session + URL and enqueues that resolution well before `NavigationStack`
    /// materializes the destination view; this is that materialization, called only
    /// for `.pushed` screens (`.root` routes to `makeRootHost` instead, so there is no
    /// record-absence inference here).
    ///
    /// A claim miss is defensive-only (it should never happen on the `.pushed` path,
    /// since a destination only renders after `navigate` enqueued its record) — it
    /// logs and returns a minimal placeholder host rather than silently mis-rendering
    /// or crashing.
    package func makeHost(
        token: AppScreensToken,
        address: AppScreenAddress,
        targetRequest: URLRequest?,
        navigating: AppScreensNavigating
    ) -> UIViewController {
        guard let record = pendingNavigations.claim(for: address, in: token) else {
            // No pending record: SwiftUI is materializing a `navigationDestination`
            // that was NOT reached through `navigate` in this flow — a `.pushed`
            // destination restored from a shared `NavigationPath` into a freshly
            // created flow (e.g. presenting the Hub while its tab already pushed a
            // detail, so the presented flow inherits the tab's path). `navigate`
            // (which enqueues the pending record) never ran for it, so cold-load the
            // address into a fresh ephemeral session rather than returning a blank
            // placeholder host.
            os_log(
                "makeHost found no pending navigation for %{public}@ — cold-loading restored destination",
                log: .appScreens,
                type: .info,
                address.url.absoluteString
            )
            return makeColdFallbackHost(
                token: token,
                address: address,
                targetRequest: targetRequest,
                navigating: navigating
            )
        }

        // A claimed prewarmed session's web view is currently parented in its
        // off-screen boot window; release it so the render can reparent the view into
        // the host. No-op for master/cold/ephemeral sessions.
        detachFromOffscreenWindow(record.session)

        return attachHost(
            to: record.session,
            resolvedURL: record.resolvedURL,
            optimisticDataJSON: record.optimisticDataJSON,
            isColdLoad: record.isColdLoad,
            tapTime: record.tapTime,
            token: token,
            navigating: navigating
        )
    }

    /// Builds the host for `session`, wires its callbacks, stamps its flow identity,
    /// registers it in ``sessionsByToken`` so ``release(_:)`` can tear it down, and
    /// starts the load pipeline. Shared by ``makeHost(flow:address:targetRequest:navigating:)``'s
    /// claimed-record path and its cold-load fallback.
    private func attachHost(
        to session: AppScreenSession,
        resolvedURL: URL,
        optimisticDataJSON: String?,
        isColdLoad: Bool,
        tapTime: DispatchTime,
        token: AppScreensToken,
        navigating: AppScreensNavigating
    ) -> AppScreensPageViewController {
        // A reused web view already shows real (previous) content that the next
        // hydrate morphs in place, so it skips the skeleton; a cold/ephemeral load
        // shows the skeleton behind its 300 ms grace.
        let host = AppScreensPageViewController(
            webView: session.webView,
            screenBackground: Self.defaultScreenBackground,
            showsSkeleton: isColdLoad
        )
        session.hostViewController = host
        wireHostCallbacks(to: host, for: session)

        session.navigating = navigating
        session.token = token
        sessionsByToken[token, default: [:]][ObjectIdentifier(session)] = session

        runNavigatePipeline(
            resolvedURL: resolvedURL,
            optimisticDataJSON: optimisticDataJSON,
            session: session,
            host: host,
            isColdLoad: isColdLoad,
            tapTime: tapTime
        )

        return host
    }

    /// Cold-loads `address` into a fresh **ephemeral** session when ``makeHost`` finds
    /// no pending record (a destination restored from a shared `NavigationPath` into a
    /// new flow). An ephemeral session is deliberate: it is isolated from the shared
    /// warm pool (so it never clobbers a template session the originating flow still
    /// owns) and is torn down on pop / ``release(_:)``, matching the one-off nature
    /// of a restored screen. Returns the inert placeholder only if the address cannot
    /// be keyed (never expected for a valid App Screen address).
    private func makeColdFallbackHost(
        token: AppScreensToken,
        address: AppScreenAddress,
        targetRequest: URLRequest?,
        navigating: AppScreensNavigating
    ) -> UIViewController {
        let resolvedURL = targetRequest?.url ?? address.url
        guard let templateKey = Self.templateKey(from: resolvedURL) else {
            return AppScreensPageViewController(
                webView: nil,
                screenBackground: Self.defaultScreenBackground,
                showsSkeleton: false
            )
        }

        let webView = makeWebView(screenBackground: Self.defaultScreenBackground)
        let session = AppScreenSession(templateKey: templateKey, webView: webView, state: .loadingDocument)
        session.isEphemeral = true
        session.documentURL = resolvedURL
        // On the stack for its whole presentation, mirroring the `.push`/`.sheet`
        // navigate branches that set this at resolve time.
        session.isOnStack = true
        ephemeralSessions.append(session)

        return attachHost(
            to: session,
            resolvedURL: resolvedURL,
            optimisticDataJSON: nil,
            isColdLoad: true,
            tapTime: .now(),
            token: token,
            navigating: navigating
        )
    }

    // MARK: - Navigation

    /// Handles a `navigate` bridge message: resolves the target, selects/creates a
    /// session, pushes a host immediately (the transition covers the load), arms
    /// the edge-swipe assist, and runs the bounded pipeline.
    ///
    /// `package` (not `private`) so `AppScreenNavigatePushTests` can drive it directly
    /// via `@testable import`, without going through the bridge message handler.
    package func navigate(
        href: String,
        optimisticDataJSON: String?,
        transition: AppScreenTransition?,
        from source: AppScreenSession
    ) {
        let tapTime = DispatchTime.now()

        // The posting screen must still be on a navigation stack. A popped template
        // session is kept warm with its web view — and therefore its bridge — alive
        // (``handlePop(of:)``), and a prewarming session boots a whole runtime
        // off-screen, so either can post a late `navigate` long after the user left
        // it. Acting on one would push into whatever presentation is on screen now
        // and report a tap the user never made on a screen they are no longer
        // looking at. An `.occluded` source (on the stack, covered by a detail or a
        // sheet) is deliberately still allowed: it is a live screen the user can
        // return to, and its runtime may legitimately navigate on their behalf.
        guard Self.visibility(of: source) != .offStack else {
            os_log(
                "Dropping navigate from off-stack session [%{public}@] — its screen is no longer on a navigation stack",
                log: .appScreens,
                type: .info,
                source.templateKey
            )
            return
        }

        guard
            let sourceDocumentURL = source.documentURL,
            let rawResolvedURL = Self.resolveHref(href, against: sourceDocumentURL)
        else {
            os_log(
                "navigate could not resolve href %{public}@ against %{public}@",
                log: .appScreens,
                type: .error,
                href,
                source.documentURL?.absoluteString ?? "(no document URL)"
            )
            return
        }

        // Authorize the resolved target before touching any session or the network:
        // it must be an `/a/{template}` App Screens URL, http(s) (normalized to
        // https), and hosted on one of the app's associated domains — mirroring the
        // entry point's gate. A screen that tries to steer navigation to a foreign
        // origin (where the personalized `.json` fetch would leak the account token
        // and device/user identifiers, and attacker HTML would load with the bridge)
        // is rejected here. Rejection is a security signal, so it logs at `.error`.
        guard let target = Self.authorizedTarget(resolvedURL: rawResolvedURL, allowedHosts: associatedDomains) else {
            os_log(
                "Rejecting unauthorized App Screens navigation to %{public}@ (resolved %{public}@)",
                log: .appScreens,
                type: .error,
                href,
                rawResolvedURL.absoluteString
            )
            return
        }
        let resolvedURL = target.url
        // Analytics: the tap is a click only now that the target passed the
        // associated-domain gate above — a rejected navigation is not a click.
        trackLinkClicked(from: source, linkURL: resolvedURL)
        // The authorized target is a normalized `/a/{template}` https URL, so
        // `templateKey` always resolves; guard defensively rather than force-unwrap.
        // The origin-qualified key (not the bare template path) is the session slot,
        // so two associated domains serving the same path never share a warm web view.
        guard let templateKey = Self.templateKey(from: resolvedURL) else {
            return
        }
        let existing = sessions[templateKey]
        let hasWarmReady = existing?.state == .ready
        let isOnStack = existing?.isOnStack ?? false
        let selection = Self.selectSession(hasWarmReady: hasWarmReady, isOnStack: isOnStack)

        os_log(
            "navigate → [%{public}@] %{public}@ (optimisticData=%{public}@)",
            log: .appScreens,
            type: .info,
            templateKey,
            String(describing: selection),
            optimisticDataJSON == nil ? "no" : "yes"
        )

        let session: AppScreenSession
        let isColdLoad: Bool
        switch selection {
        case .reuse:
            guard let existing else {
                return
            }
            session = existing
            session.isEphemeral = false
            isColdLoad = false
        case .ephemeral:
            let webView = makeWebView(screenBackground: Self.defaultScreenBackground)
            session = AppScreenSession(templateKey: templateKey, webView: webView, state: .loadingDocument)
            session.isEphemeral = true
            ephemeralSessions.append(session)
            isColdLoad = true
        case .cold:
            let webView = makeWebView(screenBackground: Self.defaultScreenBackground)
            session = AppScreenSession(templateKey: templateKey, webView: webView, state: .loadingDocument)
            session.isEphemeral = false
            // The slot is free (nothing warm-ready and nothing on stack); store as
            // the template's warm session so a later navigation can reuse it.
            sessions[templateKey] = session
            isColdLoad = true
        }
        session.documentURL = resolvedURL

        guard session.webView != nil else {
            return
        }

        // An absent transition (or an unrecognized value the bridge already mapped
        // to `nil`) defaults to push; only an explicit "sheet" presents modally.
        switch transition ?? .push {
        case .push:
            guard let address = AppScreenAddress(rawURL: resolvedURL) else {
                return
            }
            if let token = source.token {
                // New SwiftUI path: defer host creation to `makeHost` via the pending
                // record. `isOnStack` is set here (not at render time) so a rapid
                // second `navigate` to the same template sees it and selects
                // `.ephemeral` rather than reusing the not-yet-rendered session.
                session.isOnStack = true
                pendingNavigations.enqueue(
                    PendingNavigation(
                        session: session,
                        resolvedURL: resolvedURL,
                        optimisticDataJSON: optimisticDataJSON,
                        isColdLoad: isColdLoad,
                        tapTime: tapTime
                    ),
                    for: address,
                    in: token
                )
                source.navigating?.pushScreen(address: address, targetRequest: URLRequest(url: resolvedURL))
            }
        case .sheet:
            guard let address = AppScreenAddress(rawURL: resolvedURL) else {
                return
            }
            if let sourceToken = source.token {
                // A sheet opens a NEW flow, so mint a fresh token for it — but remember
                // which flow it was presented over, so the dismissal's view accounting
                // can be scoped to the stack this sheet is covering.
                let sheetToken = AppScreensToken()
                presentingFlowBySheetFlow[sheetToken] = sourceToken
                // The presenting flow's last-reported screen is about to be covered, so
                // it stops standing for "already counted": when this sheet is dismissed
                // and that screen is exposed again, it is a new view. Clearing here keeps
                // the identity check meaning what it says — "the reveal itself was
                // already reported by an appearance callback" — instead of suppressing
                // every reveal over a screen that had been seen before the sheet opened.
                lastViewedSessionIdentityByFlow[sourceToken] = nil
                // `isOnStack` is set here (not at render time) so a rapid second navigate to
                // the same template sees it and selects `.ephemeral` rather than reusing the
                // not-yet-rendered session.
                session.isOnStack = true
                pendingNavigations.enqueue(
                    PendingNavigation(
                        session: session,
                        resolvedURL: resolvedURL,
                        optimisticDataJSON: optimisticDataJSON,
                        isColdLoad: isColdLoad,
                        tapTime: tapTime
                    ),
                    for: address,
                    in: sheetToken
                )
                source.navigating?.presentSheet(
                    address: address,
                    targetRequest: URLRequest(url: resolvedURL),
                    sheetToken: sheetToken
                )
            }
        }
    }

    /// The per-navigate async pipeline. Mirrors the master pipeline but adds
    /// optimistic paint and the warm-reuse (content-over-content, no skeleton) path.
    ///
    /// - Cold/ephemeral: fetch document → `loadHTMLString` → await `loaded` → (optimisticData?
    ///   `show({href,optimisticData})` → reveal) → fetch `.json` → handshake →
    ///   `show({href,optimisticData,response})` morph.
    /// - Warm reuse: reset scroll; the previous content stays painted; (optimisticData?
    ///   `show({href,optimisticData})` morphs to the optimistic data) → fetch `.json` → morph. No skeleton.
    private func runNavigatePipeline(
        resolvedURL: URL,
        optimisticDataJSON: String?,
        session: AppScreenSession,
        host: AppScreensPageViewController,
        isColdLoad: Bool,
        tapTime: DispatchTime
    ) {
        let templateKey = session.templateKey
        let warmReuse = !isColdLoad
        let showHref = Self.relativeHref(for: resolvedURL)

        // A fresh navigation into the session restores its single recovery budget
        // (matters for a warm-reused session that recovered on a previous visit).
        session.didAttemptRecovery = false

        if isColdLoad {
            session.state = .loadingDocument
            session.runtimeDidLoad = false
            session.runtimeLoadedContinuation = nil
        } else {
            // Reused web view: bring the previous content back to the top so the new
            // screen doesn't push in mid-scroll.
            session.webView?.scrollView.setContentOffset(.zero, animated: false)
        }

        let navSignpostID = appScreensSignposter.makeSignpostID()
        let navInterval = appScreensSignposter.beginInterval("navigate→reveal", id: navSignpostID)

        // Supersede any previous pipeline of this session before this navigation
        // writes into the (possibly warm-reused) web view. A late response from
        // the prior navigation must not `show()` or reveal over this one.
        session.pipelineTask?.cancel()
        session.pipelineTask = Task { [weak self, weak host] in
            guard let self, let host else {
                appScreensSignposter.endInterval("navigate→reveal", navInterval)
                return
            }

            // Log the headline tap→reveal number once, at the first moment the
            // pushed screen reflects the tapped target.
            var revealLogged = false
            func logTapToReveal() {
                guard !revealLogged else {
                    return
                }
                revealLogged = true
                appScreensSignposter.endInterval("navigate→reveal", navInterval)
                os_log(
                    "tap→reveal [%{public}@] %{public}.0fms (%{public}@)",
                    log: .appScreens,
                    type: .info,
                    templateKey,
                    Self.elapsedMs(since: tapTime),
                    warmReuse ? "warm" : "cold"
                )
            }
            // Close the interval even if the pipeline fails before revealing, so a
            // hard cold-load failure never leaves a dangling Instruments span.
            defer {
                if !revealLogged {
                    appScreensSignposter.endInterval("navigate→reveal", navInterval)
                }
            }

            do {
                // The `.json` request derives from the document's data scope. When
                // the scope is already known — a warm/prewarmed session, or (for an
                // ephemeral detail→detail load) the warm session still stored for the
                // same template — kick the fetch off concurrently with the
                // document/optimistic work using that scope. On a cold load with an unknown
                // scope, the fetch must wait until the document lands and sets
                // `session.dataScope` (the document header carries the scope), so the
                // `async let` below resolves to `nil` and the fetch happens after.
                //
                // On a cold load this eager scope is only a guess: the fresh
                // document may declare a different scope (a PUBLIC↔PERSONALIZED
                // config change). When it lands we reconcile — see
                // `shouldRestartEagerFetch` — discarding a mis-scoped concurrent
                // result (without surfacing its error) and refetching under the
                // document's effective scope, so we never send identifiers to a
                // now-public screen nor strand SSR content on a stale public failure.
                let knownScope = session.dataScope ?? self.sessions[templateKey]?.dataScope
                async let concurrentJSON:
                    (rawJSON: String, templateHash: String?, responseScope: AppScreenDataScope?)? = {
                        guard let knownScope else {
                            return nil
                        }
                        return try await withTimeout(seconds: Self.jsonTimeout) {
                            try await self.fetchScreenData(for: resolvedURL, scope: knownScope)
                        }
                    }()

                // Set when the fresh document's scope disagrees with the eager
                // fetch's guessed scope: the concurrent result is discarded and a
                // fresh, correctly-scoped fetch runs at the join below.
                var reconcileEagerFetch = false

                if isColdLoad {
                    let (html, etag, dataScope) = try await withTimeout(seconds: Self.documentTimeout) {
                        try await self.fetchDocument(url: resolvedURL)
                    }
                    session.documentETag = etag
                    session.dataScope = dataScope
                    os_log(
                        "document loaded [%{public}@] etag=%{public}@ scope=%{public}@",
                        log: .appScreens,
                        type: .info,
                        templateKey,
                        etag ?? "(none)",
                        Self.effectiveScope(dataScope).rawValue
                    )

                    // Reconcile the concurrent fetch (if one started under a guessed
                    // scope) against the document's now-known scope. On a mismatch,
                    // settle the mis-scoped task WITHOUT surfacing its error (a stale
                    // public request may have failed with a 401), then refetch fresh
                    // under the effective scope at the join.
                    let effectiveScope = Self.effectiveScope(dataScope)
                    if Self.shouldRestartEagerFetch(eagerScope: knownScope, effectiveScope: effectiveScope) {
                        os_log(
                            "eager fetch scope reconcile [%{public}@] eager=%{public}@ effective=%{public}@ — discarding and refetching",
                            log: .appScreens,
                            type: .default,
                            templateKey,
                            (knownScope?.rawValue ?? "(none)"),
                            effectiveScope.rawValue
                        )
                        _ = try? await concurrentJSON
                        reconcileEagerFetch = true
                    }

                    session.state = .awaitingRuntime
                    // A fresh document announces its own liveness by ticking, so clear
                    // any liveness the reused/previous document had set.
                    session.isLive = false
                    session.webView?.loadHTMLString(html, baseURL: resolvedURL)
                    try await withTimeout(seconds: Self.loadedTimeout) {
                        try await self.awaitRuntimeLoaded(session)
                    }
                    session.state = .ready
                }

                if let optimisticDataJSON {
                    // Optimistic paint (zero network): amber PHASE 2 on cold, content-over-
                    // content morph on warm reuse. Reveal after the optimistic data lands. By now
                    // the web view is ready, so a `show()` rejection here is a liveness
                    // signal — route it through recovery rather than the cold-load
                    // failure path.
                    let payload = ShowPayload(href: showHref, optimisticDataJSON: optimisticDataJSON, responseJSON: nil)
                    do {
                        let hydrateMs = try await withTimeout(seconds: Self.showTimeout) {
                            try await self.performShow(session: session, payload: payload)
                        }
                        os_log(
                            "optimistic data painted [%{public}@] hydrateMs=%{public}.1f",
                            log: .appScreens,
                            type: .info,
                            templateKey,
                            hydrateMs
                        )
                        // `callAsyncJavaScript` may not observe cancellation
                        // mid-flight, so re-check before revealing over a session
                        // popped/reused while the optimistic show ran.
                        guard !Task.isCancelled else {
                            return
                        }
                        host.reveal()
                        logTapToReveal()
                    } catch {
                        // A superseded pipeline unwinds here on cancellation — never
                        // recover a popped/reused session.
                        guard !Task.isCancelled else {
                            return
                        }
                        os_log(
                            "optimistic show rejected [%{public}@]: %{public}@ — recovering",
                            log: .appScreens,
                            type: .error,
                            templateKey,
                            error.localizedDescription
                        )
                        self.recover(session: session, reason: "optimistic show rejected")
                        return
                    }
                } else if isColdLoad {
                    // No optimistic data on a cold load: reveal the anonymous SSR body now (the
                    // morph lands when `.json` resolves).
                    guard !Task.isCancelled else {
                        return
                    }
                    host.reveal()
                    logTapToReveal()
                }
                // Warm reuse with no optimistic data: keep the previous content painted (no
                // reveal, no skeleton) until the `.json` morph below.

                // The `.json` fetch failing is non-fatal (the current content is a
                // valid render); the morph/`show()` failing is the liveness signal.
                // Consume the concurrent fetch if a known scope started one and its
                // scope was reconciled against the document; otherwise (cold load
                // with an unknown or mis-scoped eager fetch) fetch now that the
                // document has set `session.dataScope`.
                let jsonResponse: (rawJSON: String, templateHash: String?, responseScope: AppScreenDataScope?)
                do {
                    if !reconcileEagerFetch, let concurrent = try await concurrentJSON {
                        jsonResponse = concurrent
                    } else {
                        let scope = Self.effectiveScope(session.dataScope)
                        jsonResponse = try await withTimeout(seconds: Self.jsonTimeout) {
                            try await self.fetchScreenData(for: resolvedURL, scope: scope)
                        }
                    }
                } catch {
                    // A cancelled fetch (pop/reuse) unwinds here — do not reveal over
                    // the session that superseded this one.
                    guard !Task.isCancelled else {
                        return
                    }
                    os_log(
                        "json channel unavailable [nav %{public}@]: %{public}@ — leaving current content",
                        log: .appScreens,
                        type: .error,
                        templateKey,
                        error.localizedDescription
                    )
                    // Ensure the screen is never stuck behind the skeleton: a cold
                    // load without optimistic data already revealed the SSR; a warm reuse with
                    // no optimistic data still shows the previous content — reveal to be safe.
                    host.reveal()
                    logTapToReveal()
                    return
                }

                // Freshen scope from the `.json` response header when present.
                if let responseScope = jsonResponse.responseScope {
                    session.dataScope = responseScope
                }

                do {
                    try await self.runHashHandshakeAndMorph(
                        session: session,
                        entryURL: resolvedURL,
                        href: showHref,
                        optimisticDataJSON: optimisticDataJSON,
                        rawJSON: jsonResponse.rawJSON,
                        templateHash: jsonResponse.templateHash
                    )
                    // `callAsyncJavaScript` inside the morph may not observe
                    // cancellation mid-flight, so re-check before revealing.
                    guard !Task.isCancelled else {
                        return
                    }
                    host.reveal()
                    logTapToReveal()
                } catch {
                    // A superseded pipeline unwinds here on cancellation — never
                    // recover a popped/reused session.
                    guard !Task.isCancelled else {
                        return
                    }
                    os_log(
                        "morph failed [nav %{public}@]: %{public}@ — recovering",
                        log: .appScreens,
                        type: .error,
                        templateKey,
                        error.localizedDescription
                    )
                    self.recover(session: session, reason: "show rejected")
                }
            } catch {
                // A cancelled pipeline (superseded by a pop/reuse/teardown) unwinds
                // through here — never paint the load-failure UI for it.
                guard !Task.isCancelled else {
                    return
                }
                // The document fetch or first runtime boot failed — a cold load
                // failure, not a liveness signal. Re-run the navigation behind the
                // retry error state, unless a concurrent termination signal already
                // started a recovery (don't paint failure over an in-flight recover).
                guard !session.isRecovering else {
                    return
                }
                os_log(
                    "navigate pipeline failed [%{public}@]: %{public}@",
                    log: .appScreens,
                    type: .error,
                    templateKey,
                    error.localizedDescription
                )
                host.showLoadFailure { [weak self, weak host] in
                    guard let self, let host else {
                        return
                    }
                    self.runNavigatePipeline(
                        resolvedURL: resolvedURL,
                        optimisticDataJSON: optimisticDataJSON,
                        session: session,
                        host: host,
                        // Retry always cold-reloads: the document/runtime is the part
                        // that failed, so a warm reuse assumption no longer holds.
                        isColdLoad: true,
                        tapTime: DispatchTime.now()
                    )
                }
            }
        }
    }

    // MARK: - Refresh

    /// Honors a `{type:"refresh"}` tick: a runtime-driven poll that refetches the
    /// screen the session already navigated to and re-`show()`s it, which re-arms the
    /// runtime's own one-shot poll loop. The refresh timing logic is wholly internal
    /// to the App Screens JavaScript — the tick itself is the only liveness signal
    /// native gets — so the first one latches `isLive`.
    ///
    /// Gates: drop unless the session is idle
    /// (`state == .ready`; an in-flight pipeline's own `show()` re-arms the loop
    /// anyway) and currently visible (a warm/occluded web view keeps running timers
    /// and can post ticks, but its `show()` can never resolve off-screen — it would
    /// only burn the show timeout). A dropped tick leaves the runtime's loop unarmed
    /// by design; a later reappear/foreground/navigation re-arms it.
    ///
    /// The refetch rides the session's normal `pipelineTask` slot (cancel-replace), so
    /// a navigate arriving mid-refresh supersedes it through the existing idiom, and
    /// goes through the full handshake + morph so the go-quiet document reload comes
    /// along for free. Error policy = web parity: a failed refetch logs and does NOT
    /// re-`show()`, leaving the loop unarmed (no retries, no stale re-show).
    private func refreshScreen(session: AppScreenSession) {
        // Latch liveness before the visibility/busy early returns: even a tick that
        // is then dropped tells native this document is live, so a later
        // reappear/foreground can re-arm the loop this hidden tick leaves unarmed.
        //
        // Gate the latch on `runtimeDidLoad`. A genuine tick can only originate from
        // a runtime that has loaded and completed a `show()` (which is what arms the
        // one-shot timer), so `runtimeDidLoad` is necessarily true for any legitimate
        // tick — gating never suppresses a real latch. But a tick arriving while the
        // session is still loading a *new* document (`.loadingDocument` /
        // `.awaitingRuntime`, where `runtimeDidLoad` was reset to false at the
        // document-load choke point) can only be a stale, already-queued tick from
        // the *previous* document. Latching from it would wrongly mark the
        // replacement screen live and cost a spurious refetch on its next
        // reappear/foreground if that screen is not itself live.
        if session.runtimeDidLoad {
            session.isLive = true
        }

        guard session.state == .ready else {
            os_log(
                "refresh dropped [%{public}@] — session busy (state=%{public}@)",
                log: .appScreens,
                type: .debug,
                session.templateKey,
                String(describing: session.state)
            )
            return
        }
        guard Self.visibility(of: session) == .visible else {
            os_log(
                "refresh dropped [%{public}@] — not visible (%{public}@); loop left unarmed",
                log: .appScreens,
                type: .info,
                session.templateKey,
                String(describing: Self.visibility(of: session))
            )
            return
        }
        guard let documentURL = session.documentURL else {
            return
        }

        let href = Self.relativeHref(for: documentURL)
        let scope = Self.effectiveScope(session.dataScope)
        os_log(
            "refresh [%{public}@] %{public}@ scope=%{public}@",
            log: .appScreens,
            type: .info,
            session.templateKey,
            href,
            scope.rawValue
        )

        // Occupy the session's single pipeline slot so a navigate arriving mid-refresh
        // cancels it via the standard cancel-replace idiom (reaching here implies no
        // active pipeline: `state == .ready`).
        session.pipelineTask?.cancel()
        session.pipelineTask = Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let jsonResponse = try await withTimeout(seconds: Self.jsonTimeout) {
                    try await self.fetchScreenData(for: documentURL, scope: scope)
                }
                // Freshen the session's scope from the `.json` response header when present.
                if let responseScope = jsonResponse.responseScope {
                    session.dataScope = responseScope
                }
                try await self.runHashHandshakeAndMorph(
                    session: session,
                    entryURL: documentURL,
                    href: href,
                    optimisticDataJSON: nil,
                    rawJSON: jsonResponse.rawJSON,
                    templateHash: jsonResponse.templateHash
                )
            } catch {
                // A navigate/pop/teardown superseding this refresh cancels the task —
                // exit quietly, never treating it as a refresh failure.
                guard !Task.isCancelled else {
                    return
                }
                // Web parity: a failed refresh logs and does NOT re-`show()`. The
                // runtime's loop stays unarmed; the next reappear/foreground/navigation
                // re-arms it. (A genuine WebContent death is handled independently by
                // the navigation delegate's termination path.)
                os_log(
                    "refresh failed [%{public}@]: %{public}@ — loop left unarmed",
                    log: .appScreens,
                    type: .error,
                    session.templateKey,
                    error.localizedDescription
                )
            }
        }
    }

    /// Refreshes every visible live session on app foreground. Only visible + live
    /// sessions qualify (`refreshScreen` re-checks both); non-live screens are
    /// deliberately left alone — the runtime never asked for refreshes there, and
    /// refetching every screen on every foreground would be a behavior change with
    /// real fetch cost. In practice only the topmost session of a stack is visible.
    private func refreshVisibleLiveSessions() {
        let onStackSessions = rootSessions + Array(sessions.values) + ephemeralSessions
        for session in onStackSessions
        where session.isLive && Self.visibility(of: session) == .visible {
            refreshScreen(session: session)
        }
    }

    // MARK: - External links

    /// Finds the root session that ultimately owns `source`.
    ///
    /// A root session matches directly against `rootSessions`. Returns `nil` when
    /// `source` is not itself a root (e.g. a torn-down host).
    private func rootSession(owning source: AppScreenSession) -> AppScreenSession? {
        rootSessions.first { $0 === source }
    }

    /// Handles an `openURL` bridge message: interprets the href with browser
    /// `<a href>` semantics (WHATWG resolution against the posting document's URL),
    /// hands it to the root's host opener (or the OS), and — when `dismiss` is set —
    /// tears down the enclosing Experience presentation via the host dismissal.
    package func openExternalURL(href: String, dismiss: Bool, from source: AppScreenSession) {
        guard
            let documentURL = source.documentURL,
            let url = Self.externalURL(from: href, against: documentURL)
        else {
            os_log(
                "openURL dropped unparseable href %{private}@",
                log: .appScreens,
                type: .error,
                href
            )
            return
        }

        // Deliberately NOT run through `authorizedTarget`: unlike `navigate` (which
        // must stay on an associated App Screens domain because it steers the
        // authenticated `.json` channel and the bridge-bearing web view), `openURL`
        // targets arbitrary external URLs and custom-scheme deep links by design. The
        // pre-dispatch main-frame/origin guard in `handle` already authenticated the
        // sender, so the target is handed on as-is.

        // Synchronous double-dispatch guard (dismiss:true only). Navigator-wide, not
        // per-flow: two near-simultaneous DISTINCT dismiss:true deep links in the same
        // runloop tick collapse to first-wins by design (multi-flow is out of scope).
        if dismiss {
            guard !openInFlight else {
                os_log(
                    "openURL ignored: a dismiss open is already in flight",
                    log: .appScreens,
                    type: .info
                )
                return
            }
            openInFlight = true
            scheduleInFlightReset { [weak self] in self?.openInFlight = false }
        }

        // Analytics: emitted after the double-dispatch guard, so a duplicate
        // `dismiss: true` burst collapsed above is counted once, like the open itself.
        trackLinkClicked(from: source, linkURL: url)

        // 2b: the owner controls dismiss-then-open. Resolve the injected handler by the
        // posting session's flow token (works for the root flow and every sheet flow,
        // none of which share a UIKit navigation controller). When present it fully owns
        // sequencing; the old transitionCoordinator wait is gone.
        if let token = source.token, let handler = openHandlersByToken[token] {
            handler(url, dismiss)
            return
        }

        // No injected handler (embedded Hub that opted out of onOpenExternalURL): open
        // in place, no dismiss (today's fallback, minus the transitionCoordinator
        // sequencing).
        guard let root = rootSession(owning: source) else {
            guard dismiss else {
                // dismiss:false with no handler/root session — preserve prior behavior (drop).
                os_log(
                    "openURL found no root session for [%{public}@] — dropping %{private}@",
                    log: .appScreens,
                    type: .error,
                    source.templateKey,
                    url.absoluteString
                )
                return
            }
            // Never silently drop a deep link (dismiss:true): no handler resolved and no
            // root session (e.g. an unregistered/sheet source). Open best-effort instead.
            os_log(
                "openURL: no handler/root session for [%{public}@] — opening best-effort %{private}@",
                log: .appScreens,
                type: .info,
                source.templateKey,
                url.absoluteString
            )
            systemURLOpener(url)
            return
        }

        if dismiss {
            os_log(
                "openURL requested dismiss but no injected open handler; opening in place",
                log: .appScreens,
                type: .info
            )
        }

        if let onOpenURL = root.onOpenURL {
            onOpenURL(url)
        } else {
            systemURLOpener(url)
        }
    }

    /// Handles a `presentWebsite` bridge message: interprets the href with browser
    /// `<a href>` semantics (WHATWG resolution against the posting document's URL) and
    /// coerces it to a Safari-presentable http(s) URL. The flow-tokened (SwiftUI-hosted)
    /// source hands the resolved URL up through its `AppScreensNavigating` seam, so the
    /// presenting screen shows it via `.fullScreenCover` + `SafariView` (parity with
    /// `ScreenView`). Never overridable by the embedding app.
    package func presentWebsite(href: String, from source: AppScreenSession) {
        guard
            let documentURL = source.documentURL,
            let url = Self.externalURL(from: href, against: documentURL),
            let presentableURL = Self.safariPresentableURL(url)
        else {
            os_log(
                "presentWebsite dropped href %{private}@ — not presentable in an in-app browser",
                log: .appScreens,
                type: .error,
                href
            )
            return
        }

        // Analytics: the href resolved to a presentable http(s) URL, so the tap is a
        // click whatever the presentation seam does with it.
        trackLinkClicked(from: source, linkURL: presentableURL)

        if source.token != nil {
            // Migrated (SwiftUI-hosted) source: hand the resolved URL up so the presenting
            // screen shows it via .fullScreenCover + SafariView (parity with ScreenView).
            source.navigating?.presentWebsite(url: presentableURL)
            return
        }
    }

    // MARK: - Pop semantics

    /// Wires a host's lifecycle callbacks to the navigator: `onBecameVisible` for
    /// emitting the "App Screen Viewed" analytics event and for firing a deferred
    /// recovery once an occluded session's screen is on top again.
    private func wireHostCallbacks(to host: AppScreensPageViewController, for session: AppScreenSession) {
        host.onBecameVisible = { [weak self, weak session] in
            guard let self, let session else {
                return
            }
            self.hostBecameVisible(session)
        }
    }

    /// Called from the host's `viewDidAppear`. Emits the screen's
    /// "App Screen Viewed" analytics event, then fires a recovery that was deferred
    /// while the session was occluded (its WebContent process had died off-screen,
    /// where the runtime cannot boot). The recovery half is a no-op on ordinary
    /// appearances; the analytics half runs on every one.
    private func hostBecameVisible(_ session: AppScreenSession) {
        // Analytics: one "App Screen Viewed" per appearance of the screen the user is
        // actually looking at. Driven by the host's `viewDidAppear` rather than the
        // runtime's `loaded` message, so it can never fire for a prewarmed session
        // (which boots in an off-screen window with no view controller at all), and
        // an optimistic push reports the href it is already showing.
        //
        // `.visible` — not merely "appeared" — is the bar, because a page sheet is a
        // non-fullscreen presentation: the stack underneath it is never told it
        // disappeared, so a `navigate` posted by a covered root pushes a destination
        // that receives `viewDidAppear` while the user is still looking at the sheet.
        // ``visibility(of:)`` reads that case as `.occluded` (its
        // `presentedViewController` clause), and an occluded screen has not been seen.
        if Self.visibility(of: session) == .visible {
            trackViewed(of: session)
        }

        guard session.needsRecoveryOnAppear else {
            // No deferred recovery pending. If a live session is reappearing (back-pop,
            // sheet dismiss revealing it), refetch+show once — this freshens the stale
            // screen and re-arms the runtime's poll loop that went unarmed while hidden.
            if session.isLive {
                refreshScreen(session: session)
            }
            return
        }
        session.needsRecoveryOnAppear = false
        os_log(
            "deferred recovery firing on appear [%{public}@]",
            log: .appScreens,
            type: .error,
            session.templateKey
        )
        recover(session: session, reason: "deferred recovery on appear")
    }

    /// On pop: an ephemeral (detail→detail) session is torn down; a warm template
    /// session stays live with its web view warm, only leaving the stack so the
    /// next navigation to its template can reuse it.
    private func handlePop(of session: AppScreenSession) {
        // Cancel this session's in-flight pipeline before it leaves the stack. An
        // ephemeral is about to be torn down; a warm session becomes reusable, and
        // its next navigation shares the same web view — a late `.json`/`show` from
        // the popped navigation must not morph over the record that reuse renders.
        session.pipelineTask?.cancel()
        session.pipelineTask = nil
        if session.isEphemeral {
            os_log(
                "popped ephemeral session [%{public}@] — tearing down",
                log: .appScreens,
                type: .info,
                session.templateKey
            )
            teardown(session)
            ephemeralSessions.removeAll { $0 === session }
        } else {
            session.isOnStack = false
            os_log(
                "popped template session [%{public}@] — kept warm (off stack)",
                log: .appScreens,
                type: .info,
                session.templateKey
            )
        }
    }

    /// The production dismantle-driven pop for `.pushed` screens (see
    /// ``AppScreensPageRepresentable/dismantleUIViewController(_:coordinator:)``): resolves
    /// the session hosted by `host`, runs the existing keep-warm-vs-teardown decision via
    /// ``handlePop(of:)``, and de-registers the session from ``sessionsByToken`` so a
    /// popped-but-kept-warm session is no longer considered owned by the flow that pushed it.
    /// A resolution miss (host not found among root/warm/ephemeral sessions) is a no-op —
    /// this can happen for a plain (non-App-Screen) placeholder host.
    package func handlePop(forHostedBy host: UIViewController) {
        guard let appScreenHost = host as? AppScreensPageViewController,
            let session = liveSession(hostedBy: appScreenHost)
        else {
            return
        }
        handlePop(of: session)
        if let token = session.token {
            sessionsByToken[token]?[ObjectIdentifier(session)] = nil
        }
    }

    /// Tears down a root (entry-point) session whose owning presentation has ended.
    /// The sole root-release path (used by ``release(_:)``): cancels the root's
    /// in-flight pipeline, drops it from ``rootSessions``, and either demotes it to
    /// an off-stack **reusable** warm session — mirroring Android's warm master pool
    /// — when its keyed slot is free and the runtime is healthy (`state == .ready`),
    /// so the next presentation of the template takes the warm-reuse path; or tears
    /// it down (releasing the web view) otherwise.
    ///
    /// Idempotent: a second call (or a call for an already-released session) finds
    /// nothing in ``rootSessions`` to remove and simply re-runs the demote/teardown
    /// decision harmlessly.
    private func releaseRootSession(_ session: AppScreenSession) {
        // Cancel the root's in-flight pipeline and drop it from root tracking so no
        // late await acts on it and a second release is a no-op.
        session.pipelineTask?.cancel()
        session.pipelineTask = nil
        session.isOnStack = false
        rootSessions.removeAll { $0 === session }

        // Prefer demoting to the warm reusable pool (Android parity: keep the master
        // warm for the next presentation) when the slot is free and the runtime is
        // healthy; otherwise release the web view outright.
        if sessions[session.templateKey] == nil, session.state == .ready {
            sessions[session.templateKey] = session
            os_log(
                "root presentation ended [%{public}@] — demoted to warm pool (off stack)",
                log: .appScreens,
                type: .info,
                session.templateKey
            )
        } else {
            teardown(session)
            os_log(
                "root presentation ended [%{public}@] — torn down (slot occupied or unhealthy)",
                log: .appScreens,
                type: .info,
                session.templateKey
            )
        }
    }

    /// Tears down every live session a flow owns. There is no UIKit navigation
    /// controller to walk, so ``sessionsByToken`` and ``pendingNavigations`` are the
    /// only source of truth for what the flow still owns. Called from
    /// `AppScreensTokenBox`'s deinit-driven teardown on Hub home disappear/URL-change
    /// or standalone dismissal.
    ///
    /// The ordering is load-bearing: releasing the root first (its
    /// `releaseRootSession` may demote it into — or otherwise mutate — the shared
    /// `sessions`/`rootSessions` pools) before the flow's pushed details and
    /// unclaimed pending sessions are safely down would let a premature root release
    /// interleave with, and corrupt, state those two cohorts still depend on. So the
    /// root always goes last:
    /// 1. Snapshot the flow's owned sessions and identify which one (if any) is the
    ///    root — the owned session currently present in ``rootSessions``.
    /// 2. Tear down every non-root (`.pushed`) owned session first, via
    ///    ``handlePop(of:)`` (mirrors what popping each one individually would do).
    /// 3. Tear down sessions still sitting in the flow's unclaimed
    ///    ``AppScreenPendingNavigationStore`` records — enqueued but never rendered —
    ///    via ``teardown(_:)``.
    /// 4. Release the root last, via ``releaseRootSession(_:)``.
    /// 5. Purge ``sessionsByToken[flow]`` (the pending records are already drained by
    ///    step 3).
    ///
    /// Idempotent: a second call for the same flow finds no owned sessions and no
    /// unclaimed pending records, and no-ops.
    package func release(_ token: AppScreensToken) {
        let owned: [AppScreenSession] = sessionsByToken[token].map { Array($0.values) } ?? []
        let root = owned.first { session in rootSessions.contains { $0 === session } }
        let pushedDetails = owned.filter { $0 !== root }

        for session in pushedDetails {
            handlePop(of: session)
        }

        for record in pendingNavigations.drain(in: token) {
            teardown(record.session)
        }

        if let root {
            releaseRootSession(root)
        }

        sessionsByToken[token] = nil
        openHandlersByToken[token] = nil
        lastViewedSessionIdentityByFlow[token] = nil

        // Analytics: the reveal a dismissed sheet causes is reported from the sheet's own
        // `onDismiss` — ``sheetFlowDidDismiss(_:)``, which UIKit runs after the dismissal
        // transition has finished. This is the fallback for a sheet flow torn down
        // WITHOUT one (the presenting screen itself going away, say), where the ticket is
        // still unredeemed. Deferred a turn because teardown can land while the
        // presentation is still unwinding; the reveal check reads the settled hierarchy
        // and reports nothing if it is not, so this path can only miss a view, never
        // invent one.
        guard presentingFlowBySheetFlow[token] != nil else {
            return
        }
        // Retained rather than fire-and-forget, so the hop is something a caller can
        // await: ``drainPendingDismissalFallbacks()`` is what the tests synchronise on,
        // instead of spinning the run loop and hoping the main-actor continuation was
        // drained inside the window. Nothing in production awaits it.
        let fallback = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            self.pendingDismissalFallbacks[token] = nil
            self.sheetFlowDidDismiss(token)
        }
        // Safe against the task clearing its own entry first: this method and the task
        // body are both main-actor isolated and nothing suspends in between, so the
        // assignment always lands before the body runs.
        pendingDismissalFallbacks[token] = fallback
    }

    /// Awaits every deferred ``release(_:)`` dismissal fallback currently in flight.
    ///
    /// A test seam, and the only reason the fallback task is retained: the hop is a
    /// main-actor continuation, which a run-loop spin can only *probably* drain — as a
    /// flaky `testReleaseWithoutTheDismissalHookStillReportsTheReveal` demonstrated.
    /// Awaiting the task itself is the guarantee. Production never calls this; there
    /// the fallback is fire-and-forget by design.
    package func drainPendingDismissalFallbacks() async {
        // Snapshot: each task clears its own entry as it runs.
        for task in Array(pendingDismissalFallbacks.values) {
            await task.value
        }
    }

    /// The sheet-dismissal reveal hook, called from the presenting screen's
    /// `.sheet(item:onDismiss:)`. That callback is the one moment guaranteed to be
    /// *after* the dismissal transition completed, so the presenting host's
    /// `presentedViewController` is already nil and the exposed screen reads `.visible`
    /// rather than `.occluded` — which the flow's own teardown, the only previous
    /// signal, could not promise: it is driven by SwiftUI releasing the sheet's
    /// `AppScreensTokenBox`, and a `Task { @MainActor }` hop from there buys one
    /// main-actor turn, not the length of an animation.
    ///
    /// ``presentingFlowBySheetFlow`` is a one-shot ticket: whichever arrives first —
    /// this hook or ``release(_:)``'s fallback — redeems it and the other no-ops. That,
    /// with ``trackScreenExposedByDismissal(inFlowOf:)``'s own last-viewed identity
    /// check, is what keeps one dismissal worth exactly one "App Screen Viewed".
    func sheetFlowDidDismiss(_ sheetFlow: AppScreensToken) {
        guard let presentingFlow = presentingFlowBySheetFlow.removeValue(forKey: sheetFlow) else {
            return
        }
        trackScreenExposedByDismissal(inFlowOf: presentingFlow)
    }

    // MARK: - Sheet presentation

    /// Finds the live root/warm/ephemeral session whose host is `host`, used by
    /// ``handlePop(forHostedBy:)`` to resolve the SwiftUI dismantle-driven pop back
    /// to its owning session.
    private func liveSession(hostedBy host: AppScreensPageViewController) -> AppScreenSession? {
        if let root = rootSessions.first(where: { $0.hostViewController === host }) {
            return root
        }
        if let warm = sessions.values.first(where: { $0.hostViewController === host }) {
            return warm
        }
        return ephemeralSessions.first(where: { $0.hostViewController === host })
    }

    /// Fully releases a session's web view: removes the message handler (so the
    /// content controller stops retaining the proxy), detaches the nav delegate,
    /// removes the view, and marks the session dead.
    func teardown(_ session: AppScreenSession) {
        session.state = .dead
        // Stop any in-flight load/navigation/recovery pipeline before the web view
        // is released so a late await can't act on a dead session.
        session.pipelineTask?.cancel()
        session.pipelineTask = nil
        // Release the off-screen prewarm window first (if the session was still
        // booting there) so it doesn't outlive its web view.
        detachFromOffscreenWindow(session)
        if let webView = session.webView {
            webView.configuration.userContentController.removeScriptMessageHandler(
                forName: appScreensMessageHandlerName
            )
            webView.navigationDelegate = nil
            webView.removeFromSuperview()
        }
        session.webView = nil
        session.hostViewController = nil
    }

    /// Milliseconds elapsed since `start`, for the tap→reveal telemetry.
    nonisolated static func elapsedMs(since start: DispatchTime) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
    }

    // MARK: - Web view factory

    /// Builds a warm App Screens web view. The web view is opaque and paints its own
    /// page background: the App Screens runtime mirrors the screen's declared color
    /// (from the `{% screen %}` root Tailwind class) onto `html`/`body` and a
    /// `<meta name="theme-color">`, so an opaque web view renders the right backdrop
    /// and WebKit derives the elastic-scroll underpage color from it. The surfaces are
    /// seeded here with the adaptive system background so there is never an unstyled
    /// frame, then ``AppScreenSession`` keeps them aligned with `themeColor`. The
    /// `roverAppScreens` handler is attached through the weak proxy so the content
    /// controller never retains the navigator.
    func makeWebView(screenBackground: UIColor) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.userContentController.add(messageProxy, name: appScreensMessageHandlerName)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = true
        webView.backgroundColor = screenBackground
        webView.scrollView.backgroundColor = screenBackground
        webView.underPageBackgroundColor = screenBackground
        // Pages own their safe-area insets via `env(safe-area-inset-*)` with
        // `viewport-fit=cover` (the document contract), so UIKit must not add its
        // own: `.never` leaves the scroll content un-inset and edge-to-edge, and the
        // page's own padding places content below the status bar / floating bar and
        // above the home indicator. `.always` would double-inset (native inset plus
        // the page's `env()` padding), pushing content too far down.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = navigationDelegate
        #if DEBUG
            webView.isInspectable = true
        #endif
        return webView
    }

    /// The fallback screen background: applied before any content loads, and the
    /// resting value whenever a page declares no background of its own (no
    /// `theme-color`). Uses the adaptive system background so the no-flash behavior
    /// and the unset-screen appearance both hold in light and dark.
    static var defaultScreenBackground: UIColor {
        .systemBackground
    }

}

// MARK: - WKScriptMessageHandler

extension AppScreensDriver: WKScriptMessageHandler {
    /// Delivered on the main thread by WebKit. Decodes defensively and routes to
    /// the owning session. `nonisolated` so it satisfies the non-isolated protocol
    /// requirement; it immediately hops to the main actor it is already running on.
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == appScreensMessageHandlerName else {
            return
        }
        guard let parsed = AppScreenMessage(body: message.body) else {
            os_log(
                "Ignoring unknown App Screens message: %{public}@",
                log: .appScreens,
                type: .debug,
                String(describing: message.body)
            )
            return
        }

        let webView = message.webView
        // `frameInfo` is main-thread state, like `webView` above; this handler is
        // already delivered on the main thread (the `nonisolated` only satisfies the
        // protocol requirement). Carry it into `handle` so the message can be
        // authenticated against the owning session's origin before it is routed.
        let frameInfo = message.frameInfo
        MainActor.assumeIsolated {
            self.handle(parsed, from: webView, frameInfo: frameInfo)
        }
    }
}
