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
    /// href resolved against the source document URL, reduced to its template path,
    /// de-duplicated in DOM order, then filtered to templates that are neither
    /// already live (`existingTemplatePaths`) nor already reserved
    /// (`inflightTemplatePaths`). Pure — unit-tested in isolation.
    ///
    /// De-duplication happens *before* the live/in-flight filter, so DOM order is
    /// preserved and each template appears at most once even if several links point
    /// to it with different query params.
    static func prewarmCandidates(
        linkHrefs: [String],
        documentURL: URL,
        existingTemplatePaths: Set<String>,
        inflightTemplatePaths: Set<String>
    ) -> [PrewarmCandidate] {
        var seen: Set<String> = []
        var candidates: [PrewarmCandidate] = []

        for href in linkHrefs {
            guard
                let resolved = resolveHref(href, against: documentURL),
                let templatePath = templatePath(from: resolved)
            else {
                continue
            }
            guard seen.insert(templatePath).inserted else {
                continue
            }
            guard
                !existingTemplatePaths.contains(templatePath),
                !inflightTemplatePaths.contains(templatePath),
                let prewarmURL = prewarmURL(templatePath: templatePath, relativeTo: resolved)
            else {
                continue
            }
            candidates.append(PrewarmCandidate(templatePath: templatePath, documentURL: prewarmURL))
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
}
