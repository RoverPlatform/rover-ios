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
import RoverData
import WebKit
import os.log

/// Errors from the anonymous document channel.
enum AppScreenDocumentError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case notUTF8
    case webViewUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "App Screens document response was not an HTTP response"
        case .httpStatus(let code):
            return "App Screens document fetch failed with HTTP \(code)"
        case .notUTF8:
            return "App Screens document body was not valid UTF-8"
        case .webViewUnavailable:
            return "App Screens web view was unavailable"
        }
    }
}

/// Errors from the `.json` data channel.
enum AppScreenDataError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case notUTF8

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "App Screens data URL could not be derived"
        case .invalidResponse:
            return "App Screens data response was not an HTTP response"
        case .httpStatus(let code):
            return "App Screens data fetch failed with HTTP \(code)"
        case .notUTF8:
            return "App Screens data body was not valid UTF-8"
        }
    }
}

extension AppScreensNavigator {

    /// Fetches the anonymous document. A bare `URLRequest` — no account token, no
    /// `Authorization`, no identifier query items — so credentials never touch the
    /// document channel, in any scope. Captures the `ETag` for the hash handshake
    /// and the screen's data scope from the `x-rover-app-screen-data-scope` header
    /// (present on 200 and 304, so a cache-served/304-freshened response carries it
    /// too), which drives whether the derived `.json` request is identified.
    ///
    /// The hash-mismatch reload passes `.reloadRevalidatingCacheData` so the
    /// refetch is conditional (`If-None-Match`/304-friendly) yet always revalidates
    /// against the origin rather than serving the stale cached document.
    func fetchDocument(
        url: URL,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) async throws -> (html: String, etag: String?, dataScope: AppScreenDataScope?) {
        let signpostID = appScreensSignposter.makeSignpostID()
        let interval = appScreensSignposter.beginInterval("document fetch", id: signpostID)
        defer { appScreensSignposter.endInterval("document fetch", interval) }

        var request = URLRequest(url: url)
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.cachePolicy = cachePolicy

        let (data, response) = try await documentSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppScreenDocumentError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AppScreenDocumentError.httpStatus(httpResponse.statusCode)
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw AppScreenDocumentError.notUTF8
        }

        // `HTTPURLResponse.value(forHTTPHeaderField:)` is case-insensitive.
        let etag = httpResponse.value(forHTTPHeaderField: "ETag")
        let dataScope = AppScreenDataScope(
            headerValue: httpResponse.value(forHTTPHeaderField: AppScreenDataScope.headerName)
        )
        return (html, etag, dataScope)
    }

    /// Fetches the `/a/{path}.json` payload, deriving its shape from the screen's
    /// data scope (captured from the document the SDK just loaded).
    ///
    /// - `.personalized`: through `HTTPClient`'s package-scoped authenticated
    ///   request path so the SDK's identifiers (`deviceIdentifier`/`userID` query
    ///   items) — and an `Authorization: Bearer` JWT when signed in (host
    ///   `*.rover.io` is JWT-enabled) — are attached; the credential never crosses
    ///   the bridge.
    /// - `.public`: a completely bare `URLRequest` (`Accept: application/json`, no
    ///   identifiers, no `Authorization`) through the document channel's own
    ///   `URLSession`, whose private `URLCache` gives the device-side freshness
    ///   window the `public, max-age=60` response advertises. A bare, URL-keyed
    ///   request lets a shared CDN serve one entry to every device.
    ///
    /// Implements the one-shot stale-hint retry: a `.json` fetched as `public`
    /// whose response instead advertises `personalized` (the screen's scope
    /// flipped between the document load and this fetch) is refetched ONCE through
    /// the authenticated path. The raw response body is kept verbatim as a
    /// `String` (forwarded into `show()`); only `templateHash` is peeked, via a
    /// one-field `Decodable`. Non-2xx statuses throw.
    func fetchScreenData(
        for url: URL,
        scope: AppScreenDataScope
    ) async throws -> (rawJSON: String, templateHash: String?, responseScope: AppScreenDataScope?) {
        guard let dataURL = Self.jsonURL(from: url) else {
            throw AppScreenDataError.invalidURL
        }

        let signpostID = appScreensSignposter.makeSignpostID()
        let interval = appScreensSignposter.beginInterval("json fetch", id: signpostID)
        defer { appScreensSignposter.endInterval("json fetch", interval) }

        let result = try await fetchScreenDataOnce(dataURL: dataURL, scope: scope, sourceURL: url)

        guard
            Self.shouldRefetchWithIdentifiers(requestedScope: scope, responseScope: result.responseScope)
        else {
            return result
        }
        os_log(
            "json scope flipped to personalized [%{public}@] — refetching with identifiers",
            log: .appScreens,
            type: .default,
            Self.templatePath(from: url) ?? url.path
        )
        return try await fetchScreenDataOnce(dataURL: dataURL, scope: .personalized, sourceURL: url)
    }

    /// One `.json` fetch for a given scope, with no retry. `.personalized` rides
    /// the authenticated download path (identifiers + JWT); `.public` is a bare
    /// request through `documentSession`, with non-2xx statuses thrown in the
    /// document channel's error style. Reads the response's advertised scope from
    /// the `x-rover-app-screen-data-scope` header (case-insensitive) in both cases.
    private func fetchScreenDataOnce(
        dataURL: URL,
        scope: AppScreenDataScope,
        sourceURL: URL
    ) async throws -> (rawJSON: String, templateHash: String?, responseScope: AppScreenDataScope?) {
        let started = DispatchTime.now()

        let data: Data
        let statusCode: Int
        let responseScope: AppScreenDataScope?

        switch scope {
        case .personalized:
            let request = try await httpClient.authenticatedDownloadRequest(url: dataURL)
            switch await httpClient.download(with: request) {
            case .success(let payload, let response):
                data = payload
                statusCode = response.statusCode
                responseScope = AppScreenDataScope(
                    headerValue: response.value(forHTTPHeaderField: AppScreenDataScope.headerName)
                )
            case .error(let error, _):
                throw error ?? URLError(.unknown)
            }
        case .public:
            var request = URLRequest(url: dataURL)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (payload, response) = try await documentSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppScreenDataError.invalidResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw AppScreenDataError.httpStatus(httpResponse.statusCode)
            }
            data = payload
            statusCode = httpResponse.statusCode
            responseScope = AppScreenDataScope(
                headerValue: httpResponse.value(forHTTPHeaderField: AppScreenDataScope.headerName)
            )
        }

        guard let rawJSON = String(data: data, encoding: .utf8) else {
            throw AppScreenDataError.notUTF8
        }
        let templateHash = Self.peekTemplateHash(from: data)
        let elapsedMs =
            Double(DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds)
            / 1_000_000
        os_log(
            "json loaded [%{public}@] scope=%{public}@ status=%d templateHash=%{public}@ %{public}.1fms",
            log: .appScreens,
            type: .info,
            Self.templatePath(from: sourceURL) ?? sourceURL.path,
            scope.rawValue,
            statusCode,
            templateHash ?? "(none)",
            elapsedMs
        )
        return (rawJSON, templateHash, responseScope)
    }

    /// Peeks only the `templateHash` field out of a `.json` body, leaving the rest
    /// of the (opaque, forwarded-verbatim) payload untouched. Returns `nil` when
    /// the field is absent or the body is not decodable.
    static func peekTemplateHash(from data: Data) -> String? {
        (try? JSONDecoder().decode(TemplateHashPeek.self, from: data))?.templateHash
    }

    /// One-field view over a `.json` body for `templateHash` peeking.
    private struct TemplateHashPeek: Decodable {
        let templateHash: String?
    }

    /// Runs the hash handshake, then morphs the `.json` data over the current
    /// document via `show()`.
    ///
    /// - `.render`: hashes match, morph directly.
    /// - `.failOpen`: no `templateHash` to compare, warn + morph anyway.
    /// - `.reloadFirst`: hashes differ (document/data skew). Warn, refetch the
    ///   document ONCE (conditionally), re-boot the runtime, update the ETag, and
    ///   re-check. If it *still* mismatches, log one fault and proceed anyway — no
    ///   loop. This guarantees v2 data is never morphed over a v1 template while a
    ///   single refetch is in flight.
    func runHashHandshakeAndMorph(
        session: AppScreenSession,
        entryURL: URL,
        href: String,
        optimisticDataJSON: String? = nil,
        rawJSON: String,
        templateHash: String?
    ) async throws {
        switch Self.decide(documentETag: session.documentETag, templateHash: templateHash) {
        case .render:
            break
        case .failOpen:
            os_log(
                "json carried no templateHash [%{public}@] — rendering without handshake",
                log: .appScreens,
                type: .default,
                session.templatePath
            )
        case .reloadFirst:
            os_log(
                "hash mismatch [%{public}@] documentETag=%{public}@ templateHash=%{public}@ — refetching document",
                log: .appScreens,
                type: .default,
                session.templatePath,
                session.documentETag ?? "(none)",
                templateHash ?? "(none)"
            )
            try await reloadDocument(session: session, entryURL: entryURL)
            if Self.decide(documentETag: session.documentETag, templateHash: templateHash) == .reloadFirst {
                os_log(
                    "hash still mismatched after refetch [%{public}@] documentETag=%{public}@ templateHash=%{public}@ — rendering anyway",
                    log: .appScreens,
                    type: .fault,
                    session.templatePath,
                    session.documentETag ?? "(none)",
                    templateHash ?? "(none)"
                )
            }
        }

        let payload = ShowPayload(href: href, optimisticDataJSON: optimisticDataJSON, responseJSON: rawJSON)
        let hydrateMs = try await withTimeout(seconds: Self.showTimeout) {
            try await self.performShow(session: session, payload: payload)
        }
        os_log(
            "show resolved [%{public}@] hydrateMs=%{public}.1f",
            log: .appScreens,
            type: .info,
            session.templatePath,
            hydrateMs
        )
    }

    /// Refetches the document conditionally, re-boots the runtime, and updates the
    /// captured ETag. Used only by the hash-mismatch path.
    private func reloadDocument(session: AppScreenSession, entryURL: URL) async throws {
        let (html, etag, dataScope) = try await withTimeout(seconds: Self.documentTimeout) {
            try await self.fetchDocument(url: entryURL, cachePolicy: .reloadRevalidatingCacheData)
        }
        session.documentETag = etag
        session.dataScope = dataScope
        os_log(
            "document refetched [%{public}@] etag=%{public}@",
            log: .appScreens,
            type: .info,
            session.templatePath,
            etag ?? "(none)"
        )

        // Re-arm the runtime rendezvous: the fresh `loadHTMLString` re-boots the
        // runtime, which posts `loaded` again.
        session.runtimeDidLoad = false
        session.runtimeLoadedContinuation = nil
        session.state = .awaitingRuntime
        session.webView?.loadHTMLString(html, baseURL: entryURL)

        try await withTimeout(seconds: Self.loadedTimeout) {
            try await self.awaitRuntimeLoaded(session)
        }
        session.state = .ready
    }

    /// Resolves the session's web view then invokes `show()`. Kept separate from
    /// `callShow(on:payload:)` so the timeout wrapper captures only `Sendable`
    /// values (never the web view).
    func performShow(session: AppScreenSession, payload: ShowPayload) async throws -> Double {
        guard let webView = session.webView else {
            throw AppScreenDocumentError.webViewUnavailable
        }
        // Record the payload we are about to render *before* the call, not after:
        // if the process dies mid-`show()` the call rejects, and recovery must
        // replay the full payload we were attempting (optimistic data + `.json` response if it
        // had landed) — not the previous, staler one. On success this simply
        // re-records the same payload.
        session.lastShowPayload = payload
        let hydrateMs = try await callShow(on: webView, payload: payload)
        return hydrateMs
    }

    /// Invokes `window.RoverAppScreens.show(payload)` and returns the runtime's
    /// reported `hydrateMs` (or `-1` if unreported). The function body throws
    /// `rover-appscreens-runtime-missing` if the runtime is absent; `optimisticData`/
    /// `response` are passed as JSON text and `JSON.parse`d only when non-null
    /// (an arguments dictionary avoids all string-interpolation escaping hazards).
    func callShow(on webView: WKWebView, payload: ShowPayload) async throws -> Double {
        let result = try await webView.callAsyncJavaScript(
            Self.showFunctionBody,
            arguments: Self.showArguments(for: payload),
            contentWorld: .page
        )

        if let number = result as? NSNumber {
            return number.doubleValue
        }
        return -1
    }

    /// Assembles the `callAsyncJavaScript` arguments dictionary for a payload.
    /// Absent `optimisticData`/`response` become `NSNull` (JS `null`) so the function body
    /// can `JSON.parse` only the values that are present.
    static func showArguments(for payload: ShowPayload) -> [String: Any] {
        [
            "href": payload.href,
            "optimisticData": payload.optimisticDataJSON ?? NSNull(),
            "response": payload.responseJSON ?? NSNull()
        ]
    }

    private static let showFunctionBody = """
        if (!(window.RoverAppScreens && typeof window.RoverAppScreens.show === 'function')) {
            throw new Error('rover-appscreens-runtime-missing');
        }
        const payload = { href: href };
        if (optimisticData !== null) {
            payload.optimisticData = JSON.parse(optimisticData);
        }
        if (response !== null) {
            payload.response = JSON.parse(response);
        }
        const result = await window.RoverAppScreens.show(payload);
        return (result && typeof result.hydrateMs === 'number') ? result.hydrateMs : -1;
        """
}
