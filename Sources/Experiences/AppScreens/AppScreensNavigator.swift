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
import SafariServices
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
final class AppScreensNavigator: NSObject {
    let httpClient: HTTPClient
    private let configManager: ConfigManager

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
    /// (``releaseRootPresentation(_:)``) may be moved *into* this pool as an
    /// off-stack reusable session when its slot is free.
    var sessions: [String: AppScreenSession] = [:]

    /// The live root (entry-point) sessions, one per active
    /// ``ExperienceViewController`` App Screens presentation. Tracked as an
    /// independent list rather than in ``sessions`` because the keyed pool holds a
    /// single warm session per template: two scenes (or two presentations) showing
    /// the same `/a/home` must each keep their own live root, and neither may evict
    /// the other from ``liveSession(for:)``. A root leaves this list only when its
    /// owning presentation ends (``releaseRootPresentation(_:)``), which either
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

    #if DEBUG
        /// TEST HOOK (DEBUG only): when the host process is launched with
        /// `-appScreensDisablePrewarm`, `links`-hint prewarming is skipped. Lets a
        /// UI test exercise the deterministic cold → optimistic → warm-reuse paths without
        /// a prewarm racing (and satisfying) the first navigation. No effect in
        /// release builds or normal use.
        let prewarmDisabledForTesting =
            ProcessInfo.processInfo.arguments.contains("-appScreensDisablePrewarm")
    #endif

    /// Owns the `interactivePopGestureRecognizer` delegate for the App Screens
    /// navigation controller so the edge-swipe-to-pop begins whenever the stack has
    /// something to pop and no transition is in flight — the system delegate has
    /// been observed leaving the gesture inert in hybrid (web content + per-item
    /// bar appearance) stacks. Installed once per navigation controller.
    private let popGestureAssist = PopGestureAssist()

    /// The App Screens sheets the navigator has presented, tracked so a navigation
    /// reset can find and dismiss the ones a given child navigation controller
    /// opened. A sheet presents `.pageSheet` from the window's presentation context,
    /// so the child nav's `presentedViewController` is `nil` while a sheet is up —
    /// there is no other way to reach them. Both references are weak, so a sheet
    /// dismissed through the normal swipe/xmark path deallocates and its record
    /// compacts away. `origin` is the navigation controller the sheet was presented
    /// from — the child nav for a top-level sheet, or the outer sheet's own nav for a
    /// sheet-from-sheet, which gives `popToRoot` transitive reach across nesting.
    private var presentedSheets: [PresentedSheetRecord] = []

    /// A weak (sheet, origin) pair retained in `presentedSheets`.
    private struct PresentedSheetRecord {
        weak var sheet: UINavigationController?
        weak var origin: UINavigationController?
    }

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

    init(httpClient: HTTPClient, configManager: ConfigManager, associatedDomains: [String]) {
        self.httpClient = httpClient
        self.configManager = configManager
        self.associatedDomains = Set(associatedDomains.map { $0.lowercased() })

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

    /// Vends the root host view controller for an App Screens entry URL. The
    /// caller (`ExperienceViewController`) wraps it in a child
    /// `UINavigationController`; this navigator pushes subsequent screens onto
    /// `rootHost.navigationController`.
    func makeRootViewController(
        for url: URL,
        onDismissButtonPressed: (() -> Void)? = nil,
        onOpenURL: ((URL) -> Void)? = nil
    ) -> UIViewController {
        os_log(
            "Creating App Screens root host for %{public}@",
            log: .appScreens,
            type: .info,
            url.absoluteString
        )

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
        // presentation releases it via `releaseRootPresentation(_:)`.
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

        let host = AppScreenHostViewController(
            webView: webView,
            screenBackground: screenBackground,
            showsSkeleton: true
        )
        session.hostViewController = host
        // The root can be occluded by a pushed detail; wire its visibility callback
        // so a recovery deferred while occluded fires when the user pops back to it.
        // `onPopped` never fires for the root under normal dismissal (it is dismissed
        // with its containing navigation controller, which removes no view controller
        // from a stack) — its teardown is driven by `releaseRootPresentation(_:)`,
        // invoked by the owning `ExperienceViewController` when the presentation ends.
        wireHostCallbacks(to: host, for: session)

        runMasterPipeline(entryURL: url, session: session, host: host)
        return host
    }

    /// Updates the live root session's `onDismissButtonPressed` in place, keyed by its
    /// root host. A Hub only learns it is presented modally *after* its root loads
    /// (the hosting relationship is established at `HubHostingController.viewWillAppear`),
    /// so the handler that drives the `openURL { dismiss: true }` teardown flips from
    /// `nil` to a real closure then; this lets that flip reach the already-created root
    /// session without recreating the session or its web view. Idempotent / no-op when
    /// `rootHost` owns no live root session (a non-App-Screens experience, or one
    /// already released).
    func setRootDismissHandler(for rootHost: UIViewController, onDismissButtonPressed: (() -> Void)?) {
        guard let session = rootSessions.first(where: { $0.hostViewController === rootHost }) else {
            return
        }
        session.onDismissButtonPressed = onDismissButtonPressed
    }

    // MARK: - Master pipeline

    /// Cold-loads the master: fetch the anonymous document → `loadHTMLString` →
    /// await the runtime `loaded` message → `show()` → reveal. Every await is
    /// time-bounded; any failure surfaces a retry affordance instead of an
    /// infinite skeleton. (Full recover-and-replay lives in the liveness path.)
    private func runMasterPipeline(
        entryURL: URL,
        session: AppScreenSession,
        host: AppScreenHostViewController
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

    // MARK: - Navigation

    /// Handles a `navigate` bridge message: resolves the target, selects/creates a
    /// session, pushes a host immediately (the transition covers the load), arms
    /// the edge-swipe assist, and runs the bounded pipeline.
    private func navigate(
        href: String,
        optimisticDataJSON: String?,
        transition: AppScreenTransition?,
        from source: AppScreenSession
    ) {
        let tapTime = DispatchTime.now()

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

        guard let webView = session.webView else {
            return
        }

        // A claimed prewarmed session's web view is currently parented in its
        // off-screen boot window; release it so the push can reparent the view into
        // the host. No-op for master/cold/ephemeral sessions.
        detachFromOffscreenWindow(session)

        // A reused web view already shows real (previous) content that the next
        // hydrate morphs in place, so it skips the skeleton; a cold/ephemeral load
        // shows the skeleton behind its 300 ms grace.
        let host = AppScreenHostViewController(
            webView: webView,
            screenBackground: Self.defaultScreenBackground,
            showsSkeleton: isColdLoad
        )
        session.hostViewController = host
        wireHostCallbacks(to: host, for: session)

        // An absent transition (or an unrecognized value the bridge already mapped
        // to `nil`) defaults to push; only an explicit "sheet" presents modally.
        switch transition ?? .push {
        case .push:
            guard let navigationController = source.hostViewController?.navigationController else {
                os_log(
                    "navigate has no navigation controller to push onto [%{public}@]",
                    log: .appScreens,
                    type: .error,
                    templateKey
                )
                return
            }
            // Push immediately: the push transition covers the async load underneath.
            session.isOnStack = true
            navigationController.pushViewController(host, animated: true)
            armPopGesture(on: navigationController)
        case .sheet:
            guard let sourceHost = source.hostViewController else {
                os_log(
                    "navigate has no source host to present a sheet from [%{public}@]",
                    log: .appScreens,
                    type: .error,
                    templateKey
                )
                return
            }
            // On the stack for its whole presentation, wrapped in its own nav
            // controller so in-sheet link taps push within the sheet.
            session.isOnStack = true
            presentSheet(host: host, from: sourceHost)
        }

        runNavigatePipeline(
            resolvedURL: resolvedURL,
            optimisticDataJSON: optimisticDataJSON,
            session: session,
            host: host,
            isColdLoad: isColdLoad,
            tapTime: tapTime
        )
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
        host: AppScreenHostViewController,
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

    /// Finds the root session that ultimately owns `source`, walking out from a
    /// pushed detail or a sheet-hosted session back to the root of its presentation.
    ///
    /// A root session matches directly. A pushed detail shares its root's navigation
    /// controller, so its root is the session hosting that nav controller's first
    /// view controller. A sheet-hosted session's nav controller is not the root's, so
    /// the walk follows each sheet record's `origin` back through however many nested
    /// sheets until it lands on a nav controller no sheet was presented from — the
    /// root's — then resolves the root by that nav controller's first view controller.
    /// Returns `nil` when no root can be reached (e.g. a torn-down host).
    private func rootSession(owning source: AppScreenSession) -> AppScreenSession? {
        if rootSessions.contains(where: { $0 === source }) {
            return source
        }
        guard var nav = source.hostViewController?.navigationController else {
            return nil
        }
        // Climb out of any sheet nesting: each sheet's nav controller was presented
        // from its `origin`, so follow origins until the current nav controller is one
        // no sheet record was presented from — the root's own navigation controller.
        while let origin = presentedSheets.first(where: { $0.sheet === nav })?.origin {
            nav = origin
        }
        return rootSessions.first { $0.hostViewController === nav.viewControllers.first }
    }

    /// Handles an `openURL` bridge message: interprets the href with browser
    /// `<a href>` semantics (WHATWG resolution against the posting document's URL),
    /// hands it to the root's host opener (or the OS), and — when `dismiss` is set —
    /// tears down the enclosing Experience presentation via the host dismissal.
    private func openExternalURL(href: String, dismiss: Bool, from source: AppScreenSession) {
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

        guard let root = rootSession(owning: source) else {
            os_log(
                "openURL found no root session for [%{public}@] — dropping %{private}@",
                log: .appScreens,
                type: .error,
                source.templateKey,
                url.absoluteString
            )
            return
        }

        // The URL hand-off (host override, or the OS as the default opener), factored
        // out so it can run either immediately or deferred until the enclosing
        // Experience has finished tearing down.
        let openTarget = {
            if let handler = root.onOpenURL {
                handler(url)
            } else {
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
        }

        // Without a dismiss, or with no host dismiss registered (e.g. an embedded Hub),
        // nothing tears down — open immediately.
        guard dismiss, let onDismiss = root.onDismissButtonPressed else {
            if dismiss {
                os_log(
                    "openURL requested dismiss but no host dismiss is registered; leaving presentation up",
                    log: .appScreens,
                    type: .info
                )
            }
            openTarget()
            return
        }

        // Dismiss-THEN-open, sequenced on the dismissal transition (parity with the V2
        // modern-experiences renderer — see `ExperienceAction.handle` / the
        // `performDismissExperience` helper in `Action+handler.swift`, which opens the URL
        // inside the dismissal completion when `dismissExperience` is set). Opening first
        // races the OS re-delivering a Rover deep-link target back into the app:
        // `PresentViewAction` resolves a presenter by walking to the top-most presented
        // view controller — which is still this disappearing host — so UIKit drops the
        // presentation ("view is not in the window hierarchy") and the target is silently
        // lost. Waiting on the dismissal completion guarantees the presenter has settled
        // on the revealed ancestor before we open. Reordering alone is not enough: both
        // the dismissal and `PresentViewAction` are async, so an immediate open still
        // lands mid-animation.
        let dismissingHost = root.hostViewController
        onDismiss()
        if let coordinator = dismissingHost?.transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { _ in
                openTarget()
            }
        } else {
            // No animated dismissal transition in flight (a non-animated teardown, or a
            // host that resolved its dismissal synchronously) — nothing to wait on.
            openTarget()
        }
    }

    /// Handles a `presentWebsite` bridge message: interprets the href with browser
    /// `<a href>` semantics (WHATWG resolution against the posting document's URL),
    /// coerces it to a Safari-presentable http(s) URL, and presents it in an in-app
    /// `SFSafariViewController` from the topmost controller above the source host.
    /// Never overridable by the embedding app.
    private func presentWebsite(href: String, from source: AppScreenSession) {
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

        guard let sourceHost = source.hostViewController else {
            os_log(
                "presentWebsite has no source host to present from [%{public}@]",
                log: .appScreens,
                type: .error,
                source.templateKey
            )
            return
        }

        let safari = SFSafariViewController(url: presentableURL)
        Self.topmostPresentedViewController(from: sourceHost).present(safari, animated: true)
    }

    // MARK: - Pop semantics

    /// Wires a host's lifecycle callbacks to the navigator: `onPopped` for pop
    /// teardown, and `onBecameVisible` for firing a deferred recovery once an
    /// occluded session's screen is on top again.
    private func wireHostCallbacks(to host: AppScreenHostViewController, for session: AppScreenSession) {
        host.onPopped = { [weak self, weak session] in
            guard let self, let session else {
                return
            }
            self.handlePop(of: session)
        }
        host.onBecameVisible = { [weak self, weak session] in
            guard let self, let session else {
                return
            }
            self.hostBecameVisible(session)
        }
    }

    /// Called from the host's `viewDidAppear`. Fires a recovery that was deferred
    /// while the session was occluded (its WebContent process had died off-screen,
    /// where the runtime cannot boot). No-op on ordinary appearances.
    private func hostBecameVisible(_ session: AppScreenSession) {
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

    /// Resets an App Screens child navigation stack back to its root host, releasing
    /// every pushed session (and dismissing any sheets the stack presented) exactly
    /// as a pop would. Used when the Hub performs a coordinator-driven navigation
    /// while a detail — and possibly a sheet — is up, so backing out never reveals a
    /// stale pushed detail.
    ///
    /// `popToRootViewController` alone is not enough: ``AppScreenHostViewController``
    /// fires `onPopped` from `viewDidDisappear` + `isMovingFromParent`, which never
    /// runs for the *intermediate* hosts a bulk pop-to-root removes (only the
    /// formerly-visible top disappears). Those sessions would leak stuck
    /// `isOnStack = true`, which corrupts ``selectSession(hasWarmReady:isOnStack:)``
    /// — every future navigation to their template would be forced ephemeral. So the
    /// reset walks the popped hosts explicitly and releases each via `handlePop`. The
    /// top host may still fire its own `onPopped`; `handlePop` is idempotent per
    /// session, so the double-fire is harmless.
    func popToRoot(in navigationController: UINavigationController) {
        // Dismiss any sheets this stack presented first. A sheet's child nav has no
        // `presentedViewController` of its own here (it was presented from the
        // window), so the tracked set is the only handle. Dismiss the outermost
        // (first-presented) so UIKit tears down everything stacked above it, then
        // release each set member's sessions (idempotent) and purge them.
        let sheets = trackedSheets(originatingFrom: navigationController)
        if let outermost = sheets.first {
            outermost.dismiss(animated: false)
        }
        for sheet in sheets {
            handleSheetDismissed(sheet)
        }
        presentedSheets.removeAll { record in
            record.sheet == nil || sheets.contains { $0 === record.sheet }
        }

        let popped = navigationController.popToRootViewController(animated: false) ?? []
        for case let host as AppScreenHostViewController in popped {
            guard let session = liveSession(hostedBy: host) else {
                continue
            }
            handlePop(of: session)
        }

        os_log(
            "navigation reset — popped %d screen(s), dismissed %d sheet(s)",
            log: .appScreens,
            type: .info,
            popped.count,
            sheets.count
        )
    }

    /// Tears down a root (entry-point) session whose owning presentation has ended.
    /// The owning ``ExperienceViewController`` calls this from its `deinit` because
    /// a root is dismissed *with* its containing navigation controller — no view
    /// controller is popped off a stack, so ``AppScreenHostViewController/onPopped``
    /// never fires for it. Without this hook the root would remain falsely on-stack
    /// in the navigator forever, retaining its `WKWebView` and continuing to accept
    /// bridge/prewarm activity with no host.
    ///
    /// The release: (1) runs the ``popToRoot(in:)`` cleanup for the root's
    /// navigation controller so any pushed details + presented sheets release exactly
    /// as a pop would (that bulk removal fires no `onPopped` either); (2) cancels the
    /// root's in-flight pipeline and drops it from ``rootSessions``; then (3) either
    /// demotes it to an off-stack **reusable** warm session — mirroring Android's warm
    /// master pool — when its keyed slot is free and the runtime is healthy
    /// (`state == .ready`), so the next presentation of the template takes the
    /// warm-reuse path; or tears it down (releasing the web view) otherwise.
    ///
    /// Idempotent: a second call (or a call for a non-root host) finds nothing in
    /// ``rootSessions`` and no-ops.
    func releaseRootPresentation(_ rootHost: UIViewController) {
        guard let session = rootSessions.first(where: { $0.hostViewController === rootHost }) else {
            // Already released, or this host never owned a root session.
            return
        }

        // Reset the child navigation stack: release every pushed detail and dismiss
        // any sheets it presented, exactly as a pop would (idempotent per session).
        // The root host sits at the stack's root, so `popToRoot` never touches the
        // root session itself — that is handled below.
        if let navigationController = rootHost.navigationController {
            popToRoot(in: navigationController)
        }

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

    /// The transitive set of tracked live sheets originating from
    /// `navigationController`: sheets presented directly from it, plus sheets
    /// presented from within one of those (whose `origin` is a sheet already in the
    /// set). Records are appended in presentation order, so a single forward pass
    /// reaches every descendant, and the result is ordered first-presented →
    /// last so the caller can dismiss the outermost. Compacts dead weak entries.
    private func trackedSheets(
        originatingFrom navigationController: UINavigationController
    )
        -> [UINavigationController]
    {
        presentedSheets.removeAll { $0.sheet == nil }

        var origins: Set<ObjectIdentifier> = [ObjectIdentifier(navigationController)]
        var result: [UINavigationController] = []
        for record in presentedSheets {
            guard
                let sheet = record.sheet,
                let origin = record.origin,
                origins.contains(ObjectIdentifier(origin))
            else {
                continue
            }
            result.append(sheet)
            origins.insert(ObjectIdentifier(sheet))
        }
        return result
    }

    // MARK: - Sheet presentation

    /// Presents a `navigate` target as a page sheet: the new host wrapped in a
    /// fresh `UINavigationController` so in-sheet link taps push within the sheet
    /// (their source session resolves `navigationController` to this one). The sheet
    /// root carries an xmark close item mirroring the modal entry point. Both a
    /// swipe-down (via `UIAdaptivePresentationControllerDelegate`) and the xmark
    /// release the sheet's sessions exactly like a pop.
    private func presentSheet(host: AppScreenHostViewController, from sourceHost: AppScreenHostViewController) {
        let sheetNavigationController = UINavigationController(rootViewController: host)
        sheetNavigationController.modalPresentationStyle = .pageSheet

        // A modal presentation hangs off the window's presentation context, outside the
        // presenting screen's hierarchy, so the config colorScheme override the Hub
        // applies via `.colorScheme()` (HubContentView) never reaches it — the sheet's
        // WKWebView would resolve `prefers-color-scheme` from the device appearance
        // instead. Inherit the PRESENTER's resolved appearance rather than reading the
        // config directly: the override is a Hub-only policy, and the source host's
        // traits already encode it — a hub-embedded host carries the override, while a
        // standalone full-screen host (which deliberately does not follow the override)
        // carries the device appearance. The trait registration keeps the sheet in
        // lockstep with the presenter while it is up: a device flip under AUTO, or a
        // live config flip re-theming the Hub, propagates instead of leaving the sheet
        // pinned to its present-time appearance.
        sheetNavigationController.overrideUserInterfaceStyle =
            sourceHost.traitCollection.userInterfaceStyle
        sourceHost.registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
            [weak sheetNavigationController] (host: AppScreenHostViewController, _) in
            sheetNavigationController?.overrideUserInterfaceStyle =
                host.traitCollection.userInterfaceStyle
        }

        // Track the sheet against its origin so a navigation reset can dismiss it.
        // For a sheet-from-sheet, the source host's navigation controller IS the
        // outer sheet's nav, which chains the reset transitively across nesting.
        recordPresentedSheet(sheetNavigationController, origin: sourceHost.navigationController)

        // Programmatic `dismiss()` does not fire `presentationControllerDidDismiss`,
        // so the xmark path releases the sheet's sessions itself.
        host.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            primaryAction: UIAction { [weak self, weak sheetNavigationController] _ in
                guard let sheetNavigationController else {
                    return
                }
                sheetNavigationController.dismiss(animated: true)
                self?.handleSheetDismissed(sheetNavigationController)
            }
        )

        // A user swipe-down dismissal routes through the adaptive presentation
        // delegate; wire it so those sessions release the same way.
        sheetNavigationController.presentationController?.delegate = self

        // Present from the frontmost presented controller so a sheet opened from
        // within an existing sheet stacks correctly.
        Self.topmostPresentedViewController(from: sourceHost)
            .present(sheetNavigationController, animated: true)
    }

    /// Releases every App Screens session hosted in a dismissed sheet's navigation
    /// stack, exactly as a pop would: ephemeral (detail→detail) sessions are torn
    /// down; warm template sessions leave the stack but stay warm for reuse. Safe to
    /// call more than once — `handlePop` is idempotent per session.
    private func handleSheetDismissed(_ sheetNavigationController: UINavigationController) {
        for case let host as AppScreenHostViewController in sheetNavigationController.viewControllers {
            guard let session = liveSession(hostedBy: host) else {
                continue
            }
            handlePop(of: session)
        }
        // Purge this sheet's tracking record (and any dead weak entries).
        presentedSheets.removeAll { $0.sheet == nil || $0.sheet === sheetNavigationController }
    }

    /// Records a presented sheet against the navigation controller it was presented
    /// from, compacting any dead weak entries first.
    private func recordPresentedSheet(_ sheet: UINavigationController, origin: UINavigationController?) {
        presentedSheets.removeAll { $0.sheet == nil }
        presentedSheets.append(PresentedSheetRecord(sheet: sheet, origin: origin))
    }

    /// Finds the live root/warm/ephemeral session whose host is `host` (sheet
    /// dismissal walks the sheet's view controllers back to their sessions).
    private func liveSession(hostedBy host: AppScreenHostViewController) -> AppScreenSession? {
        if let root = rootSessions.first(where: { $0.hostViewController === host }) {
            return root
        }
        if let warm = sessions.values.first(where: { $0.hostViewController === host }) {
            return warm
        }
        return ephemeralSessions.first(where: { $0.hostViewController === host })
    }

    /// Walks the modal presentation chain to the frontmost controller not currently
    /// being dismissed, so a new sheet presents above any sheet already on screen.
    private static func topmostPresentedViewController(from viewController: UIViewController) -> UIViewController {
        var top = viewController
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
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

    /// Installs the edge-swipe-to-pop assist on a navigation controller (idempotent
    /// per controller).
    private func armPopGesture(on navigationController: UINavigationController) {
        guard let popGesture = navigationController.interactivePopGestureRecognizer else {
            os_log("interactive pop unavailable on this navigation controller", log: .appScreens, type: .error)
            return
        }
        popGestureAssist.navigationController = navigationController
        if popGesture.delegate !== popGestureAssist {
            popGesture.delegate = popGestureAssist
        }
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

// MARK: - UIAdaptivePresentationControllerDelegate

extension AppScreensNavigator: UIAdaptivePresentationControllerDelegate {
    /// Fired when the user swipe-dismisses a presented sheet. Releases the sheet's
    /// sessions like a pop (the xmark path handles the programmatic-dismiss case,
    /// which does not call this).
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard
            let sheetNavigationController = presentationController.presentedViewController
                as? UINavigationController
        else {
            return
        }
        handleSheetDismissed(sheetNavigationController)
    }
}

// MARK: - WKScriptMessageHandler

extension AppScreensNavigator: WKScriptMessageHandler {
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
