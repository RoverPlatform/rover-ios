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

import Foundation

/// A screen's static data scope, advertised by the server on every document
/// response (200 **and** 304) and every `.json` data response via the
/// `x-rover-app-screen-data-scope` header.
///
/// The scope is a property of the *screen* (personalized when its template
/// references `user` or a personalized data connector; public otherwise), not
/// of a request. The SDK derives its `.json` request from it: a `personalized`
/// screen attaches identifiers (`deviceIdentifier`/`userID`) + a JWT so the data
/// is per-user; a `public` screen sends a completely bare request so a URL-keyed
/// CDN shares one cache entry across every device.
enum AppScreenDataScope: String {
    case `public` = "public"
    case personalized = "personalized"

    /// The response header carrying a screen's data scope, on both the document
    /// and `.json` channels.
    static let headerName = "x-rover-app-screen-data-scope"

    /// Parses a scope from a raw header value: whitespace-trimmed and
    /// case-insensitive, so `Public`, `PERSONALIZED`, and ` public ` all parse.
    /// An unknown or absent value yields `nil` — the caller applies the
    /// fail-safe default (see ``AppScreensNavigator/effectiveScope(_:)``).
    init?(headerValue: String?) {
        guard let headerValue else {
            return nil
        }
        let normalized = headerValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            return nil
        }
        self.init(rawValue: normalized)
    }
}

/// The result of the hash handshake: comparing the normalized document `ETag`
/// against the `.json` `templateHash` decides whether the `.json` data can be
/// morphed over the current document, or whether the document must be refetched
/// first so a v2 payload can never render over a v1 template (and vice versa).
enum HandshakeOutcome: Equatable {
    /// Hashes match: morph the data over the current document.
    case render
    /// Hashes differ: refetch the document (conditionally) before rendering.
    case reloadFirst
    /// No `templateHash` to compare against: render anyway (fail open) + warn.
    case failOpen
}

extension AppScreensNavigator {

    /// The session-selection decision for a navigation. Pure function of the two
    /// facts that matter, so it is unit-tested in isolation.
    enum SessionSelection: Equatable {
        /// A warm, ready, off-stack template session exists: reuse its web view
        /// (reset scroll, keep the previous content painted through the push).
        case reuse
        /// The template is already on the stack (detail→detail): create a one-off
        /// ephemeral session, cold-loaded and discarded on pop.
        case ephemeral
        /// No usable session: cold-create and store as the template's warm session.
        case cold
    }

    /// The action to take when a session's WebContent process dies (or a bounded
    /// await for a previously-ready web view fails). Pure function of the two facts
    /// that matter, so it is unit-tested in isolation.
    enum RecoveryAction: Equatable {
        /// The session is visible and has not yet used its per-navigation recovery:
        /// reload the document once and replay the last `show()` payload.
        case recover
        /// The session is visible but already spent its recovery this navigation:
        /// surface the retry error state instead of looping.
        case failure
        /// The session is occluded (on-stack but not top): a WebKit runtime cannot
        /// boot off-screen and a loaded-wait would burn its full timeout painting a
        /// failure overlay on a hidden screen. Defer — mark the session and recover
        /// from the host's `viewDidAppear` when it becomes visible again.
        case defer_
        /// The session is an idle warm/prewarming web view off the stack: tear it
        /// down so the next tap takes the cold path.
        case teardown
    }

    /// Chooses how to satisfy a navigation to a template, given whether a warm
    /// ready session already exists for it and whether that session is currently on
    /// the navigation stack. On-stack wins first (detail→detail must not disturb the
    /// visible screen); otherwise a warm ready session is reused; otherwise cold.
    static func selectSession(hasWarmReady: Bool, isOnStack: Bool) -> SessionSelection {
        if isOnStack {
            return .ephemeral
        }
        if hasWarmReady {
            return .reuse
        }
        return .cold
    }

    /// Resolves a `navigate` href against the document URL of the session that
    /// posted it. Relative hrefs (`/a/player-detail?id=3`) become absolute on the
    /// same host; already-absolute hrefs (same host or other) pass through; the
    /// query is preserved in every case.
    static func resolveHref(_ href: String, against documentURL: URL) -> URL? {
        URL(string: href, relativeTo: documentURL)?.absoluteURL
    }

    /// Interprets an external-link href (`openURL` / `presentWebsite`) the way a
    /// browser interprets an `<a href>`: WHATWG-style resolution against the posting
    /// document's URL. Absolute URLs — http(s), `mailto:`, `tel:`, custom deep-link
    /// schemes — pass through as written (unlike `resolveHref`'s `navigate` targets,
    /// opaque schemes are valid here — deep links are the point); relative,
    /// protocol-relative, and query/fragment hrefs resolve against `documentURL`,
    /// which is what lets `openURL` reach *other* experiences by path. Leading and
    /// trailing whitespace is trimmed, as the WHATWG parser does. Deliberately NO
    /// address-bar-style host guessing: a scheme-less `www.example.com` is a
    /// relative path per the URL standard and resolves onto the document's domain.
    /// A blank or unparseable href returns `nil` for the caller to log and drop.
    static func externalURL(from href: String, against documentURL: URL) -> URL? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return URL(string: trimmed, relativeTo: documentURL)?.absoluteURL
    }

    /// Derives the template path from an App Screens URL: the path after the `a`
    /// component, query stripped, multi-segment joined with `/`.
    ///
    /// `/a/player-detail?id=12` → `player-detail`; `/a/home` → `home`;
    /// `/a/x/y` → `x/y`. Returns `nil` when the URL is not an `/a/{path}` URL
    /// or carries no template segment.
    static func templatePath(from url: URL) -> String? {
        let components = url.pathComponents
        guard components.count >= 2, components[1] == "a" else {
            return nil
        }

        let tail = components.dropFirst(2)
        guard !tail.isEmpty else {
            return nil
        }

        return tail.joined(separator: "/")
    }

    /// The normalized origin of a URL — `scheme://host[:port]` with scheme and host
    /// lowercased and the port kept only when it is explicit *and* not the scheme's
    /// default (an absent port, or an explicit default like `:443` for https, both
    /// collapse to no port). `nil` when the URL has no scheme or host. The shared
    /// basis for every origin-qualified identity, so `https://host` and an explicit
    /// `https://host:443` resolve to one identity — matching the origin equivalence
    /// ``bridgeMessageAllowed(isMainFrame:originProtocol:originHost:originPort:documentURL:)``
    /// already enforces.
    static func normalizedOrigin(of url: URL) -> String? {
        guard
            let scheme = url.scheme?.lowercased(),
            let host = url.host?.lowercased()
        else {
            return nil
        }
        if let port = url.port, port != Self.defaultPort(forScheme: scheme) {
            return "\(scheme)://\(host):\(port)"
        }
        return "\(scheme)://\(host)"
    }

    /// The origin-qualified identity for an App Screens URL:
    /// `scheme://host[:port]/a/{templatePath}` with scheme + host lowercased, the
    /// port included only when explicit, and query/fragment excluded. Returns `nil`
    /// when the URL is not an `/a/{path}` URL (same rule as ``templatePath(from:)``)
    /// or has no resolvable origin.
    ///
    /// This — not the bare template path — is the session/prewarm/in-flight identity.
    /// Two associated domains that both serve `/a/detail`
    /// (`https://a.example/a/detail` and `https://b.example/a/detail`) are distinct
    /// screens and must never share a warm web view, so the origin keys every slot.
    static func templateKey(from url: URL) -> String? {
        guard
            let templatePath = templatePath(from: url),
            let origin = normalizedOrigin(of: url)
        else {
            return nil
        }
        return "\(origin)/a/\(templatePath)"
    }

    /// A defensive origin-qualified identity for an entry URL that is *not* an
    /// `/a/{template}` URL: `scheme://host[:port]{path}` when the origin resolves,
    /// else the full URL string. ``AppScreensNavigator/makeRootViewController(for:)``
    /// is the only caller — the entry URL is pre-gated upstream — so this merely
    /// guarantees that even a contract-violating entry can never collide across
    /// domains the way a bare `url.path` would.
    static func fallbackTemplateKey(for url: URL) -> String {
        guard let origin = normalizedOrigin(of: url) else {
            return url.absoluteString
        }
        return origin + url.path
    }

    /// Builds the data endpoint URL for an App Screens document URL by appending
    /// `.json` to the path while preserving the query.
    ///
    /// `/a/player-detail?id=12` → `/a/player-detail.json?id=12`. Returns `nil`
    /// when the URL has no meaningful path.
    static func jsonURL(from url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        guard !components.path.isEmpty, components.path != "/" else {
            return nil
        }

        components.path += ".json"
        return components.url
    }

    /// The relative `href` handed to `show()` for the entry URL: path plus the
    /// original (percent-encoded) query, matching what the runtime expects.
    ///
    /// `https://testbench.rover.io/a/home` → `/a/home`;
    /// `.../a/player-detail?id=12` → `/a/player-detail?id=12`.
    static func relativeHref(for url: URL) -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.path
        }
        guard let query = components.percentEncodedQuery, !query.isEmpty else {
            return components.path
        }
        return "\(components.path)?\(query)"
    }

    /// Computes the ordered, distinct prewarm candidates for a `links` hint: each
    /// href resolved against the source document URL, reduced to its origin-qualified
    /// template key (dropping anything that is not an `/a/{template}` document on an
    /// authorized `allowedHosts` http(s) origin), de-duplicated in DOM order, then
    /// filtered to keys that are neither already live (`existingTemplateKeys`) nor
    /// already reserved (`inflightTemplateKeys`). Pure — unit-tested in isolation.
    ///
    /// De-duplication (and every filter) is keyed by the origin-qualified
    /// ``templateKey(from:)``, so the same bare path on two associated domains is two
    /// distinct candidates and never collapses into one warm web view.
    /// De-duplication happens *before* the live/in-flight filter, so DOM order is
    /// preserved and each key appears at most once even if several links point to it
    /// with different query params.
    static func prewarmCandidates(
        linkHrefs: [String],
        documentURL: URL,
        existingTemplateKeys: Set<String>,
        inflightTemplateKeys: Set<String>,
        allowedHosts: Set<String>
    ) -> [PrewarmCandidate] {
        var seen: Set<String> = []
        var candidates: [PrewarmCandidate] = []

        for href in linkHrefs {
            guard
                let resolved = resolveHref(href, against: documentURL),
                let templatePath = templatePath(from: resolved),
                let templateKey = templateKey(from: resolved),
                // A `links` hint can carry an absolute href to any host; only prewarm
                // App Screens documents on an authorized, http(s) origin so a hostile
                // page can never be booted with the bridge attached.
                let scheme = resolved.scheme?.lowercased(),
                scheme == "https" || scheme == "http",
                let host = resolved.host,
                allowedHosts.contains(host.lowercased())
            else {
                continue
            }
            guard seen.insert(templateKey).inserted else {
                continue
            }
            guard
                !existingTemplateKeys.contains(templateKey),
                !inflightTemplateKeys.contains(templateKey),
                // The document URL still needs the *bare* template segment; the origin
                // rides in `templateKey`, which the candidate carries as its identity.
                let prewarmURL = prewarmURL(templatePath: templatePath, relativeTo: resolved)
            else {
                continue
            }
            candidates.append(PrewarmCandidate(templateKey: templateKey, documentURL: prewarmURL))
        }

        return candidates
    }

    /// Builds the anonymous prewarm document URL for a template: the source host +
    /// `/a/{templatePath}` with **no query or fragment**. Template documents are
    /// per-template (params only ever ride on the `.json` fetch), so a prewarm never
    /// carries an `id` — one warm document serves every parameterization.
    ///
    /// `/a/player-detail?id=12` (resolved) → `https://host/a/player-detail`.
    static func prewarmURL(templatePath: String, relativeTo url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = "/a/\(templatePath)"
        components.query = nil
        components.fragment = nil
        return components.url
    }

    /// Normalizes an HTTP `ETag` for comparison against the `.json`
    /// `templateHash`: strips a weak-validator `W/` prefix and the surrounding
    /// double quotes an `ETag` is transported in, so `W/"fx-home-v1"` and
    /// `"fx-home-v1"` both compare equal to the bare `fx-home-v1`. `nil`-safe.
    static func normalizeETag(_ etag: String?) -> String? {
        guard let etag else {
            return nil
        }
        var value = etag.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("W/") {
            value = String(value.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        }
        return value
    }

    /// The fail-safe data scope (pure, unit-tested): a document that carries no
    /// scope header (an older server) is treated as `.personalized`. That is
    /// today's behavior — identifiers are always attached — so it can never break
    /// personalization; a bare public request is only ever taken once the server
    /// explicitly advertises `public`.
    static func effectiveScope(_ scope: AppScreenDataScope?) -> AppScreenDataScope {
        scope ?? .personalized
    }

    /// The one-shot retry decision (pure, unit-tested) for the stale-hint window:
    /// a `.json` fetched as `public` whose response header instead says
    /// `personalized` means the screen's scope flipped between the document load
    /// and the data fetch, so it must be refetched ONCE with identifiers + JWT.
    /// Every other combination — a public response to a public request, any
    /// personalized request, or a response with no scope header — needs no retry
    /// (the reverse flip just records the new scope).
    static func shouldRefetchWithIdentifiers(
        requestedScope: AppScreenDataScope,
        responseScope: AppScreenDataScope?
    ) -> Bool {
        requestedScope == .public && responseScope == .personalized
    }

    /// The eager-fetch reconcile decision (pure, unit-tested) for a cold load.
    ///
    /// A cold load may kick a `.json` fetch off concurrently under a scope
    /// guessed from a warm/prewarmed session (`eagerScope`) before the fresh
    /// document lands and advertises the screen's real scope (`effectiveScope`).
    /// When those two disagree the eager result must be discarded and refetched,
    /// and the mismatch bites in *both* directions:
    ///
    /// - A stale `personalized` eager fetch against a now-`public` screen sent
    ///   the account token + identifiers to a public endpoint — a leak the
    ///   response-side retry (``shouldRefetchWithIdentifiers(requestedScope:responseScope:)``)
    ///   never corrects, since it only flips public→personalized.
    /// - A stale `public` eager fetch against a now-`personalized` screen may
    ///   fail (e.g. an unauthenticated `401`) before it can observe the
    ///   personalized response header, stranding SSR-only content.
    ///
    /// A `nil` eager scope means no concurrent fetch was started (the fetch
    /// waited for the document), so there is nothing to reconcile → `false`.
    static func shouldRestartEagerFetch(
        eagerScope: AppScreenDataScope?,
        effectiveScope: AppScreenDataScope
    ) -> Bool {
        guard let eagerScope else {
            return false
        }
        return eagerScope != effectiveScope
    }

    /// The hash-handshake decision (pure, unit-tested): compares the normalized
    /// document `ETag` against the `.json` `templateHash`.
    ///
    /// A missing/empty `templateHash` fails open (`.failOpen`); a match renders
    /// (`.render`); anything else demands a document refetch first (`.reloadFirst`)
    /// so a payload can never be morphed over a template of a different version.
    static func decide(documentETag: String?, templateHash: String?) -> HandshakeOutcome {
        guard let templateHash, !templateHash.isEmpty else {
            return .failOpen
        }
        guard normalizeETag(documentETag) == templateHash else {
            return .reloadFirst
        }
        return .render
    }

    /// Decides how to respond to a WebContent process termination for a session,
    /// given its stack visibility and whether it has already attempted a recovery
    /// this navigation. Visible sessions recover once (then fail); occluded sessions
    /// defer recovery until they are visible again; off-stack idle sessions are torn
    /// down.
    static func recoveryAction(visibility: SessionVisibility, didAttemptRecovery: Bool) -> RecoveryAction {
        switch visibility {
        case .offStack:
            return .teardown
        case .occluded:
            return .defer_
        case .visible:
            return didAttemptRecovery ? .failure : .recover
        }
    }

    /// The bridge-message authentication decision (pure, unit-tested). A native
    /// bridge message is honored only when it originates from the web view's **main
    /// frame** AND that frame's security origin matches the owning session's
    /// `documentURL` origin (scheme + host + port). Everything else — a cross-origin
    /// iframe, an externally navigated page, a subframe — is rejected, so an
    /// embedded frame can never mark a half-booted session ready or trigger native
    /// navigation and authenticated data requests.
    ///
    /// Takes plain values rather than `WKFrameInfo`/`WKSecurityOrigin` so it is
    /// testable without WebKit. `originProtocol`/`originHost` come from
    /// `WKSecurityOrigin.protocol`/`.host`; `originPort` from `WKSecurityOrigin.port`,
    /// which is `0` for a scheme's default port. `URL.port` is `nil` for a default
    /// port, so both sides are normalized to the scheme's canonical default before
    /// comparing — `https://host` and an explicit `https://host:443` are the same
    /// origin.
    static func bridgeMessageAllowed(
        isMainFrame: Bool,
        originProtocol: String,
        originHost: String,
        originPort: Int,
        documentURL: URL
    ) -> Bool {
        guard isMainFrame else {
            return false
        }
        guard
            let expectedScheme = documentURL.scheme?.lowercased(),
            let expectedHost = documentURL.host
        else {
            return false
        }
        guard originProtocol.lowercased() == expectedScheme else {
            return false
        }
        guard originHost.caseInsensitiveCompare(expectedHost) == .orderedSame else {
            return false
        }
        let defaultPort = Self.defaultPort(forScheme: expectedScheme)
        let normalizedOriginPort = originPort == 0 ? defaultPort : originPort
        let normalizedDocumentPort = documentURL.port ?? defaultPort
        return normalizedOriginPort == normalizedDocumentPort
    }

    /// The canonical default port for a URL scheme, used to reconcile
    /// `WKSecurityOrigin.port` (0 for default) with `URL.port` (nil for default)
    /// when authenticating a bridge message's origin. Unknown schemes have no
    /// default (`nil`), so their ports must match exactly.
    static func defaultPort(forScheme scheme: String) -> Int? {
        switch scheme.lowercased() {
        case "https":
            return 443
        case "http":
            return 80
        default:
            return nil
        }
    }

    /// An authorized bridge navigation target: the normalized (https) URL and its
    /// App Screens template path, produced by ``authorizedTarget(resolvedURL:allowedHosts:)``.
    struct AuthorizedTarget: Equatable {
        let url: URL
        let templatePath: String
    }

    /// The bridge-navigation authorization decision (pure, unit-tested). A `navigate`
    /// message's resolved target is honored only when it is (a) an `/a/{template}`
    /// App Screens URL, (b) http or https — normalized to https, exactly as the entry
    /// point does — and (c) hosted on one of the app's associated domains
    /// (`allowedHosts`, compared case-insensitively). Any other target — a foreign
    /// host, a custom scheme, or a non-App-Screen path — returns `nil` so the caller
    /// rejects and logs it, closing the hole where a screen could steer the
    /// personalized `.json` fetch (which carries the Rover account token and
    /// device/user identifiers) or the bridge-bearing web view to an attacker origin.
    ///
    /// `allowedHosts` must already be lowercased. Returns the normalized URL and its
    /// template path so the caller neither re-normalizes nor force-unwraps the path.
    static func authorizedTarget(resolvedURL: URL, allowedHosts: Set<String>) -> AuthorizedTarget? {
        guard
            let scheme = resolvedURL.scheme?.lowercased(),
            scheme == "https" || scheme == "http"
        else {
            return nil
        }
        guard var components = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        // Upgrade http → https before the host gate and any fetch/load, mirroring
        // `ExperienceViewController.loadAppScreensExperience`.
        components.scheme = "https"
        guard
            let normalizedURL = components.url,
            let templatePath = templatePath(from: normalizedURL),
            let host = normalizedURL.host,
            allowedHosts.contains(host.lowercased())
        else {
            return nil
        }
        return AuthorizedTarget(url: normalizedURL, templatePath: templatePath)
    }

    /// Coerces a `presentWebsite` target into a URL `SFSafariViewController` will
    /// accept, or `nil` when the link is not presentable in an in-app browser.
    ///
    /// `SFSafariViewController` requires an http/https URL and crashes when handed
    /// anything else, so a non-http(s) scheme is rewritten to https via
    /// `URLComponents` — coercion that mirrors the V2 action handler and the Android
    /// SDK, so a link authored once behaves identically on both platforms. An http(s)
    /// URL (scheme compared case-insensitively) passes through unchanged. The result
    /// must have a non-`nil` host, so opaque or hostless URLs (`mailto:`, `tel:`) are
    /// not presentable and return `nil`.
    static func safariPresentableURL(_ url: URL) -> URL? {
        let scheme = url.scheme?.lowercased()
        if scheme == "https" || scheme == "http" {
            return url.host == nil ? nil : url
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = "https"
        guard let coerced = components.url, coerced.host != nil else {
            return nil
        }
        return coerced
    }

    /// The main-frame navigation policy decision (pure, unit-tested), mirroring the
    /// shape of ``bridgeMessageAllowed(isMainFrame:originProtocol:originHost:originPort:documentURL:)``.
    /// The App Screens runtime never navigates the main frame itself — every
    /// legitimate document load is a native `loadHTMLString(_:baseURL:)`, which
    /// arrives as a `.other` navigation whose request URL equals the base URL (the
    /// session's `documentURL`). So allow:
    ///
    /// - any non-main-frame action (an iframe may load its own content);
    /// - a main-frame `.other` action whose request URL is `about:blank` or nil, or
    ///   matches the owning session's `documentURL` (the native load).
    ///
    /// Everything else — a `.linkActivated` main-frame tap, a scripted `location.href`,
    /// or an `.other` action to any other URL — is denied, so page JS can never render
    /// arbitrary web content inside the native-chrome App Screen.
    ///
    /// Takes plain values (`isOtherNavigationType` in place of `WKNavigationType`,
    /// `isMainFrame` in place of `WKFrameInfo`) so it is testable without WebKit.
    static func mainFrameNavigationAllowed(
        isMainFrame: Bool,
        isOtherNavigationType: Bool,
        requestURL: URL?,
        documentURL: URL?
    ) -> Bool {
        guard isMainFrame else {
            return true
        }
        guard isOtherNavigationType else {
            return false
        }
        guard let requestURL else {
            return true
        }
        if requestURL.absoluteString == "about:blank" {
            return true
        }
        guard let documentURL else {
            return false
        }
        return requestURL.absoluteString == documentURL.absoluteString
    }
}
