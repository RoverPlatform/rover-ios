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
final class AppScreensNavigator: NSObject {
    let httpClient: HTTPClient
    private let configManager: ConfigManager

    /// Live warm sessions keyed by template path (master + reusable templates).
    var sessions: [String: AppScreenSession] = [:]

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

    /// Template paths reserved by prewarm — either queued or booting — so a repeated
    /// `links` hint coalesces and never schedules duplicate work. A path is reserved
    /// at schedule time and released when its prewarm finishes (success or failure)
    /// or the scheduler is cancelled.
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

    /// The anonymous document channel's own `URLSession` + `URLCache`. Kept
    /// separate from `HTTPClient` so the document fetch can never pick up an
    /// account token, `Authorization` header, or identifier query items, and so
    /// document caching (`max-age`/`ETag`) is isolated from all other traffic.
    let documentSession: URLSession

    /// Bounds for the master pipeline's awaits (seconds), so a stalled load can
    /// never present an infinite skeleton.
    static let documentTimeout: Double = 12
    static let loadedTimeout: Double = 10
    static let showTimeout: Double = 12
    private static let jsonTimeout: Double = 12

    init(httpClient: HTTPClient, configManager: ConfigManager) {
        self.httpClient = httpClient
        self.configManager = configManager

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
        self.documentSession = URLSession(configuration: configuration)

        super.init()
        messageProxy.delegate = self
        navigationDelegate.navigator = self
    }

    deinit {
        // Cheap guard for the singleton ever being torn down: stop the stagger loop
        // and any in-flight prewarm workers. They also hold weak references and
        // unwind on their own once `self` is gone.
        prewarmSchedulerTask?.cancel()
        for worker in prewarmWorkerTasks {
            worker.cancel()
        }
    }

    /// Vends the root host view controller for an App Screens entry URL. The
    /// caller (`ExperienceViewController`) wraps it in a child
    /// `UINavigationController`; this navigator pushes subsequent screens onto
    /// `rootHost.navigationController`.
    func makeRootViewController(for url: URL) -> UIViewController {
        os_log(
            "Creating App Screens root host for %{public}@",
            log: .appScreens,
            type: .info,
            url.absoluteString
        )

        let templatePath = Self.templatePath(from: url) ?? url.path
        let screenBackground = Self.defaultScreenBackground
        let webView = makeWebView(screenBackground: screenBackground)

        let session = AppScreenSession(
            templatePath: templatePath,
            webView: webView,
            state: .loadingDocument
        )
        // The master is the root of the stack for its whole lifetime.
        session.documentURL = url
        session.isOnStack = true
        sessions[templatePath] = session

        let host = AppScreenHostViewController(
            webView: webView,
            screenBackground: screenBackground,
            showsSkeleton: true
        )
        session.hostViewController = host
        // The master can be occluded by a pushed detail; wire its visibility
        // callback so a recovery deferred while occluded fires when the user pops
        // back to it. `onPopped` never fires for the root under normal dismissal.
        wireHostCallbacks(to: host, for: session)

        runMasterPipeline(entryURL: url, session: session, host: host)
        return host
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

        Task { [weak self, weak host] in
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
                    session.templatePath,
                    etag ?? "(none)",
                    Self.effectiveScope(dataScope).rawValue
                )

                let effectiveScope = Self.effectiveScope(session.dataScope)
                async let jsonResult = withTimeout(seconds: Self.jsonTimeout) {
                    try await self.fetchScreenData(for: entryURL, scope: effectiveScope)
                }

                session.state = .awaitingRuntime
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
                        session.templatePath,
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
                    os_log(
                        "morph failed [%{public}@]: %{public}@ — recovering",
                        log: .appScreens,
                        type: .error,
                        session.templatePath,
                        error.localizedDescription
                    )
                    self.recover(session: session, reason: "show rejected")
                }
            } catch {
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
                    session.templatePath,
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
    private func handle(_ message: AppScreenMessage, from webView: WKWebView?) {
        guard
            let webView,
            let session = liveSession(for: webView)
        else {
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
                session.templatePath,
                hrefs.count
            )
            schedulePrewarms(fromLinks: hrefs, source: session)
        }
    }

    /// Finds the live session owning `webView`, searching warm sessions, the
    /// one-off ephemeral sessions, and sessions still booting via prewarm (so a
    /// prewarming web view's `loaded` message routes to its continuation before the
    /// session is promoted into `sessions`).
    func liveSession(for webView: WKWebView) -> AppScreenSession? {
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
            let resolvedURL = Self.resolveHref(href, against: sourceDocumentURL)
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

        let templatePath = Self.templatePath(from: resolvedURL) ?? resolvedURL.path
        let existing = sessions[templatePath]
        let hasWarmReady = existing?.state == .ready
        let isOnStack = existing?.isOnStack ?? false
        let selection = Self.selectSession(hasWarmReady: hasWarmReady, isOnStack: isOnStack)

        os_log(
            "navigate → [%{public}@] %{public}@ (optimisticData=%{public}@)",
            log: .appScreens,
            type: .info,
            templatePath,
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
            session = AppScreenSession(templatePath: templatePath, webView: webView, state: .loadingDocument)
            session.isEphemeral = true
            ephemeralSessions.append(session)
            isColdLoad = true
        case .cold:
            let webView = makeWebView(screenBackground: Self.defaultScreenBackground)
            session = AppScreenSession(templatePath: templatePath, webView: webView, state: .loadingDocument)
            session.isEphemeral = false
            // The slot is free (nothing warm-ready and nothing on stack); store as
            // the template's warm session so a later navigation can reuse it.
            sessions[templatePath] = session
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
                    templatePath
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
                    templatePath
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
        let templatePath = session.templatePath
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

        Task { [weak self, weak host] in
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
                    templatePath,
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
                let knownScope = session.dataScope ?? self.sessions[templatePath]?.dataScope
                async let concurrentJSON:
                    (rawJSON: String, templateHash: String?, responseScope: AppScreenDataScope?)? = {
                        guard let knownScope else {
                            return nil
                        }
                        return try await withTimeout(seconds: Self.jsonTimeout) {
                            try await self.fetchScreenData(for: resolvedURL, scope: knownScope)
                        }
                    }()

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
                        templatePath,
                        etag ?? "(none)",
                        Self.effectiveScope(dataScope).rawValue
                    )
                    session.state = .awaitingRuntime
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
                            templatePath,
                            hydrateMs
                        )
                        host.reveal()
                        logTapToReveal()
                    } catch {
                        os_log(
                            "optimistic show rejected [%{public}@]: %{public}@ — recovering",
                            log: .appScreens,
                            type: .error,
                            templatePath,
                            error.localizedDescription
                        )
                        self.recover(session: session, reason: "optimistic show rejected")
                        return
                    }
                } else if isColdLoad {
                    // No optimistic data on a cold load: reveal the anonymous SSR body now (the
                    // morph lands when `.json` resolves).
                    host.reveal()
                    logTapToReveal()
                }
                // Warm reuse with no optimistic data: keep the previous content painted (no
                // reveal, no skeleton) until the `.json` morph below.

                // The `.json` fetch failing is non-fatal (the current content is a
                // valid render); the morph/`show()` failing is the liveness signal.
                // Resolve the concurrent fetch if a known scope started one;
                // otherwise (cold load, unknown scope) fetch now that the document
                // has set `session.dataScope`.
                let jsonResponse: (rawJSON: String, templateHash: String?, responseScope: AppScreenDataScope?)
                do {
                    if let concurrent = try await concurrentJSON {
                        jsonResponse = concurrent
                    } else {
                        let scope = Self.effectiveScope(session.dataScope)
                        jsonResponse = try await withTimeout(seconds: Self.jsonTimeout) {
                            try await self.fetchScreenData(for: resolvedURL, scope: scope)
                        }
                    }
                } catch {
                    os_log(
                        "json channel unavailable [nav %{public}@]: %{public}@ — leaving current content",
                        log: .appScreens,
                        type: .error,
                        templatePath,
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
                    host.reveal()
                    logTapToReveal()
                } catch {
                    os_log(
                        "morph failed [nav %{public}@]: %{public}@ — recovering",
                        log: .appScreens,
                        type: .error,
                        templatePath,
                        error.localizedDescription
                    )
                    self.recover(session: session, reason: "show rejected")
                }
            } catch {
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
                    templatePath,
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
            return
        }
        session.needsRecoveryOnAppear = false
        os_log(
            "deferred recovery firing on appear [%{public}@]",
            log: .appScreens,
            type: .error,
            session.templatePath
        )
        recover(session: session, reason: "deferred recovery on appear")
    }

    /// On pop: an ephemeral (detail→detail) session is torn down; a warm template
    /// session stays live with its web view warm, only leaving the stack so the
    /// next navigation to its template can reuse it.
    private func handlePop(of session: AppScreenSession) {
        if session.isEphemeral {
            os_log(
                "popped ephemeral session [%{public}@] — tearing down",
                log: .appScreens,
                type: .info,
                session.templatePath
            )
            teardown(session)
            ephemeralSessions.removeAll { $0 === session }
        } else {
            session.isOnStack = false
            os_log(
                "popped template session [%{public}@] — kept warm (off stack)",
                log: .appScreens,
                type: .info,
                session.templatePath
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

    /// Finds the live warm/ephemeral session whose host is `host` (sheet dismissal
    /// walks the sheet's view controllers back to their sessions).
    private func liveSession(hostedBy host: AppScreenHostViewController) -> AppScreenSession? {
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

    /// Builds a warm App Screens web view. Backgrounds are set before any load so
    /// there is no white flash; the `roverAppScreens` handler is attached through
    /// the weak proxy so the content controller never retains the navigator.
    func makeWebView(screenBackground: UIColor) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.userContentController.add(messageProxy, name: appScreensMessageHandlerName)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
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

    /// The screen background applied before any content loads. May later be sourced
    /// from remote config / the document. Uses the system background so the
    /// no-flash behavior holds in light and dark.
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
        MainActor.assumeIsolated {
            self.handle(parsed, from: webView)
        }
    }
}
