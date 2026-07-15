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
import os.log

extension AppScreensNavigator {

    /// How a prewarmed web view is hosted while its runtime boots. The default is
    /// `.offscreenWindow`; `.unattached` remains available behind the flag.
    enum PrewarmAttachStrategy: Equatable {
        /// The web view is created but never added to any window. The runtime's
        /// `loaded` rendezvous is not `requestAnimationFrame`-gated, so an unattached
        /// web view boots its runtime fully and the first-tap timing budget is met.
        /// Its drawback: WebKit builds the web view's accessibility
        /// tree from the empty SSR body and does not refresh it after the runtime's
        /// Idiomorph `innerHTML` morph, so VoiceOver / XCUITest cannot read the
        /// first, never-before-attached render (the pixels are correct). Kept behind
        /// the flag for A/B timing measurement.
        case unattached
        /// Host the booting web view in a real (non-hidden) but off-screen `UIWindow`
        /// positioned just outside the visible bounds — the flows-prototype trick.
        /// Because the web view lives in a live window while it boots and morphs,
        /// WebKit keeps its accessibility tree in sync with the DOM, so the first
        /// prewarmed render is readable by VoiceOver and XCUITest. This is the
        /// default: the a11y correctness matters more than the marginal cost of one
        /// extra off-screen window, and first-tap timing stays within budget (the
        /// window is torn down / the view reparented into the pushed host at claim
        /// time). The window sits below `.normal` level and off the left edge, so it
        /// never appears on screen or steals key.
        case offscreenWindow
    }

    /// The active prewarm hosting strategy. `.offscreenWindow` is the default (its
    /// booting web view keeps a live accessibility tree — see the enum); flip to
    /// `.unattached` here to A/B the marginal first-tap timing.
    static let prewarmAttachStrategy: PrewarmAttachStrategy = .offscreenWindow

    /// A resolved prewarm target: the origin-qualified template key to warm (the
    /// session/in-flight identity) and the anonymous, param-free document URL to
    /// fetch for it. The bare template segment is not carried — it was consumed when
    /// building `documentURL` (`/a/{segment}`); everything downstream keys by
    /// `templateKey`.
    struct PrewarmCandidate: Equatable {
        let templateKey: String
        let documentURL: URL
    }

    /// Delay between successive prewarm starts, so a `links` hint's missing
    /// templates warm one at a time rather than all contending for network + CPU at
    /// once (per the spec's ~300 ms stagger).
    private static let prewarmStaggerSeconds: Double = 0.3

    /// Consumes a session's `links` hint: computes the missing template candidates,
    /// reserves them, and (re)starts the staggered drain. Coalesces — a repeated
    /// hint only ever appends genuinely-new candidates, never duplicating queued or
    /// booting work.
    func schedulePrewarms(fromLinks hrefs: [String], source: AppScreenSession) {
        #if DEBUG
            if prewarmDisabledForTesting {
                return
            }
        #endif

        guard let documentURL = source.documentURL else {
            return
        }

        // Treat a live root's template as already-live so a `links` hint that points
        // back at the root's own template (e.g. `/a/home` linking to `/a/home`) never
        // spins up a redundant warm session in the keyed pool — the root is already
        // rendering it. Roots live in `rootSessions`, not `sessions`, so they must be
        // folded into the existing-keys set explicitly.
        let liveTemplateKeys = Set(sessions.keys).union(rootSessions.map(\.templateKey))
        let candidates = Self.prewarmCandidates(
            linkHrefs: hrefs,
            documentURL: documentURL,
            existingTemplateKeys: liveTemplateKeys,
            inflightTemplateKeys: inflightPrewarms,
            allowedHosts: associatedDomains
        )
        guard !candidates.isEmpty else {
            return
        }

        // Reserve each slot immediately so a subsequent hint (or a concurrent one
        // from another session) coalesces against it.
        for candidate in candidates {
            inflightPrewarms.insert(candidate.templateKey)
            pendingPrewarms.append(candidate)
        }

        os_log(
            "prewarm scheduled %d template(s) from [%{public}@]: %{public}@",
            log: .appScreens,
            type: .info,
            candidates.count,
            source.templateKey,
            candidates.map(\.templateKey).joined(separator: ", ")
        )

        startPrewarmDrainIfIdle()
    }

    /// Starts the single stagger loop if one is not already running. New hints
    /// arriving while it runs simply appended to `pendingPrewarms`; the running loop
    /// picks them up.
    private func startPrewarmDrainIfIdle() {
        guard prewarmSchedulerTask == nil else {
            return
        }
        prewarmSchedulerTask = Task { [weak self] in
            await self?.drainPrewarmQueue()
        }
    }

    /// Drains `pendingPrewarms`, launching one prewarm worker `prewarmStaggerSeconds`
    /// apart (the first starts immediately). Each worker is an independent `Task`, so
    /// this loop only spaces out the *starts* — it never blocks on a prewarm's
    /// network + boot latency, and slow prewarms cannot delay the next one's start.
    /// Runs on the main actor, so its queue mutations interleave safely with
    /// `schedulePrewarms`. Clears its own task handle on exit so the next hint can
    /// restart it.
    private func drainPrewarmQueue() async {
        var isFirst = true
        while !pendingPrewarms.isEmpty {
            if Task.isCancelled {
                break
            }
            if !isFirst {
                try? await Task.sleep(nanoseconds: UInt64(Self.prewarmStaggerSeconds * 1_000_000_000))
                if Task.isCancelled {
                    break
                }
            }
            isFirst = false

            let candidate = pendingPrewarms.removeFirst()
            let worker = Task { [weak self] in
                guard let self else {
                    return
                }
                await self.prewarm(templateKey: candidate.templateKey, documentURL: candidate.documentURL)
            }
            prewarmWorkerTasks.append(worker)
        }

        // Release any reservations left unstarted by a cancellation so a future hint
        // can retry them.
        for leftover in pendingPrewarms {
            inflightPrewarms.remove(leftover.templateKey)
        }
        pendingPrewarms.removeAll()
        prewarmSchedulerTask = nil
    }

    /// Prewarms one template into a warm, `ready`, off-stack session: create an
    /// unattached web view, fetch the anonymous param-free document, `loadHTMLString`,
    /// await the runtime `loaded` message, then promote it into `sessions` so the
    /// next navigation to this template takes the warm-reuse path automatically
    /// (`selectSession` sees a warm-ready off-stack session). `show()` is never
    /// called here — the optimistic paint + `.json` morph run in-window at navigation time.
    ///
    /// Failure is non-fatal: log + tear down. The cold navigation path fully covers
    /// correctness, so a failed prewarm only forfeits the speedup.
    private func prewarm(templateKey: String, documentURL: URL) async {
        // Release the reservation whenever this returns.
        defer { inflightPrewarms.remove(templateKey) }

        // The slot may have filled (a real navigation cold-created the session)
        // between scheduling and now; if so, there is nothing to prewarm.
        guard sessions[templateKey] == nil else {
            return
        }

        let started = DispatchTime.now()

        let webView = makeWebView(screenBackground: Self.defaultScreenBackground)
        let session = AppScreenSession(templateKey: templateKey, webView: webView, state: .loadingDocument)
        session.documentURL = documentURL
        prewarmingSessions.append(session)

        // Host the booting web view per the active strategy. `.offscreenWindow`
        // (default) parents it in a real, off-screen window so WebKit keeps its
        // accessibility tree in sync with the morphed DOM; `.unattached` leaves it
        // window-less. Either way the runtime boots (the `loaded` rendezvous is not
        // rAF-gated). The window is released when the session is claimed or torn
        // down.
        if Self.prewarmAttachStrategy == .offscreenWindow {
            attachToOffscreenWindow(session)
        }

        do {
            let (html, etag, dataScope) = try await withTimeout(seconds: Self.documentTimeout) {
                try await self.fetchDocument(url: documentURL)
            }
            session.documentETag = etag
            // Capture the screen's data scope so the eventual navigation to this
            // warm template already knows whether its `.json` fetch is identified —
            // prewarm is the main reason a warm navigation can start `.json`
            // concurrently instead of waiting on a fresh document.
            session.dataScope = dataScope
            session.state = .awaitingRuntime
            session.runtimeDidLoad = false
            session.runtimeLoadedContinuation = nil
            session.webView?.loadHTMLString(html, baseURL: documentURL)

            try await withTimeout(seconds: Self.loadedTimeout) {
                try await self.awaitRuntimeLoaded(session)
            }
            session.state = .ready

            prewarmingSessions.removeAll { $0 === session }

            // Promote only if the slot is still free. A navigation may have
            // cold-created the template's session while we booted — drop ours then
            // (the visible session wins; a duplicate warm view would leak).
            guard sessions[templateKey] == nil else {
                teardown(session)
                os_log(
                    "prewarm [%{public}@] discarded — slot taken during boot",
                    log: .appScreens,
                    type: .info,
                    templateKey
                )
                return
            }
            sessions[templateKey] = session
            os_log(
                "prewarmed [%{public}@] %{public}.0fms",
                log: .appScreens,
                type: .info,
                templateKey,
                Self.elapsedMs(since: started)
            )
        } catch {
            prewarmingSessions.removeAll { $0 === session }
            teardown(session)
            os_log(
                "prewarm failed [%{public}@]: %{public}@ — cold path will cover",
                log: .appScreens,
                type: .error,
                templateKey,
                error.localizedDescription
            )
        }
    }

    /// Parents a prewarming session's web view in a real but off-screen `UIWindow`
    /// so WebKit renders it (and keeps its accessibility tree in sync with the
    /// Idiomorph-morphed DOM) while it boots. The window is positioned one full
    /// width off the left edge, sits below `.normal` level, and is made visible
    /// (`isHidden = false`) without ever becoming key — so it never appears on
    /// screen or steals input. No-ops (leaving the view window-less, i.e. the
    /// `.unattached` behavior) if there is no scene to attach to.
    private func attachToOffscreenWindow(_ session: AppScreenSession) {
        guard let webView = session.webView, let window = makeOffscreenWindow() else {
            return
        }
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.frame = window.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(webView)
        session.offscreenWindow = window
    }

    /// Releases a session's off-screen prewarm window, if any. The web view is
    /// removed from it first (it reparents into the pushed host on claim, or is
    /// discarded on teardown). Idempotent.
    func detachFromOffscreenWindow(_ session: AppScreenSession) {
        guard let window = session.offscreenWindow else {
            return
        }
        if session.webView?.superview === window {
            session.webView?.removeFromSuperview()
        }
        window.isHidden = true
        session.offscreenWindow = nil
    }

    /// Builds an off-screen host window on the active foreground scene: a real
    /// `UIWindow` offset one full width off the left edge, below `.normal` level,
    /// non-hidden but never key. Returns `nil` when no `UIWindowScene` is available.
    private func makeOffscreenWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard
            let scene = scenes.first(where: { $0.activationState == .foregroundActive })
                ?? scenes.first
        else {
            return nil
        }

        let bounds = scene.coordinateSpace.bounds
        let window = UIWindow(windowScene: scene)
        window.frame = bounds.offsetBy(dx: -bounds.width, dy: 0)
        window.windowLevel = .normal - 1
        window.isHidden = false
        return window
    }
}
