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

/// Covers `AppScreensSheetHostView`'s make-host seam directly: its production
/// `makeScreen` claims a screen (sheet root or an in-sheet push) via
/// `AppScreensDriver.makeHost` under the flow token INJECTED into the sheet's own
/// `AppScreensTokenBox` — never the presenting flow's token. This is exercised as
/// direct navigator/store logic rather than through SwiftUI rendering: `.sheet` /
/// `.onAppear` / `@StateObject`-teardown unit tests are non-deterministic in this
/// headless SPM test bundle. Real sheet presentation, auto-dismiss on path change,
/// and box teardown are validated manually in Testbench.
@MainActor
final class AppScreenSheetHostingTests: XCTestCase {

    private var navigator: AppScreensDriver!
    private let configSuiteName = "io.rover.test.appscreens.sheetHosting.config"

    override func setUp() {
        super.setUp()
        navigator = Self.makeNavigator(configSuiteName: configSuiteName)
    }

    override func tearDown() {
        navigator = nil
        UserDefaults(suiteName: configSuiteName)?.removePersistentDomain(forName: configSuiteName)
        super.tearDown()
    }

    /// Builds a real navigator with throwaway dependencies. `makeHost` never touches
    /// the HTTP/config layers directly (the pipeline it starts would, but the test
    /// only asserts the task was started, not awaited to completion).
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

    func testFlowBoxExposesInjectedSheetToken() {
        let token = AppScreensToken()
        let box = AppScreensTokenBox(navigator: navigator, token: token, isSheet: true)
        XCTAssertEqual(box.token, token)
    }

    func testSheetContainerMakeScreenClaimsSheetRootUnderInjectedToken() throws {
        let sheetToken = AppScreensToken()
        let address = try XCTUnwrap(
            AppScreenAddress(rawURL: URL(string: "https://testbench.rover.io/a/sheet-root")!)
        )

        let session = AppScreenSession(
            templateKey: "https://testbench.rover.io/a/sheet-root",
            webView: WKWebView(),
            state: .ready
        )
        session.isOnStack = true
        session.documentURL = address.url

        let record = PendingNavigation(
            session: session,
            resolvedURL: address.url,
            optimisticDataJSON: nil,
            isColdLoad: false,
            tapTime: .now()
        )
        navigator.pendingNavigations.enqueue(record, for: address, in: sheetToken)

        // Mirrors `AppScreensSheetHostView`'s own `makeScreen`: every role claims via
        // `makeHost` under the injected sheet token.
        let makeScreen: (AppScreensPageRequest) -> UIViewController = { request in
            self.navigator.makeHost(
                token: sheetToken,
                address: request.address,
                targetRequest: request.targetRequest,
                navigating: request.navigating
            )
        }

        let host = makeScreen(
            AppScreensPageRequest(
                role: .sheetRoot,
                address: address,
                targetRequest: nil,
                navigating: FakeNavigating()
            )
        )

        let hostViewController = try XCTUnwrap(host as? AppScreensPageViewController)
        XCTAssertTrue(session.hostViewController === hostViewController)
        XCTAssertEqual(session.token, sheetToken)
        XCTAssertNotNil(session.pipelineTask)
    }

    func testSheetContainerMakeScreenClaimsInSheetPushUnderSameToken() throws {
        let sheetToken = AppScreensToken()
        let detailAddress = try XCTUnwrap(
            AppScreenAddress(rawURL: URL(string: "https://testbench.rover.io/a/detail")!)
        )

        let detailSession = AppScreenSession(
            templateKey: "https://testbench.rover.io/a/detail",
            webView: WKWebView(),
            state: .ready
        )
        detailSession.isOnStack = true
        detailSession.documentURL = detailAddress.url

        let record = PendingNavigation(
            session: detailSession,
            resolvedURL: detailAddress.url,
            optimisticDataJSON: nil,
            isColdLoad: false,
            tapTime: .now()
        )
        navigator.pendingNavigations.enqueue(record, for: detailAddress, in: sheetToken)

        let makeScreen: (AppScreensPageRequest) -> UIViewController = { request in
            self.navigator.makeHost(
                token: sheetToken,
                address: request.address,
                targetRequest: request.targetRequest,
                navigating: request.navigating
            )
        }

        let host = makeScreen(
            AppScreensPageRequest(
                role: .pushed,
                address: detailAddress,
                targetRequest: nil,
                navigating: FakeNavigating()
            )
        )

        let hostViewController = try XCTUnwrap(host as? AppScreensPageViewController)
        XCTAssertTrue(detailSession.hostViewController === hostViewController)
        XCTAssertEqual(detailSession.token, sheetToken)
        XCTAssertNotNil(detailSession.pipelineTask)
    }
}
