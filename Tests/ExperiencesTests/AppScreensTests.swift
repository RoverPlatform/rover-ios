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

import XCTest

@testable import RoverExperiences

@MainActor
final class AppScreensTests: XCTestCase {

    // MARK: - ExperienceURLClassifier

    func testClassifyAppScreensHome() {
        let url = URL(string: "https://testbench.rover.io/a/home")!
        XCTAssertEqual(ExperienceURLClassifier.classify(url), .appScreens)
    }

    func testClassifyAppScreensBareA() {
        let url = URL(string: "https://testbench.rover.io/a")!
        XCTAssertEqual(ExperienceURLClassifier.classify(url), .appScreens)
    }

    func testClassifyDocumentAboutIsNotAppScreens() {
        let url = URL(string: "https://testbench.rover.io/about")!
        XCTAssertEqual(ExperienceURLClassifier.classify(url), .document)
    }

    func testClassifyDocumentExperiencesPath() {
        let url = URL(string: "https://testbench.rover.io/experiences/x")!
        XCTAssertEqual(ExperienceURLClassifier.classify(url), .document)
    }

    func testClassifyFileURLIsDocument() {
        let url = URL(fileURLWithPath: "/a/home")
        XCTAssertEqual(ExperienceURLClassifier.classify(url), .document)
    }

    // MARK: - Template path derivation

    func testTemplatePathStripsQuery() {
        let url = URL(string: "https://testbench.rover.io/a/player-detail?id=12")!
        XCTAssertEqual(AppScreensNavigator.templatePath(from: url), "player-detail")
    }

    func testTemplatePathSingleSegment() {
        let url = URL(string: "https://testbench.rover.io/a/home")!
        XCTAssertEqual(AppScreensNavigator.templatePath(from: url), "home")
    }

    func testTemplatePathMultiSegment() {
        let url = URL(string: "https://testbench.rover.io/a/x/y")!
        XCTAssertEqual(AppScreensNavigator.templatePath(from: url), "x/y")
    }

    func testTemplatePathNonAppScreensURLIsNil() {
        let url = URL(string: "https://testbench.rover.io/about")!
        XCTAssertNil(AppScreensNavigator.templatePath(from: url))
    }

    // MARK: - .json URL derivation

    func testJSONURLPreservesQuery() {
        let url = URL(string: "https://testbench.rover.io/a/player-detail?id=12")!
        XCTAssertEqual(
            AppScreensNavigator.jsonURL(from: url)?.absoluteString,
            "https://testbench.rover.io/a/player-detail.json?id=12"
        )
    }

    func testJSONURLNoQuery() {
        let url = URL(string: "https://testbench.rover.io/a/home")!
        XCTAssertEqual(
            AppScreensNavigator.jsonURL(from: url)?.absoluteString,
            "https://testbench.rover.io/a/home.json"
        )
    }

    // MARK: - Relative href

    func testRelativeHrefNoQuery() {
        let url = URL(string: "https://testbench.rover.io/a/home")!
        XCTAssertEqual(AppScreensNavigator.relativeHref(for: url), "/a/home")
    }

    func testRelativeHrefPreservesQuery() {
        let url = URL(string: "https://testbench.rover.io/a/player-detail?id=12")!
        XCTAssertEqual(AppScreensNavigator.relativeHref(for: url), "/a/player-detail?id=12")
    }

    // MARK: - Session selection

    func testSelectSessionWarmOffStackReuses() {
        XCTAssertEqual(
            AppScreensNavigator.selectSession(hasWarmReady: true, isOnStack: false),
            .reuse
        )
    }

    func testSelectSessionOnStackIsEphemeral() {
        // A warm-ready session that is on the stack (detail→detail) must not be
        // disturbed: the navigation gets a one-off ephemeral session.
        XCTAssertEqual(
            AppScreensNavigator.selectSession(hasWarmReady: true, isOnStack: true),
            .ephemeral
        )
    }

    func testSelectSessionOnStackWinsEvenWhenNotReady() {
        XCTAssertEqual(
            AppScreensNavigator.selectSession(hasWarmReady: false, isOnStack: true),
            .ephemeral
        )
    }

    func testSelectSessionMissingIsCold() {
        XCTAssertEqual(
            AppScreensNavigator.selectSession(hasWarmReady: false, isOnStack: false),
            .cold
        )
    }

    // MARK: - Href resolution against the document URL

    func testResolveHrefRelativeSameHost() {
        let document = URL(string: "https://testbench.rover.io/a/home")!
        let resolved = AppScreensNavigator.resolveHref("/a/player-detail?id=3", against: document)
        XCTAssertEqual(resolved?.absoluteString, "https://testbench.rover.io/a/player-detail?id=3")
    }

    func testResolveHrefRelativeFromDetailPreservesHostAndQuery() {
        let document = URL(string: "https://testbench.rover.io/a/player-detail?id=3")!
        let resolved = AppScreensNavigator.resolveHref("/a/player-detail?id=7", against: document)
        XCTAssertEqual(resolved?.absoluteString, "https://testbench.rover.io/a/player-detail?id=7")
    }

    func testResolveHrefAbsoluteSameHost() {
        let document = URL(string: "https://testbench.rover.io/a/home")!
        let resolved = AppScreensNavigator.resolveHref(
            "https://testbench.rover.io/a/standings",
            against: document
        )
        XCTAssertEqual(resolved?.absoluteString, "https://testbench.rover.io/a/standings")
    }

    func testResolveHrefAbsoluteOtherHostStillResolves() {
        let document = URL(string: "https://testbench.rover.io/a/home")!
        let resolved = AppScreensNavigator.resolveHref(
            "https://other.rover.io/a/player-detail?id=9",
            against: document
        )
        XCTAssertEqual(resolved?.absoluteString, "https://other.rover.io/a/player-detail?id=9")
    }

    func testResolveHrefResolvedTemplatePathMatches() {
        let document = URL(string: "https://testbench.rover.io/a/home")!
        let resolved = AppScreensNavigator.resolveHref("/a/player-detail?id=3", against: document)
        XCTAssertEqual(AppScreensNavigator.templatePath(from: resolved!), "player-detail")
    }

    // MARK: - AppScreenMessage decoding

    func testMessageLoaded() {
        XCTAssertEqual(AppScreenMessage(body: ["type": "loaded"]), .loaded)
    }

    func testMessageNavigateWithOptimisticDataRoundTrips() {
        let optimisticData: [String: Any] = ["id": 3, "name": "Ada"]
        let message = AppScreenMessage(body: ["type": "navigate", "href": "/a/x?id=3", "optimisticData": optimisticData]
        )

        guard case .navigate(let href, let optimisticDataJSON, let transition) = message else {
            XCTFail("expected navigate, got \(String(describing: message))")
            return
        }
        XCTAssertEqual(href, "/a/x?id=3")
        XCTAssertNil(transition)

        // Key ordering is not guaranteed, so parse the JSON string back and compare.
        let data = try! XCTUnwrap(optimisticDataJSON?.data(using: .utf8))
        let parsed = try! JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(parsed?["id"] as? Int, 3)
        XCTAssertEqual(parsed?["name"] as? String, "Ada")
    }

    func testMessageNavigateWithoutOptimisticDataIsNil() {
        let message = AppScreenMessage(body: ["type": "navigate", "href": "/a/x"])
        XCTAssertEqual(message, .navigate(href: "/a/x", optimisticDataJSON: nil, transition: nil))
    }

    func testMessageNavigateNSNullOptimisticDataIsNil() {
        let message = AppScreenMessage(body: ["type": "navigate", "href": "/a/x", "optimisticData": NSNull()])
        XCTAssertEqual(message, .navigate(href: "/a/x", optimisticDataJSON: nil, transition: nil))
    }

    func testMessageNavigateMissingHrefIsNil() {
        XCTAssertNil(AppScreenMessage(body: ["type": "navigate"]))
    }

    // MARK: - navigate transition decoding

    func testMessageNavigateTransitionSheet() {
        let message = AppScreenMessage(body: ["type": "navigate", "href": "/a/standings", "transition": "sheet"])
        XCTAssertEqual(message, .navigate(href: "/a/standings", optimisticDataJSON: nil, transition: .sheet))
    }

    func testMessageNavigateTransitionPush() {
        let message = AppScreenMessage(body: ["type": "navigate", "href": "/a/standings", "transition": "push"])
        XCTAssertEqual(message, .navigate(href: "/a/standings", optimisticDataJSON: nil, transition: .push))
    }

    func testMessageNavigateTransitionAbsentIsNil() {
        // Absent transition decodes to nil, which downstream treats as push.
        let message = AppScreenMessage(body: ["type": "navigate", "href": "/a/standings"])
        XCTAssertEqual(message, .navigate(href: "/a/standings", optimisticDataJSON: nil, transition: nil))
    }

    func testMessageNavigateTransitionGarbageIsNil() {
        // An unrecognized value decodes to nil (default-push), never a partial match.
        let message = AppScreenMessage(
            body: ["type": "navigate", "href": "/a/standings", "transition": "modal"]
        )
        XCTAssertEqual(message, .navigate(href: "/a/standings", optimisticDataJSON: nil, transition: nil))
    }

    func testMessageLinksFiltersJunkEntries() {
        let message = AppScreenMessage(
            body: ["type": "links", "hrefs": ["/a/one", 42, NSNull(), "/a/two"]]
        )
        XCTAssertEqual(message, .links(hrefs: ["/a/one", "/a/two"]))
    }

    func testMessageLinksEmptyWhenMissing() {
        XCTAssertEqual(AppScreenMessage(body: ["type": "links"]), .links(hrefs: []))
    }

    func testMessageUnknownTypeIsNil() {
        XCTAssertNil(AppScreenMessage(body: ["type": "ready"]))
    }

    func testMessageMalformedBodyIsNil() {
        XCTAssertNil(AppScreenMessage(body: "not a dictionary"))
        XCTAssertNil(AppScreenMessage(body: ["no": "type"]))
    }

    // MARK: - show() arguments assembly

    func testShowArgumentsPassesNSNullForMissingOptimisticDataAndResponse() {
        let arguments = AppScreensNavigator.showArguments(
            for: ShowPayload(href: "/a/home", optimisticDataJSON: nil, responseJSON: nil)
        )
        XCTAssertEqual(arguments["href"] as? String, "/a/home")
        XCTAssertTrue(arguments["optimisticData"] is NSNull)
        XCTAssertTrue(arguments["response"] is NSNull)
    }

    func testShowArgumentsForwardsRawJSONText() {
        let arguments = AppScreensNavigator.showArguments(
            for: ShowPayload(href: "/a/x", optimisticDataJSON: "{\"a\":1}", responseJSON: "{\"data\":2}")
        )
        XCTAssertEqual(arguments["optimisticData"] as? String, "{\"a\":1}")
        XCTAssertEqual(arguments["response"] as? String, "{\"data\":2}")
    }

    // MARK: - ETag normalization

    func testNormalizeETagQuoted() {
        XCTAssertEqual(AppScreensNavigator.normalizeETag("\"fx-home-v1\""), "fx-home-v1")
    }

    func testNormalizeETagWeak() {
        XCTAssertEqual(AppScreensNavigator.normalizeETag("W/\"fx-home-v1\""), "fx-home-v1")
    }

    func testNormalizeETagBare() {
        XCTAssertEqual(AppScreensNavigator.normalizeETag("fx-home-v1"), "fx-home-v1")
    }

    func testNormalizeETagNil() {
        XCTAssertNil(AppScreensNavigator.normalizeETag(nil))
    }

    func testNormalizeETagWeakWithWhitespace() {
        XCTAssertEqual(AppScreensNavigator.normalizeETag(" W/ \"fx-home-v1\" "), "fx-home-v1")
    }

    // MARK: - Hash handshake decision

    func testHandshakeMatchQuotedETag() {
        XCTAssertEqual(
            AppScreensNavigator.decide(documentETag: "\"fx-home-v1\"", templateHash: "fx-home-v1"),
            .render
        )
    }

    func testHandshakeMatchWeakETag() {
        XCTAssertEqual(
            AppScreensNavigator.decide(documentETag: "W/\"fx-home-v1\"", templateHash: "fx-home-v1"),
            .render
        )
    }

    func testHandshakeMismatchReloadsFirst() {
        XCTAssertEqual(
            AppScreensNavigator.decide(documentETag: "\"fx-home-v1\"", templateHash: "fx-home-v2"),
            .reloadFirst
        )
    }

    func testHandshakeMissingTemplateHashFailsOpen() {
        XCTAssertEqual(
            AppScreensNavigator.decide(documentETag: "\"fx-home-v1\"", templateHash: nil),
            .failOpen
        )
    }

    func testHandshakeEmptyTemplateHashFailsOpen() {
        XCTAssertEqual(
            AppScreensNavigator.decide(documentETag: "\"fx-home-v1\"", templateHash: ""),
            .failOpen
        )
    }

    func testHandshakeMissingDocumentETagReloadsFirst() {
        XCTAssertEqual(
            AppScreensNavigator.decide(documentETag: nil, templateHash: "fx-home-v1"),
            .reloadFirst
        )
    }

    // MARK: - Data scope header parse

    func testDataScopeParsesPublic() {
        XCTAssertEqual(AppScreenDataScope(headerValue: "public"), .public)
    }

    func testDataScopeParsesPersonalized() {
        XCTAssertEqual(AppScreenDataScope(headerValue: "personalized"), .personalized)
    }

    func testDataScopeParseIsCaseInsensitive() {
        XCTAssertEqual(AppScreenDataScope(headerValue: "Public"), .public)
        XCTAssertEqual(AppScreenDataScope(headerValue: "PERSONALIZED"), .personalized)
    }

    func testDataScopeParseTrimsWhitespace() {
        XCTAssertEqual(AppScreenDataScope(headerValue: "  public  "), .public)
        XCTAssertEqual(AppScreenDataScope(headerValue: "\tpersonalized\n"), .personalized)
    }

    func testDataScopeParseUnknownValueIsNil() {
        XCTAssertNil(AppScreenDataScope(headerValue: "private"))
        XCTAssertNil(AppScreenDataScope(headerValue: "   "))
    }

    func testDataScopeParseAbsentIsNil() {
        XCTAssertNil(AppScreenDataScope(headerValue: nil))
    }

    // MARK: - Fail-safe effective scope

    func testEffectiveScopeNilDefaultsToPersonalized() {
        // An older server that advertises no scope must never break personalization,
        // so a missing scope falls back to `.personalized` (today's behavior).
        XCTAssertEqual(AppScreensNavigator.effectiveScope(nil), .personalized)
    }

    func testEffectiveScopePassesThroughKnownScope() {
        XCTAssertEqual(AppScreensNavigator.effectiveScope(.public), .public)
        XCTAssertEqual(AppScreensNavigator.effectiveScope(.personalized), .personalized)
    }

    // MARK: - Stale-hint retry decision

    func testRetryPublicRequestPersonalizedResponseRefetches() {
        // The only combination that retries: a public request whose response says
        // the scope flipped to personalized.
        XCTAssertTrue(
            AppScreensNavigator.shouldRefetchWithIdentifiers(
                requestedScope: .public,
                responseScope: .personalized
            )
        )
    }

    func testRetryPublicRequestPublicResponseDoesNotRefetch() {
        XCTAssertFalse(
            AppScreensNavigator.shouldRefetchWithIdentifiers(
                requestedScope: .public,
                responseScope: .public
            )
        )
    }

    func testRetryPersonalizedRequestNeverRefetches() {
        // A personalized request is already identified — the reverse flip
        // (response says public) just records the new scope, no retry.
        XCTAssertFalse(
            AppScreensNavigator.shouldRefetchWithIdentifiers(
                requestedScope: .personalized,
                responseScope: .public
            )
        )
        XCTAssertFalse(
            AppScreensNavigator.shouldRefetchWithIdentifiers(
                requestedScope: .personalized,
                responseScope: .personalized
            )
        )
    }

    func testRetryAbsentResponseScopeNeverRefetches() {
        // No scope header on the response → nothing to react to, no retry.
        XCTAssertFalse(
            AppScreensNavigator.shouldRefetchWithIdentifiers(
                requestedScope: .public,
                responseScope: nil
            )
        )
        XCTAssertFalse(
            AppScreensNavigator.shouldRefetchWithIdentifiers(
                requestedScope: .personalized,
                responseScope: nil
            )
        )
    }

    // MARK: - templateHash peek

    func testPeekTemplateHashFromSampleJSON() {
        let json = """
            {"data":{"roster":[]},"user":{"name":"Andrew"},"images":{},"params":{},"templateHash":"fx-home-v1"}
            """
        let data = json.data(using: .utf8)!
        XCTAssertEqual(AppScreensNavigator.peekTemplateHash(from: data), "fx-home-v1")
    }

    func testPeekTemplateHashAbsentIsNil() {
        let data = "{\"data\":{}}".data(using: .utf8)!
        XCTAssertNil(AppScreensNavigator.peekTemplateHash(from: data))
    }

    func testPeekTemplateHashMalformedIsNil() {
        let data = "not json".data(using: .utf8)!
        XCTAssertNil(AppScreensNavigator.peekTemplateHash(from: data))
    }

    // MARK: - ShowPayload response forwarding

    func testShowArgumentsForwardsResponseJSON() {
        let raw = "{\"data\":{\"roster\":[]},\"templateHash\":\"fx-home-v1\"}"
        let arguments = AppScreensNavigator.showArguments(
            for: ShowPayload(href: "/a/home", optimisticDataJSON: nil, responseJSON: raw)
        )
        XCTAssertEqual(arguments["response"] as? String, raw)
        XCTAssertTrue(arguments["optimisticData"] is NSNull)
    }

    // MARK: - Prewarm candidate computation

    func testPrewarmCandidatesDistinctInDOMOrder() {
        // The runtime already de-dupes to query-less paths, but the SDK must not
        // depend on that: several player-detail links (with or without ids) collapse
        // to one candidate, DOM order preserved (player-detail before standings).
        let document = URL(string: "https://testbench.rover.io/a/home")!
        let candidates = AppScreensNavigator.prewarmCandidates(
            linkHrefs: [
                "/a/player-detail?id=12",
                "/a/player-detail?id=7",
                "/a/standings",
                "/a/player-detail"
            ],
            documentURL: document,
            existingTemplatePaths: [],
            inflightTemplatePaths: []
        )
        XCTAssertEqual(candidates.map(\.templatePath), ["player-detail", "standings"])
        // Prewarm URLs are param-free.
        XCTAssertEqual(
            candidates.map { $0.documentURL.absoluteString },
            [
                "https://testbench.rover.io/a/player-detail",
                "https://testbench.rover.io/a/standings"
            ]
        )
    }

    func testPrewarmCandidatesExcludesExistingAndInflight() {
        let document = URL(string: "https://testbench.rover.io/a/home")!
        let candidates = AppScreensNavigator.prewarmCandidates(
            linkHrefs: ["/a/player-detail?id=12", "/a/standings", "/a/schedule"],
            documentURL: document,
            existingTemplatePaths: ["player-detail"],
            inflightTemplatePaths: ["standings"]
        )
        // player-detail is already live; standings already in flight; only the
        // genuinely-missing schedule survives.
        XCTAssertEqual(candidates.map(\.templatePath), ["schedule"])
    }

    func testPrewarmCandidatesEmptyWhenNothingMissing() {
        let document = URL(string: "https://testbench.rover.io/a/home")!
        let candidates = AppScreensNavigator.prewarmCandidates(
            linkHrefs: ["/a/player-detail?id=1", "/a/standings"],
            documentURL: document,
            existingTemplatePaths: ["player-detail", "standings"],
            inflightTemplatePaths: []
        )
        XCTAssertTrue(candidates.isEmpty)
    }

    func testPrewarmCandidatesResolvesAgainstDetailDocument() {
        // A links hint from a detail screen resolves relative hrefs against the
        // detail's document URL, and still yields param-free prewarm URLs.
        let document = URL(string: "https://testbench.rover.io/a/player-detail?id=3")!
        let candidates = AppScreensNavigator.prewarmCandidates(
            linkHrefs: ["/a/player-detail?id=9", "/a/standings"],
            documentURL: document,
            existingTemplatePaths: ["player-detail"],
            inflightTemplatePaths: []
        )
        XCTAssertEqual(candidates.map(\.templatePath), ["standings"])
        XCTAssertEqual(
            candidates.first?.documentURL.absoluteString,
            "https://testbench.rover.io/a/standings"
        )
    }

    // MARK: - Prewarm URL construction (param-free)

    func testPrewarmURLStripsQuery() {
        let resolved = URL(string: "https://testbench.rover.io/a/player-detail?id=12")!
        XCTAssertEqual(
            AppScreensNavigator.prewarmURL(templatePath: "player-detail", relativeTo: resolved)?
                .absoluteString,
            "https://testbench.rover.io/a/player-detail"
        )
    }

    func testPrewarmURLNoQueryUnchanged() {
        let resolved = URL(string: "https://testbench.rover.io/a/standings")!
        XCTAssertEqual(
            AppScreensNavigator.prewarmURL(templatePath: "standings", relativeTo: resolved)?
                .absoluteString,
            "https://testbench.rover.io/a/standings"
        )
    }

    func testPrewarmURLStripsFragment() {
        let resolved = URL(string: "https://testbench.rover.io/a/player-detail?id=12#stats")!
        XCTAssertEqual(
            AppScreensNavigator.prewarmURL(templatePath: "player-detail", relativeTo: resolved)?
                .absoluteString,
            "https://testbench.rover.io/a/player-detail"
        )
    }

    // MARK: - PrewarmAttachStrategy

    func testPrewarmAttachStrategyDefaultsToOffscreenWindow() {
        // The offscreen-window prewarm keeps a live accessibility tree, so it is the
        // default; `.unattached` stays available behind the flag.
        XCTAssertEqual(AppScreensNavigator.prewarmAttachStrategy, .offscreenWindow)
    }

    // MARK: - Recovery decision (liveness + occluded deferral)

    func testRecoveryActionVisibleFreshBudgetRecovers() {
        // A visible session that has not yet used its per-navigation recovery
        // budget reloads once and replays.
        XCTAssertEqual(
            AppScreensNavigator.recoveryAction(visibility: .visible, didAttemptRecovery: false),
            .recover
        )
    }

    func testRecoveryActionVisibleSpentBudgetFails() {
        // A visible session that already recovered this navigation must not loop —
        // it surfaces the retry error state instead.
        XCTAssertEqual(
            AppScreensNavigator.recoveryAction(visibility: .visible, didAttemptRecovery: true),
            .failure
        )
    }

    func testRecoveryActionOccludedDefers() {
        // An occluded (on-stack but not top) session can't boot its runtime
        // off-screen, so recovery is deferred until it becomes visible — regardless
        // of the recovery budget.
        XCTAssertEqual(
            AppScreensNavigator.recoveryAction(visibility: .occluded, didAttemptRecovery: false),
            .defer_
        )
        XCTAssertEqual(
            AppScreensNavigator.recoveryAction(visibility: .occluded, didAttemptRecovery: true),
            .defer_
        )
    }

    func testRecoveryActionOffStackTearsDown() {
        // An idle, off-stack warm/prewarming session whose process died is torn
        // down so the next tap takes the cold path.
        XCTAssertEqual(
            AppScreensNavigator.recoveryAction(visibility: .offStack, didAttemptRecovery: false),
            .teardown
        )
    }

    func testRecoveryActionOffStackTearsDownRegardlessOfBudget() {
        // Off-stack always tears down; the recovery budget only matters when visible.
        XCTAssertEqual(
            AppScreensNavigator.recoveryAction(visibility: .offStack, didAttemptRecovery: true),
            .teardown
        )
    }

    // MARK: - withTimeout

    func testWithTimeoutReturnsValueWhenFast() async throws {
        let value = try await withTimeout(seconds: 1) { 42 }
        XCTAssertEqual(value, 42)
    }

    func testWithTimeoutThrowsWhenSlow() async {
        do {
            _ = try await withTimeout(seconds: 0.05) {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                return 1
            }
            XCTFail("expected a timeout")
        } catch is AppScreenTimeoutError {
            // expected
        } catch {
            XCTFail("expected AppScreenTimeoutError, got \(error)")
        }
    }
}
