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

@testable import RoverData
@testable import RoverFoundation
@testable import RoverNotifications

/// A configured reveal deep link only counts as revealable when the app can open it.
/// Otherwise the route falls back to the modal presentation instead of queueing a
/// destination behind an open that would fail silently.
@MainActor
final class HubRouteHandlerDeepLinkOpenabilityTests: XCTestCase {
    private static let userDefaultsSuiteName = "test.HubRouteHandlerDeepLinkOpenabilityTests"

    private var navigatedPostID: String?
    private var navigatedConversationID: UUID?
    private var presentedPostID: String?
    private var presentedConversationID: UUID?
    private var testUserDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        testUserDefaults = UserDefaults(suiteName: Self.userDefaultsSuiteName)!
        navigatedPostID = nil
        navigatedConversationID = nil
        presentedPostID = nil
        presentedConversationID = nil
    }

    override func tearDown() async throws {
        testUserDefaults.removePersistentDomain(forName: Self.userDefaultsSuiteName)
        testUserDefaults = nil
        try await super.tearDown()
    }

    // MARK: - configured deep link that can be opened

    func testPostRouteNavigatesWhenDeepLinkCanBeOpened() {
        let sut = makeSUT(deeplink: URL(string: "myapp://hub"), canOpenDeepLink: { _ in true })
        _ = sut.deepLinkAction(url: URL(string: "rv-rover://posts/abc123")!, domain: nil)
        XCTAssertEqual(navigatedPostID, "abc123")
        XCTAssertNil(presentedPostID)
    }

    // MARK: - configured deep link that cannot be opened

    func testPostRouteFallsBackToModalWhenDeepLinkCannotBeOpened() {
        let sut = makeSUT(deeplink: URL(string: "myapp://hub"), canOpenDeepLink: { _ in false })
        _ = sut.deepLinkAction(url: URL(string: "rv-rover://posts/abc123")!, domain: nil)
        XCTAssertEqual(presentedPostID, "abc123")
        XCTAssertNil(navigatedPostID)
    }

    func testConversationRouteFallsBackToModalWhenDeepLinkCannotBeOpened() {
        let id = UUID()
        let sut = makeSUT(deeplink: URL(string: "myapp://hub"), canOpenDeepLink: { _ in false })
        _ = sut.deepLinkAction(url: URL(string: "rv-rover://conversations/\(id.uuidString)")!, domain: nil)
        XCTAssertEqual(presentedConversationID, id)
        XCTAssertNil(navigatedConversationID)
    }

    // MARK: - no configured deep link

    func testOpenabilityCheckIsNotConsultedWithoutAConfiguredDeepLink() {
        var checkedURLs: [URL] = []
        let sut = makeSUT(
            deeplink: nil,
            canOpenDeepLink: { url in
                checkedURLs.append(url)
                return true
            }
        )
        _ = sut.deepLinkAction(url: URL(string: "rv-rover://posts/abc123")!, domain: nil)
        XCTAssertEqual(presentedPostID, "abc123")
        XCTAssertTrue(checkedURLs.isEmpty)
    }

    func testOpenabilityCheckReceivesTheConfiguredDeepLink() {
        var checkedURLs: [URL] = []
        let sut = makeSUT(
            deeplink: URL(string: "myapp://hub"),
            canOpenDeepLink: { url in
                checkedURLs.append(url)
                return true
            }
        )
        _ = sut.deepLinkAction(url: URL(string: "rv-rover://posts/abc123")!, domain: nil)
        XCTAssertEqual(checkedURLs, [URL(string: "myapp://hub")!])
    }

    // MARK: - Builders

    private func makeSUT(
        deeplink: URL?,
        canOpenDeepLink: @escaping (URL) -> Bool
    ) -> HubRouteHandler {
        let userDefaults = testUserDefaults!
        let configManager = ConfigManager(userDefaults: userDefaults)
        configManager.updateFromBackend(
            RoverConfig(
                hub: RoverConfig.Hub(
                    isHomeEnabled: false,
                    isInboxEnabled: true,
                    isSettingsViewEnabled: false,
                    deeplink: deeplink
                )
            )
        )
        let authContext = AuthenticationContext(userDefaults: userDefaults)
        let session = MockURLSession.createConfiguredSession()
        let httpClient = HTTPClient(
            accountToken: "test-token",
            endpoint: URL(string: "https://api.test.com")!,
            engageEndpoint: URL(string: "https://engage.test.com")!,
            session: session,
            authContext: authContext,
            userInfoManager: MockUserInfoManager()
        )
        let homeViewManager = HomeViewManager(
            httpClient: httpClient,
            userDefaults: userDefaults,
            userInfoManager: MockUserInfoManager()
        )
        let coordinator = HubCoordinator(
            configManager: configManager,
            homeViewManager: homeViewManager,
            notificationHandler: SpyNotificationHandler()
        )
        return HubRouteHandler(
            coordinator: coordinator,
            deepLinkOpenabilityCheck: canOpenDeepLink,
            presentPostActionProvider: { [weak self] id in
                self?.presentedPostID = id
                return nil
            },
            navigateToPostActionProvider: { [weak self] id in
                self?.navigatedPostID = id
                return nil
            },
            presentConversationActionProvider: { [weak self] id in
                self?.presentedConversationID = id
                return nil
            },
            navigateToConversationActionProvider: { [weak self] id in
                self?.navigatedConversationID = id
                return nil
            }
        )
    }
}
