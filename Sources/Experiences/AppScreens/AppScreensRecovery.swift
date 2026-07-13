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

    /// Where a session's web view sits in the navigation stack when its WebContent
    /// process dies — the fact that decides *when* (and whether) to recover.
    enum SessionVisibility: Equatable {
        /// On the stack and the top (in a window) — the user is looking at it.
        case visible
        /// On the stack but not the top (a detail is pushed over it) — its web view
        /// is off-screen, where a WebKit runtime cannot boot.
        case occluded
        /// Not on the stack — an idle warm/prewarming session.
        case offStack
    }

    /// Computes a session's current stack visibility from its host view controller:
    /// off-stack when not pushed, visible when its host is loaded, in a window, and
    /// the navigation controller's `topViewController`, otherwise occluded.
    static func visibility(of session: AppScreenSession) -> SessionVisibility {
        guard session.isOnStack else {
            return .offStack
        }
        guard
            let host = session.hostViewController,
            host.viewIfLoaded?.window != nil,
            host.navigationController?.topViewController === host,
            // A session covered by a presented sheet is off-screen just like an
            // occluded push: `presentedViewController` is non-nil when this host (or
            // an ancestor) is presenting, so the sheet root reads as visible while
            // the covered session behind it reads as occluded. A runtime cannot boot
            // beneath a sheet, so recovery must defer here too.
            host.presentedViewController == nil
        else {
            return .occluded
        }
        return .visible
    }

    /// Handles `webViewWebContentProcessDidTerminate` for the web view's owning
    /// session: recover a visible session, tear down an idle warm/prewarming one.
    /// A jetsam-killed WebContent process is the liveness signal the spec's gate
    /// exercises; this is the belt-and-braces path for a session whose `callShow`
    /// was not in flight (e.g. an idle warm template), complementing the
    /// `callAsyncJavaScript` rejection the live pipelines route through `recover`.
    fileprivate func handleWebContentProcessTermination(of webView: WKWebView) {
        guard let session = liveSession(for: webView) else {
            os_log(
                "WebContent process terminated for an unrecognized web view — ignoring",
                log: .appScreens,
                type: .info
            )
            return
        }

        switch Self.recoveryAction(
            visibility: Self.visibility(of: session),
            didAttemptRecovery: session.didAttemptRecovery
        ) {
        case .recover, .failure:
            // `.failure` is folded into `recover(session:)`, whose guard surfaces the
            // retry error state when the per-navigation recovery is already spent.
            os_log(
                "WebContent process terminated [%{public}@] (visible) — recovering",
                log: .appScreens,
                type: .error,
                session.templatePath
            )
            recover(session: session, reason: "WebContent process termination")
        case .defer_:
            // Occluded: a WebKit runtime can't boot off-screen and the loaded-wait
            // would burn its whole timeout painting a failure overlay on a hidden
            // screen. Mark it and let the host recover from `viewDidAppear` when it
            // becomes visible again.
            session.needsRecoveryOnAppear = true
            os_log(
                "WebContent process terminated [%{public}@] (occluded) — deferring recovery until visible",
                log: .appScreens,
                type: .error,
                session.templatePath
            )
        case .teardown:
            os_log(
                "WebContent process terminated [%{public}@] (idle, off stack) — tearing down dead idle session",
                log: .appScreens,
                type: .info,
                session.templatePath
            )
            teardownIdle(session)
        }
    }

    /// Tears down an idle (off-stack warm or still-prewarming) session whose
    /// WebContent process died, removing it from every registry so the next
    /// navigation to its template cold-creates a fresh session.
    private func teardownIdle(_ session: AppScreenSession) {
        teardown(session)
        if sessions[session.templatePath] === session {
            sessions.removeValue(forKey: session.templatePath)
        }
        ephemeralSessions.removeAll { $0 === session }
        prewarmingSessions.removeAll { $0 === session }
        inflightPrewarms.remove(session.templatePath)
    }

    /// Recover-and-replay for a session whose render is compromised (WebContent
    /// process death, a `show()` rejection, or a bounded await failing for an
    /// on-stack session): refetch the anonymous document, re-boot the runtime, and
    /// replay the last `show()` payload so the screen is restored in place.
    ///
    /// Idempotent across the multiple signals one process death emits (`isRecovering`
    /// gate) and bounded to a single attempt per navigation (`didAttemptRecovery`):
    /// a *failed* recovery, or a second death after the recovery budget is spent,
    /// surfaces the retry error state rather than looping. A successful recovery
    /// clears `didAttemptRecovery` so a later, independent death is again eligible.
    ///
    /// When there is no prior `show()` payload (a master that has only rendered its
    /// SSR body), recovery is a document reload + reveal with no replay.
    func recover(session: AppScreenSession, reason: String) {
        // A single process death surfaces twice (rejection + terminate callback);
        // the first trigger owns the recovery, later ones are no-ops.
        guard !session.isRecovering else {
            os_log(
                "recovery already in progress [%{public}@] — ignoring duplicate trigger (%{public}@)",
                log: .appScreens,
                type: .debug,
                session.templatePath,
                reason
            )
            return
        }

        guard let host = session.hostViewController, let documentURL = session.documentURL else {
            os_log(
                "cannot recover [%{public}@] — no host or document URL",
                log: .appScreens,
                type: .error,
                session.templatePath
            )
            return
        }

        // Reload-once: a recovery already attempted (and not cleared by success)
        // this navigation means the retry did not hold — surface the error state.
        guard !session.didAttemptRecovery else {
            os_log(
                "recovery budget spent [%{public}@] — surfacing retry error state",
                log: .appScreens,
                type: .error,
                session.templatePath
            )
            host.showLoadFailure { [weak self, weak session] in
                guard let self, let session else {
                    return
                }
                session.didAttemptRecovery = false
                self.recover(session: session, reason: "manual retry")
            }
            return
        }

        session.didAttemptRecovery = true
        session.isRecovering = true
        os_log(
            "recovering [%{public}@] after %{public}@",
            log: .appScreens,
            type: .error,
            session.templatePath,
            reason
        )

        let recoverSignpostID = appScreensSignposter.makeSignpostID()
        let recoverInterval = appScreensSignposter.beginInterval("recover", id: recoverSignpostID)

        Task { [weak self, weak host, weak session] in
            guard let self, let host, let session else {
                appScreensSignposter.endInterval("recover", recoverInterval)
                return
            }
            defer { appScreensSignposter.endInterval("recover", recoverInterval) }
            do {
                // Refetch the document conditionally (304-friendly) and re-boot the
                // runtime in the same web view.
                let (html, etag, dataScope) = try await withTimeout(seconds: Self.documentTimeout) {
                    try await self.fetchDocument(url: documentURL, cachePolicy: .reloadRevalidatingCacheData)
                }
                guard let webView = session.webView else {
                    throw AppScreenDocumentError.webViewUnavailable
                }
                session.documentETag = etag
                session.dataScope = dataScope

                // Safely re-arm the runtime rendezvous: resume any continuation left
                // dangling by the death (its awaiting task unwinds via the thrown
                // cancellation) before the fresh load posts `loaded` again.
                if let dangling = session.runtimeLoadedContinuation {
                    session.runtimeLoadedContinuation = nil
                    dangling.resume(throwing: CancellationError())
                }
                session.runtimeDidLoad = false
                session.state = .awaitingRuntime
                webView.loadHTMLString(html, baseURL: documentURL)

                try await withTimeout(seconds: Self.loadedTimeout) {
                    try await self.awaitRuntimeLoaded(session)
                }
                session.state = .ready

                // Replay the last payload (full data if `.json` had landed). A master
                // that only rendered SSR has no payload — the reload + reveal suffices.
                if let payload = session.lastShowPayload {
                    let hydrateMs = try await withTimeout(seconds: Self.showTimeout) {
                        try await self.performShow(session: session, payload: payload)
                    }
                    os_log(
                        "recovery replay resolved [%{public}@] hydrateMs=%{public}.1f",
                        log: .appScreens,
                        type: .info,
                        session.templatePath,
                        hydrateMs
                    )
                } else {
                    os_log(
                        "recovery [%{public}@] — no prior show payload, document reload only",
                        log: .appScreens,
                        type: .info,
                        session.templatePath
                    )
                }

                host.reveal()
                session.isRecovering = false
                // A clean recovery restores the per-navigation budget so an
                // independent, later process death can recover once again.
                session.didAttemptRecovery = false
                os_log(
                    "recovered [%{public}@]",
                    log: .appScreens,
                    type: .info,
                    session.templatePath
                )
            } catch {
                session.isRecovering = false
                os_log(
                    "recovery failed [%{public}@]: %{public}@ — surfacing retry error state",
                    log: .appScreens,
                    type: .error,
                    session.templatePath,
                    error.localizedDescription
                )
                host.showLoadFailure { [weak self, weak session] in
                    guard let self, let session else {
                        return
                    }
                    session.didAttemptRecovery = false
                    self.recover(session: session, reason: "manual retry")
                }
            }
        }
    }
}

/// `WKNavigationDelegate` for App Screens web views. Forwards
/// `webViewWebContentProcessDidTerminate` to the navigator so a jetsam-killed
/// WebContent process either recovers (visible session) or is torn down (idle
/// warm/prewarming session). Holds the navigator weakly — the navigator owns this
/// delegate and every session's web view retains it.
@MainActor
final class AppScreenNavigationDelegate: NSObject, WKNavigationDelegate {
    weak var navigator: AppScreensNavigator?

    /// Delivered on the main thread by WebKit when a web view's content process
    /// terminates (e.g. a jetsam kill under memory pressure, or a `kill -9` from a
    /// liveness test). `nonisolated` to satisfy the protocol requirement;
    /// it hops straight to the main actor it is already running on.
    nonisolated func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        MainActor.assumeIsolated {
            navigator?.handleWebContentProcessTermination(of: webView)
        }
    }
}
