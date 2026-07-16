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

    // MARK: - Origin-qualified template key derivation

    func testTemplateKeyComposesOriginAndPath() {
        let url = URL(string: "https://testbench.rover.io/a/player-detail")!
        XCTAssertEqual(
            AppScreensNavigator.templateKey(from: url),
            "https://testbench.rover.io/a/player-detail"
        )
    }

    func testTemplateKeyDistinguishesAssociatedDomains() {
        // The whole point of the key: the same bare path on two associated domains
        // must produce two distinct identities so they never share a warm web view.
        let a = URL(string: "https://a.example/a/detail")!
        let b = URL(string: "https://b.example/a/detail")!
        XCTAssertEqual(AppScreensNavigator.templateKey(from: a), "https://a.example/a/detail")
        XCTAssertEqual(AppScreensNavigator.templateKey(from: b), "https://b.example/a/detail")
        XCTAssertNotEqual(
            AppScreensNavigator.templateKey(from: a),
            AppScreensNavigator.templateKey(from: b)
        )
    }

    func testTemplateKeyLowercasesSchemeAndHost() {
        let url = URL(string: "HTTPS://TestBench.Rover.IO/a/home")!
        XCTAssertEqual(
            AppScreensNavigator.templateKey(from: url),
            "https://testbench.rover.io/a/home"
        )
    }

    func testTemplateKeyKeepsExplicitPort() {
        let url = URL(string: "https://testbench.rover.io:8443/a/home")!
        XCTAssertEqual(
            AppScreensNavigator.templateKey(from: url),
            "https://testbench.rover.io:8443/a/home"
        )
    }

    func testTemplateKeyOmitsDefaultPort() {
        // An explicit default port (:443 for https) is dropped by URL.port, so it is
        // absent from the key — `https://host` and `https://host:443` are one origin.
        let url = URL(string: "https://testbench.rover.io:443/a/home")!
        XCTAssertEqual(
            AppScreensNavigator.templateKey(from: url),
            "https://testbench.rover.io/a/home"
        )
    }

    func testTemplateKeyExcludesQueryAndFragment() {
        let url = URL(string: "https://testbench.rover.io/a/player-detail?id=12#stats")!
        XCTAssertEqual(
            AppScreensNavigator.templateKey(from: url),
            "https://testbench.rover.io/a/player-detail"
        )
    }

    func testTemplateKeyMultiSegmentPath() {
        let url = URL(string: "https://testbench.rover.io/a/x/y?z=1")!
        XCTAssertEqual(
            AppScreensNavigator.templateKey(from: url),
            "https://testbench.rover.io/a/x/y"
        )
    }

    func testTemplateKeyNonAppScreensURLIsNil() {
        let url = URL(string: "https://testbench.rover.io/about")!
        XCTAssertNil(AppScreensNavigator.templateKey(from: url))
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

    func testMessageRefresh() {
        XCTAssertEqual(AppScreenMessage(body: ["type": "refresh"]), .refresh)
    }

    func testMessageRefreshIgnoresStrayFields() {
        // A bare `refresh` carries no payload; any extra fields a runtime tacks on are
        // ignored and the message still decodes to `.refresh`.
        let message = AppScreenMessage(
            body: ["type": "refresh", "href": "/a/live", "count": 3, "extra": NSNull()]
        )
        XCTAssertEqual(message, .refresh)
    }

    func testMessageNavigateWithOptimisticDataRoundTrips() {
        let optimisticData: [String: Any] = ["id": 3, "name": "Ada"]
        let message = AppScreenMessage(body: [
            "type": "navigate", "href": "/a/x?id=3", "optimisticData": optimisticData
        ]
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

    // MARK: - openURL decoding

    func testMessageOpenURLDismissTrue() {
        let message = AppScreenMessage(
            body: ["type": "openURL", "href": "https://example.com/x", "dismiss": true]
        )
        XCTAssertEqual(message, .openURL(href: "https://example.com/x", dismiss: true))
    }

    func testMessageOpenURLDismissAbsentIsFalse() {
        let message = AppScreenMessage(body: ["type": "openURL", "href": "https://example.com/x"])
        XCTAssertEqual(message, .openURL(href: "https://example.com/x", dismiss: false))
    }

    func testMessageOpenURLDismissNonBoolIsFalse() {
        // A non-`Bool` dismiss (e.g. the string "yes") decodes to a plain open.
        let message = AppScreenMessage(
            body: ["type": "openURL", "href": "https://example.com/x", "dismiss": "yes"]
        )
        XCTAssertEqual(message, .openURL(href: "https://example.com/x", dismiss: false))
    }

    func testMessageOpenURLDismissNumericOneIsFalse() {
        // A `WKScriptMessage` body delivers JS numbers as `NSNumber`, and
        // `NSNumber(value: 1) as? Bool` succeeds via Foundation bridging. Decoding
        // must reject a numeric `1` (only a real JSON boolean sets `dismiss`),
        // matching Android's `JSONObject.optBoolean`. An explicit `NSNumber` is
        // required here: a plain Swift `1` literal in `[String: Any]` does not bridge
        // to `Bool` via `as?`, so it would not reproduce the bug.
        let message = AppScreenMessage(
            body: ["type": "openURL", "href": "https://example.com/x", "dismiss": NSNumber(value: 1)]
        )
        XCTAssertEqual(message, .openURL(href: "https://example.com/x", dismiss: false))
    }

    func testMessageOpenURLDismissNumericZeroIsFalse() {
        let message = AppScreenMessage(
            body: ["type": "openURL", "href": "https://example.com/x", "dismiss": NSNumber(value: 0)]
        )
        XCTAssertEqual(message, .openURL(href: "https://example.com/x", dismiss: false))
    }

    func testMessageOpenURLMissingHrefIsNil() {
        XCTAssertNil(AppScreenMessage(body: ["type": "openURL", "dismiss": true]))
    }

    func testMessageOpenURLNonStringHrefIsNil() {
        XCTAssertNil(AppScreenMessage(body: ["type": "openURL", "href": 42]))
    }

    func testMessageOpenURLCustomSchemeHrefDecodes() {
        // `openURL` targets arbitrary external URLs and custom-scheme deep links, so a
        // non-http(s) href still decodes (authorization is not applied to openURL).
        let message = AppScreenMessage(body: ["type": "openURL", "href": "myapp://profile/42"])
        XCTAssertEqual(message, .openURL(href: "myapp://profile/42", dismiss: false))
    }

    // MARK: - presentWebsite decoding

    func testMessagePresentWebsiteValid() {
        let message = AppScreenMessage(body: ["type": "presentWebsite", "href": "https://example.com/x"])
        XCTAssertEqual(message, .presentWebsite(href: "https://example.com/x"))
    }

    func testMessagePresentWebsiteMissingHrefIsNil() {
        XCTAssertNil(AppScreenMessage(body: ["type": "presentWebsite"]))
    }

    func testMessagePresentWebsiteNonStringHrefIsNil() {
        XCTAssertNil(AppScreenMessage(body: ["type": "presentWebsite", "href": 42]))
    }

    // MARK: - externalURL(from:against:)

    private let externalBase = URL(string: "https://testbench.rover.io/a/home")!

    func testExternalURLAbsoluteHTTPSPassesThrough() {
        XCTAssertEqual(
            AppScreensNavigator.externalURL(from: "https://example.com/x?id=3", against: externalBase),
            URL(string: "https://example.com/x?id=3")
        )
    }

    func testExternalURLPreservesCustomScheme() {
        // Deep links are the point of `openURL` — a custom scheme survives untouched.
        XCTAssertEqual(
            AppScreensNavigator.externalURL(from: "myapp://profile/42", against: externalBase),
            URL(string: "myapp://profile/42")
        )
    }

    func testExternalURLPreservesOpaqueMailto() {
        XCTAssertEqual(
            AppScreensNavigator.externalURL(from: "mailto:x@y.com", against: externalBase),
            URL(string: "mailto:x@y.com")
        )
    }

    func testExternalURLTrimsWhitespace() {
        // The WHATWG parser strips leading/trailing whitespace; Foundation's does not,
        // so the decision function trims before parsing.
        XCTAssertEqual(
            AppScreensNavigator.externalURL(from: "  https://example.com  ", against: externalBase),
            URL(string: "https://example.com")
        )
    }

    func testExternalURLRootRelativePathResolves() {
        // Browser `<a href>` semantics: a root-relative path lands on the document's
        // domain — this is what lets openURL reach other experiences by path.
        XCTAssertEqual(
            AppScreensNavigator.externalURL(from: "/promo", against: externalBase),
            URL(string: "https://testbench.rover.io/promo")
        )
    }

    func testExternalURLProtocolRelativeInheritsScheme() {
        XCTAssertEqual(
            AppScreensNavigator.externalURL(from: "//example.com/path", against: externalBase),
            URL(string: "https://example.com/path")
        )
    }

    func testExternalURLBareHostnameResolvesAsRelativePath() {
        // Per the URL standard a scheme-less `www.example.com` is a relative path,
        // not a host — deliberately no address-bar-style host guessing.
        XCTAssertEqual(
            AppScreensNavigator.externalURL(from: "www.example.com", against: externalBase),
            URL(string: "https://testbench.rover.io/a/www.example.com")
        )
    }

    func testExternalURLBlankIsNil() {
        XCTAssertNil(AppScreensNavigator.externalURL(from: "", against: externalBase))
        XCTAssertNil(AppScreensNavigator.externalURL(from: "   ", against: externalBase))
    }

    // MARK: - safariPresentableURL

    func testSafariPresentableURLHTTPPassesThrough() {
        let url = URL(string: "http://example.com/x")!
        XCTAssertEqual(AppScreensNavigator.safariPresentableURL(url), url)
    }

    func testSafariPresentableURLHTTPSPassesThrough() {
        let url = URL(string: "https://example.com/x")!
        XCTAssertEqual(AppScreensNavigator.safariPresentableURL(url), url)
    }

    func testSafariPresentableURLCustomSchemeCoercedToHTTPS() {
        let url = URL(string: "myapp://example.com/x")!
        XCTAssertEqual(
            AppScreensNavigator.safariPresentableURL(url),
            URL(string: "https://example.com/x")
        )
    }

    func testSafariPresentableURLUppercaseSchemeTreatedAsHTTPS() {
        // A case-insensitive https scheme is recognized as http(s) and passed through
        // unchanged (not re-coerced).
        let url = URL(string: "HTTPS://example.com/x")!
        XCTAssertEqual(AppScreensNavigator.safariPresentableURL(url), url)
    }

    func testSafariPresentableURLMailtoIsNil() {
        // A hostless URL is not presentable even after coercion.
        let url = URL(string: "mailto:x@y.com")!
        XCTAssertNil(AppScreensNavigator.safariPresentableURL(url))
    }

    func testSafariPresentableURLNoHostIsNil() {
        let url = URL(string: "tel:+15551234567")!
        XCTAssertNil(AppScreensNavigator.safariPresentableURL(url))
    }

    func testSafariPresentableURLRejectsJavascriptScheme() {
        let url = URL(string: "javascript:alert(1)")!
        XCTAssertNil(AppScreensNavigator.safariPresentableURL(url))
    }

    func testSafariPresentableURLRejectsFileScheme() {
        // `file:///…` has an empty authority — coercion must not yield an https URL.
        let url = URL(string: "file:///etc/passwd")!
        XCTAssertNil(AppScreensNavigator.safariPresentableURL(url))
    }

    func testSafariPresentableURLRejectsDataScheme() {
        let url = URL(string: "data:text/html,hello")!
        XCTAssertNil(AppScreensNavigator.safariPresentableURL(url))
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

    // MARK: - Eager-fetch reconcile decision

    func testReconcileMatchingScopesDoNotRestart() {
        // The eager guess matched the document's scope → consume the concurrent
        // result, nothing to reconcile.
        XCTAssertFalse(
            AppScreensNavigator.shouldRestartEagerFetch(
                eagerScope: .public,
                effectiveScope: .public
            )
        )
        XCTAssertFalse(
            AppScreensNavigator.shouldRestartEagerFetch(
                eagerScope: .personalized,
                effectiveScope: .personalized
            )
        )
    }

    func testReconcilePersonalizedEagerPublicDocumentRestarts() {
        // A stale personalized eager fetch sent identifiers to a now-public
        // screen → discard and refetch bare.
        XCTAssertTrue(
            AppScreensNavigator.shouldRestartEagerFetch(
                eagerScope: .personalized,
                effectiveScope: .public
            )
        )
    }

    func testReconcilePublicEagerPersonalizedDocumentRestarts() {
        // A stale public eager fetch against a now-personalized screen → discard
        // and refetch with identifiers.
        XCTAssertTrue(
            AppScreensNavigator.shouldRestartEagerFetch(
                eagerScope: .public,
                effectiveScope: .personalized
            )
        )
    }

    func testReconcileNilEagerScopeNeverRestarts() {
        // No concurrent fetch started (the fetch waited for the document) →
        // nothing to reconcile, either document scope.
        XCTAssertFalse(
            AppScreensNavigator.shouldRestartEagerFetch(
                eagerScope: nil,
                effectiveScope: .public
            )
        )
        XCTAssertFalse(
            AppScreensNavigator.shouldRestartEagerFetch(
                eagerScope: nil,
                effectiveScope: .personalized
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
            existingTemplateKeys: [],
            inflightTemplateKeys: [],
            allowedHosts: ["testbench.rover.io"]
        )
        // Candidate identity is the origin-qualified key, not the bare path.
        XCTAssertEqual(
            candidates.map(\.templateKey),
            [
                "https://testbench.rover.io/a/player-detail",
                "https://testbench.rover.io/a/standings"
            ]
        )
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
            existingTemplateKeys: ["https://testbench.rover.io/a/player-detail"],
            inflightTemplateKeys: ["https://testbench.rover.io/a/standings"],
            allowedHosts: ["testbench.rover.io"]
        )
        // player-detail is already live; standings already in flight; only the
        // genuinely-missing schedule survives.
        XCTAssertEqual(candidates.map(\.templateKey), ["https://testbench.rover.io/a/schedule"])
    }

    func testPrewarmCandidatesEmptyWhenNothingMissing() {
        let document = URL(string: "https://testbench.rover.io/a/home")!
        let candidates = AppScreensNavigator.prewarmCandidates(
            linkHrefs: ["/a/player-detail?id=1", "/a/standings"],
            documentURL: document,
            existingTemplateKeys: [
                "https://testbench.rover.io/a/player-detail",
                "https://testbench.rover.io/a/standings"
            ],
            inflightTemplateKeys: [],
            allowedHosts: ["testbench.rover.io"]
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
            existingTemplateKeys: ["https://testbench.rover.io/a/player-detail"],
            inflightTemplateKeys: [],
            allowedHosts: ["testbench.rover.io"]
        )
        XCTAssertEqual(candidates.map(\.templateKey), ["https://testbench.rover.io/a/standings"])
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

    // MARK: - bridgeMessageAllowed

    func testBridgeMessageMainFrameSameOriginAccepted() {
        // The expected main frame at the session's own origin is honored.
        let document = URL(string: "https://testbench.rover.io/a/home")!
        XCTAssertTrue(
            AppScreensNavigator.bridgeMessageAllowed(
                isMainFrame: true,
                originProtocol: "https",
                originHost: "testbench.rover.io",
                originPort: 0,
                documentURL: document
            )
        )
    }

    func testBridgeMessageSubframeRejected() {
        // No App Screens runtime posts from a subframe; a same-origin iframe is
        // still rejected purely on the main-frame check.
        let document = URL(string: "https://testbench.rover.io/a/home")!
        XCTAssertFalse(
            AppScreensNavigator.bridgeMessageAllowed(
                isMainFrame: false,
                originProtocol: "https",
                originHost: "testbench.rover.io",
                originPort: 0,
                documentURL: document
            )
        )
    }

    func testBridgeMessageCrossHostRejected() {
        // A main frame that has navigated to another host cannot post.
        let document = URL(string: "https://testbench.rover.io/a/home")!
        XCTAssertFalse(
            AppScreensNavigator.bridgeMessageAllowed(
                isMainFrame: true,
                originProtocol: "https",
                originHost: "evil.example.com",
                originPort: 0,
                documentURL: document
            )
        )
    }

    func testBridgeMessageCrossSchemeRejected() {
        // A scheme downgrade (http vs the document's https) is a different origin.
        let document = URL(string: "https://testbench.rover.io/a/home")!
        XCTAssertFalse(
            AppScreensNavigator.bridgeMessageAllowed(
                isMainFrame: true,
                originProtocol: "http",
                originHost: "testbench.rover.io",
                originPort: 0,
                documentURL: document
            )
        )
    }

    func testBridgeMessageExplicitMatchingPortAccepted() {
        // A matching explicit non-default port is accepted.
        let document = URL(string: "https://testbench.rover.io:8443/a/home")!
        XCTAssertTrue(
            AppScreensNavigator.bridgeMessageAllowed(
                isMainFrame: true,
                originProtocol: "https",
                originHost: "testbench.rover.io",
                originPort: 8443,
                documentURL: document
            )
        )
    }

    func testBridgeMessageMismatchedPortRejected() {
        // A different explicit port is a different origin.
        let document = URL(string: "https://testbench.rover.io:8443/a/home")!
        XCTAssertFalse(
            AppScreensNavigator.bridgeMessageAllowed(
                isMainFrame: true,
                originProtocol: "https",
                originHost: "testbench.rover.io",
                originPort: 9443,
                documentURL: document
            )
        )
    }

    func testBridgeMessageDefaultPortEquivalence() {
        // WKSecurityOrigin reports 0 for a default port and URL.port is nil for a
        // default port; both normalize to the scheme default and compare equal.
        let document = URL(string: "https://testbench.rover.io/a/home")!
        XCTAssertTrue(
            AppScreensNavigator.bridgeMessageAllowed(
                isMainFrame: true,
                originProtocol: "https",
                originHost: "testbench.rover.io",
                originPort: 0,
                documentURL: document
            )
        )
    }

    func testBridgeMessageHttpsExplicit443MatchesDefault() {
        // A document URL carrying an explicit `:443` is the same origin as an
        // origin whose port normalizes to the https default (0 → 443).
        let document = URL(string: "https://testbench.rover.io:443/a/home")!
        XCTAssertTrue(
            AppScreensNavigator.bridgeMessageAllowed(
                isMainFrame: true,
                originProtocol: "https",
                originHost: "testbench.rover.io",
                originPort: 0,
                documentURL: document
            )
        )
    }

    func testBridgeMessageHostMatchIsCaseInsensitive() {
        // Host comparison is case-insensitive, matching origin semantics.
        let document = URL(string: "https://Testbench.Rover.IO/a/home")!
        XCTAssertTrue(
            AppScreensNavigator.bridgeMessageAllowed(
                isMainFrame: true,
                originProtocol: "https",
                originHost: "testbench.rover.io",
                originPort: 0,
                documentURL: document
            )
        )
    }

    // MARK: - Navigation authorization

    private static let navAllowedHosts: Set<String> = ["testbench.rover.io"]

    func testAuthorizedTargetAcceptsAppScreenOnAssociatedDomain() {
        // The happy path: an `/a/{template}` https URL on an associated domain is
        // authorized, and its normalized URL + template path come back.
        let resolved = URL(string: "https://testbench.rover.io/a/player-detail?id=3")!
        let target = AppScreensNavigator.authorizedTarget(
            resolvedURL: resolved,
            allowedHosts: Self.navAllowedHosts
        )
        XCTAssertEqual(
            target,
            AppScreensNavigator.AuthorizedTarget(
                url: URL(string: "https://testbench.rover.io/a/player-detail?id=3")!,
                templatePath: "player-detail"
            )
        )
    }

    func testAuthorizedTargetRejectsForeignHost() {
        // A screen navigating to an attacker host is rejected — this is the leak the
        // fix closes (personalized `.json` would carry the account token + identifiers).
        let resolved = URL(string: "https://attacker.example/a/x")!
        XCTAssertNil(
            AppScreensNavigator.authorizedTarget(
                resolvedURL: resolved,
                allowedHosts: Self.navAllowedHosts
            )
        )
    }

    func testAuthorizedTargetUpgradesHttpToHttps() {
        // An http target on an associated domain is upgraded to https (mirroring the
        // entry point) rather than rejected.
        let resolved = URL(string: "http://testbench.rover.io/a/home")!
        let target = AppScreensNavigator.authorizedTarget(
            resolvedURL: resolved,
            allowedHosts: Self.navAllowedHosts
        )
        XCTAssertEqual(target?.url.absoluteString, "https://testbench.rover.io/a/home")
        XCTAssertEqual(target?.templatePath, "home")
    }

    func testAuthorizedTargetRejectsCustomScheme() {
        // A non-http(s) scheme (e.g. a deep-link custom scheme reaching the bridge)
        // is rejected outright.
        let resolved = URL(string: "rv-testbench://testbench.rover.io/a/home")!
        XCTAssertNil(
            AppScreensNavigator.authorizedTarget(
                resolvedURL: resolved,
                allowedHosts: Self.navAllowedHosts
            )
        )
    }

    func testAuthorizedTargetRejectsNonAppScreenPath() {
        // A URL on the associated domain that is not an `/a/{template}` document is
        // rejected — no more `?? resolvedURL.path` fallback turning it into a template.
        let resolved = URL(string: "https://testbench.rover.io/settings/account")!
        XCTAssertNil(
            AppScreensNavigator.authorizedTarget(
                resolvedURL: resolved,
                allowedHosts: Self.navAllowedHosts
            )
        )
    }

    func testAuthorizedTargetHostMatchIsCaseInsensitive() {
        // Host comparison is case-insensitive against the (lowercased) allowed set.
        let resolved = URL(string: "https://TestBench.Rover.IO/a/home")!
        let target = AppScreensNavigator.authorizedTarget(
            resolvedURL: resolved,
            allowedHosts: Self.navAllowedHosts
        )
        XCTAssertEqual(target?.templatePath, "home")
    }

    // MARK: - Prewarm domain filtering

    func testPrewarmCandidatesDropForeignHost() {
        // A `links` hint carrying an absolute href to another host is not prewarmed,
        // even though it is a well-formed `/a/{template}` URL.
        let document = URL(string: "https://testbench.rover.io/a/home")!
        let candidates = AppScreensNavigator.prewarmCandidates(
            linkHrefs: ["https://attacker.example/a/evil", "/a/standings"],
            documentURL: document,
            existingTemplateKeys: [],
            inflightTemplateKeys: [],
            allowedHosts: ["testbench.rover.io"]
        )
        XCTAssertEqual(candidates.map(\.templateKey), ["https://testbench.rover.io/a/standings"])
    }

    // MARK: - Main-frame navigation policy

    func testMainFrameNavigationAllowsNativeDocumentLoad() {
        // The native `loadHTMLString(_:baseURL:)` arrives as a `.other` action whose
        // request URL equals the session's documentURL — allowed.
        let documentURL = URL(string: "https://testbench.rover.io/a/home")!
        XCTAssertTrue(
            AppScreensNavigator.mainFrameNavigationAllowed(
                isMainFrame: true,
                isOtherNavigationType: true,
                requestURL: documentURL,
                documentURL: documentURL
            )
        )
    }

    func testMainFrameNavigationDeniesLinkActivated() {
        // A main-frame link tap (not `.other`) to the same document is still denied —
        // main-frame navigation is only ever native.
        let documentURL = URL(string: "https://testbench.rover.io/a/home")!
        XCTAssertFalse(
            AppScreensNavigator.mainFrameNavigationAllowed(
                isMainFrame: true,
                isOtherNavigationType: false,
                requestURL: documentURL,
                documentURL: documentURL
            )
        )
    }

    func testMainFrameNavigationDeniesForeignOtherNavigation() {
        // A scripted `location.href` to a foreign URL arrives as `.other`, but its
        // URL does not match the documentURL — denied.
        let documentURL = URL(string: "https://testbench.rover.io/a/home")!
        XCTAssertFalse(
            AppScreensNavigator.mainFrameNavigationAllowed(
                isMainFrame: true,
                isOtherNavigationType: true,
                requestURL: URL(string: "https://attacker.example/phish"),
                documentURL: documentURL
            )
        )
    }

    func testMainFrameNavigationAllowsSubframe() {
        // A non-main-frame action (an iframe loading its own content) is allowed,
        // regardless of its URL.
        let documentURL = URL(string: "https://testbench.rover.io/a/home")!
        XCTAssertTrue(
            AppScreensNavigator.mainFrameNavigationAllowed(
                isMainFrame: false,
                isOtherNavigationType: false,
                requestURL: URL(string: "https://ads.example/frame"),
                documentURL: documentURL
            )
        )
    }

    func testMainFrameNavigationAllowsAboutBlank() {
        // `about:blank` (and a nil request URL) are native artifacts of the load and
        // are allowed.
        let documentURL = URL(string: "https://testbench.rover.io/a/home")!
        XCTAssertTrue(
            AppScreensNavigator.mainFrameNavigationAllowed(
                isMainFrame: true,
                isOtherNavigationType: true,
                requestURL: URL(string: "about:blank"),
                documentURL: documentURL
            )
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

    // MARK: - applyScreenBackground

    /// Asserts two colors match by resolved RGBA components. The web view re-tags an
    /// assigned color into its own color space (e.g. device RGB vs extended sRGB/gray),
    /// so `UIColor ==` fails even when the components are identical; comparing
    /// components resolved against the same traits is the reliable check.
    private func assertSameColor(
        _ actual: UIColor?,
        _ expected: UIColor?,
        traits: UITraitCollection,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        func components(_ color: UIColor?) -> [CGFloat]? {
            guard let color else {
                return nil
            }
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return [red, green, blue, alpha]
        }
        guard let actualComponents = components(actual), let expectedComponents = components(expected) else {
            XCTFail("expected both colors to be non-nil and RGBA-convertible", file: file, line: line)
            return
        }
        for (actualComponent, expectedComponent) in zip(actualComponents, expectedComponents) {
            XCTAssertEqual(actualComponent, expectedComponent, accuracy: 0.0001, file: file, line: line)
        }
    }

    func testApplyScreenBackgroundUsesDeclaredColorOnEverySurface() {
        let webView = WKWebView(frame: .zero)
        let declared = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)

        AppScreenSession.applyScreenBackground(declared, to: webView)

        let traits = webView.traitCollection
        assertSameColor(webView.backgroundColor, declared, traits: traits)
        assertSameColor(webView.scrollView.backgroundColor, declared, traits: traits)
        assertSameColor(webView.underPageBackgroundColor, declared, traits: traits)
    }

    func testApplyScreenBackgroundFallsBackToSystemBackgroundWhenUndeclared() {
        let webView = WKWebView(frame: .zero)
        webView.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
        webView.scrollView.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
        webView.underPageBackgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)

        AppScreenSession.applyScreenBackground(nil, to: webView)

        let traits = webView.traitCollection
        assertSameColor(webView.backgroundColor, .systemBackground, traits: traits)
        assertSameColor(webView.scrollView.backgroundColor, .systemBackground, traits: traits)
        assertSameColor(webView.underPageBackgroundColor, .systemBackground, traits: traits)
    }

}
