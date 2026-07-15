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

/// A single template's web view and lifecycle state.
///
/// The session model keeps one warm web view per origin-qualified template key. The
/// master session drives the document fetch, runtime boot, and `show()` pipeline;
/// prewarm and ephemeral detail sessions reuse the same machinery.
@MainActor
final class AppScreenSession {
    /// The origin-qualified template key this session renders (e.g.
    /// `https://a.example/a/player-detail`), derived from the `/a/{path}` URL by
    /// ``AppScreensNavigator/templateKey(from:)``. Keys the navigator's session,
    /// prewarm, and in-flight registries so the same bare path on two associated
    /// domains never shares one warm web view.
    let templateKey: String

    /// The template's web view.
    var webView: WKWebView?

    /// Where this session is in its lifecycle.
    var state: State

    /// The absolute document URL this session currently renders. Relative
    /// `navigate{href}` messages posted from this session's web view resolve
    /// against it, and the `.json` fetch derives its URL from it.
    var documentURL: URL?

    /// Whether this session's web view is currently pushed onto the navigation
    /// stack. A warm template session that is *not* on the stack can be reused for
    /// the next navigation to its template; one that *is* on the stack forces an
    /// ephemeral session (detail→detail to the same template). The master session
    /// is on the stack at the root for its whole lifetime.
    var isOnStack: Bool = false

    /// A one-off session created for a detail→detail navigation to a template that
    /// is already on the stack. It is never stored in the navigator's warm-session
    /// dictionary and is torn down when popped (the warm template session behind it
    /// stays live).
    var isEphemeral: Bool = false

    /// Set once a recover-and-replay has been attempted for the current
    /// navigation, so a *failed* recovery degrades to the retry error state
    /// instead of looping. Reset at the start of each navigation into the session
    /// (and cleared again on a successful recovery so a later, independent process
    /// death is still eligible for its own single recovery).
    var didAttemptRecovery: Bool = false

    /// True while a `recover(session:)` attempt is in flight. A single WebContent
    /// process death surfaces through *two* signals — the pending
    /// `callAsyncJavaScript` rejecting and `webViewWebContentProcessDidTerminate`
    /// firing — and a bounded await can also time out concurrently. This flag makes
    /// `recover(session:)` idempotent: the first trigger owns the recovery, the
    /// others are ignored, so the failure UI can never paint over an in-flight
    /// recovery.
    var isRecovering: Bool = false

    /// The most recent `links` prewarm hints posted by this session's runtime, in
    /// DOM order. Consumed by the prewarm scheduler to warm missing templates.
    var latestLinkHrefs: [String] = []

    /// The real-but-off-screen `UIWindow` hosting this session's web view while it
    /// prewarms (see ``AppScreensNavigator/PrewarmAttachStrategy/offscreenWindow``).
    /// A web view booting its runtime inside a live window keeps its accessibility
    /// tree in sync with the Idiomorph-morphed DOM, unlike a window-less one. Held
    /// only until the session is claimed for a navigation (the web view reparents
    /// into the pushed host) or torn down; `nil` for master/cold/ephemeral sessions.
    var offscreenWindow: UIWindow?

    /// Set when an *occluded* (on-stack but not the visible top) session's
    /// WebContent process dies. Its runtime cannot boot off-screen, so recovery is
    /// deferred: the navigator marks this flag instead of recovering immediately,
    /// and the host fires `recover` from `viewDidAppear` once the screen is visible
    /// again. Cleared as soon as the deferred recovery starts.
    var needsRecoveryOnAppear: Bool = false

    /// The host view controller currently presenting this session's web view.
    /// Weak so a popped host deallocates; used to find the navigation controller a
    /// `navigate` should push onto.
    weak var hostViewController: AppScreenHostViewController?

    /// Host-supplied dismissal for the enclosing Experience presentation. Non-`nil`
    /// only on a root session whose presenter opted in (by threading a dismissal
    /// closure through the entry point); invoked for an `openURL` message carrying
    /// `dismiss: true`. `nil` on every non-root session and on a root whose presenter
    /// did not opt in.
    var onDismissButtonPressed: (() -> Void)?

    /// Host-supplied URL opener, consulted only for an `openURL` message (never for
    /// `presentWebsite`). Non-`nil` only on a root session whose presenter supplied an
    /// override; `nil` falls back to `UIApplication.shared.open`.
    var onOpenURL: ((URL) -> Void)?

    /// The `ETag` captured from the anonymous document response, compared against
    /// the `.json` `templateHash` in the hash handshake.
    var documentETag: String?

    /// The screen's data scope, as last advertised by the server. Written by
    /// every document fetch (the document response carries it on 200 and 304),
    /// and freshened from a `.json` response header **only when that header is
    /// present** (a `nil` never overwrites a known scope). Drives whether the
    /// `.json` request attaches identifiers + a JWT (`.personalized`) or is sent
    /// completely bare (`.public`). `nil` until the first document lands, at which
    /// point ``AppScreensNavigator/effectiveScope(_:)`` supplies the fail-safe
    /// `.personalized` default for an older server that advertises no scope.
    var dataScope: AppScreenDataScope?

    /// The last `show()` payload that resolved successfully, replayed after a
    /// WebContent process termination so recovery restores the last rendered state.
    var lastShowPayload: ShowPayload?

    /// Set the moment the runtime posts `loaded`. The `loaded` rendezvous checks
    /// this first so a message that arrives before anyone awaits is not lost.
    var runtimeDidLoad = false

    /// Resumed by the routed `loaded` message. Niled on resume to guard against a
    /// double resume.
    var runtimeLoadedContinuation: CheckedContinuation<Void, Error>?

    /// The single in-flight load/navigation pipeline for this session — the `Task`
    /// created by ``AppScreensNavigator/runMasterPipeline(entryURL:session:host:)``,
    /// ``AppScreensNavigator/runNavigatePipeline(resolvedURL:optimisticDataJSON:session:host:isColdLoad:tapTime:)``,
    /// or an in-flight ``AppScreensNavigator/recover(session:reason:)``. A session
    /// runs at most one legitimate pipeline at a time, so it is superseded and
    /// cancelled on pop, reuse, teardown, and recovery: each entry point cancels
    /// whatever is here before storing its own `Task`. Cancelling stops a
    /// superseded pipeline from morphing, revealing, writing session state, or
    /// painting the load-failure UI into a web view that has since been reused for
    /// a different record.
    var pipelineTask: Task<Void, Never>?

    enum State {
        case loadingDocument
        case awaitingRuntime
        case ready
        case dead
    }

    init(templateKey: String, webView: WKWebView? = nil, state: State = .loadingDocument) {
        self.templateKey = templateKey
        self.webView = webView
        self.state = state
    }
}

/// The arguments handed to the runtime's `show()` call. `optimisticDataJSON`/`responseJSON`
/// are raw JSON text forwarded verbatim (the runtime `JSON.parse`s them); the
/// master pipeline passes neither.
struct ShowPayload: Sendable {
    let href: String
    let optimisticDataJSON: String?
    let responseJSON: String?
}
