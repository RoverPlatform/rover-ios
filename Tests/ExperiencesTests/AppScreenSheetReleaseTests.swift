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

@testable import RoverData
@testable import RoverExperiences

/// Covers the sheet-flow release path of `AppScreensDriver.release(_:)`: a
/// sheet's flow never registers a session in `rootSessions` (there is no
/// `makeRootHost` call for a sheet, only `makeHost` pushes), so `release` must
/// treat every owned session as a non-root "pushed" detail and route it through
/// `handlePop(of:)`. That returns a warm/template session to the shared `sessions`
/// pool (off-stack, but retained) and tears down an ephemeral session entirely. This
/// is a direct-logic regression guard for `AppScreensTokenBox`'s injected
/// token — no sheet UI is exercised here.
@MainActor
final class AppScreenSheetReleaseTests: XCTestCase {

    private var navigator: AppScreensDriver!
    private let configSuiteName = "io.rover.test.appscreens.sheetRelease.config"

    override func setUp() {
        super.setUp()
        navigator = Self.makeNavigator(configSuiteName: configSuiteName)
    }

    override func tearDown() {
        navigator = nil
        UserDefaults(suiteName: configSuiteName)?.removePersistentDomain(forName: configSuiteName)
        super.tearDown()
    }

    /// Builds a real navigator with throwaway dependencies. Mirrors
    /// `AppScreenMakeHostTests.makeNavigator(configSuiteName:)`.
    private static func makeNavigator(configSuiteName: String) -> AppScreensDriver {
        let authContext = AuthenticationContext(userDefaults: UserDefaults())
        let httpClient = HTTPClient(
            accountToken: "test-token",
            endpoint: URL(string: "https://testbench.rover.io")!,
            engageEndpoint: URL(string: "https://engage.rover.io")!,
            session: .shared,
            authContext: authContext
        )
        let configManager = ConfigManager(userDefaults: UserDefaults(suiteName: configSuiteName)!)
        return AppScreensDriver(
            httpClient: httpClient,
            configManager: configManager,
            associatedDomains: ["testbench.rover.io"],
            eventQueue: nil
        )
    }

    /// A minimal `AppScreensNavigating` conformer: `makeHost` only stores this as
    /// `session.navigating`, so its method bodies are never exercised here.
    private final class FakeNavigating: AppScreensNavigating {
        func pushScreen(address: AppScreenAddress, targetRequest: URLRequest?) {}
        func presentSheet(address: AppScreenAddress, targetRequest: URLRequest?, sheetToken: AppScreensToken) {}
        func presentWebsite(url: URL) {}
        func dismissRoot() {}
    }

    func testReleaseFlowReturnsWarmSheetSessionToPool() throws {
        let token = AppScreensToken()
        let templateKey = "https://testbench.rover.io/a/sheet-detail"
        let address = try XCTUnwrap(AppScreenAddress(rawURL: URL(string: templateKey)!))

        let warmSession = AppScreenSession(
            templateKey: templateKey,
            webView: WKWebView(),
            state: .ready
        )
        warmSession.isOnStack = true
        warmSession.documentURL = address.url
        warmSession.isEphemeral = false
        navigator.sessions[templateKey] = warmSession

        let record = PendingNavigation(
            session: warmSession,
            resolvedURL: address.url,
            optimisticDataJSON: nil,
            isColdLoad: false,
            tapTime: .now()
        )
        navigator.pendingNavigations.enqueue(record, for: address, in: token)

        _ = navigator.makeHost(
            token: token,
            address: address,
            targetRequest: nil,
            navigating: FakeNavigating()
        )

        let registeredSessions = try XCTUnwrap(navigator.sessionsByToken[token])
        XCTAssertTrue(registeredSessions.values.contains { $0 === warmSession })
        XCTAssertFalse(navigator.rootSessions.contains { $0 === warmSession })

        navigator.release(token)

        XCTAssertFalse(warmSession.isOnStack)
        XCTAssertTrue(navigator.sessions[templateKey] === warmSession)
        XCTAssertNil(navigator.sessionsByToken[token])
    }

    func testReleaseFlowTearsDownEphemeralSheetSession() throws {
        let token = AppScreensToken()
        let templateKey = "https://testbench.rover.io/a/sheet-ephemeral-detail"
        let address = try XCTUnwrap(AppScreenAddress(rawURL: URL(string: templateKey)!))

        let ephemeralSession = AppScreenSession(
            templateKey: templateKey,
            webView: WKWebView(),
            state: .ready
        )
        ephemeralSession.isOnStack = true
        ephemeralSession.documentURL = address.url
        ephemeralSession.isEphemeral = true
        navigator.ephemeralSessions.append(ephemeralSession)

        let record = PendingNavigation(
            session: ephemeralSession,
            resolvedURL: address.url,
            optimisticDataJSON: nil,
            isColdLoad: false,
            tapTime: .now()
        )
        navigator.pendingNavigations.enqueue(record, for: address, in: token)

        _ = navigator.makeHost(
            token: token,
            address: address,
            targetRequest: nil,
            navigating: FakeNavigating()
        )

        let registeredSessions = try XCTUnwrap(navigator.sessionsByToken[token])
        XCTAssertTrue(registeredSessions.values.contains { $0 === ephemeralSession })

        navigator.release(token)

        XCTAssertFalse(navigator.ephemeralSessions.contains { $0 === ephemeralSession })
        XCTAssertNil(navigator.sessionsByToken[token])
    }
}
