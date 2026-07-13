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

@MainActor
final class HubRouteHandlerConversationTests: XCTestCase {
    private static let userDefaultsSuiteName = "test.HubRouteHandlerConversationTests"

    private var capturedConversationID: UUID?
    private var capturedPresentedConversationID: UUID?
    private var sut: HubRouteHandler!
    private var testUserDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        testUserDefaults = UserDefaults(suiteName: Self.userDefaultsSuiteName)!
        capturedConversationID = nil
        capturedPresentedConversationID = nil
        sut = makeSUT(inboxEnabled: true, deeplink: URL(string: "rv-rover://hub"))
    }

    override func tearDown() async throws {
        testUserDefaults.removePersistentDomain(forName: Self.userDefaultsSuiteName)
        testUserDefaults = nil
        capturedConversationID = nil
        capturedPresentedConversationID = nil
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Deep link tests

    func testDeepLinkConversationURLReturnsAction() {
        let id = UUID(uuidString: "019cbce7-86de-7610-94f0-cf590c499243")!
        let url = URL(string: "rv-rover://conversations/\(id.uuidString)")!
        _ = sut.deepLinkAction(url: url, domain: nil)
        XCTAssertEqual(capturedConversationID, id)
    }

    func testDeepLinkConversationURLWithUppercaseUUIDWorks() {
        let id = UUID(uuidString: "019CBCE7-86DE-7610-94F0-CF590C499243")!
        let url = URL(string: "rv-rover://conversations/\(id.uuidString)")!
        _ = sut.deepLinkAction(url: url, domain: nil)
        XCTAssertEqual(capturedConversationID, id)
    }

    func testDeepLinkConversationURLWithInvalidUUIDReturnsNil() {
        let url = URL(string: "rv-rover://conversations/not-a-uuid")!
        let action = sut.deepLinkAction(url: url, domain: nil)
        XCTAssertNil(action)
        XCTAssertNil(capturedConversationID)
    }

    func testDeepLinkConversationURLWithNoIDComponentReturnsNil() {
        let url = URL(string: "rv-rover://conversations")!
        let action = sut.deepLinkAction(url: url, domain: nil)
        XCTAssertNil(action)
        XCTAssertNil(capturedConversationID)
    }

    // MARK: - Universal link tests

    func testUniversalLinkConversationPathReturnsNil() {
        let id = UUID(uuidString: "019cbce7-86de-7610-94f0-cf590c499243")!
        let url = URL(string: "https://app.example.com/conversations/\(id.uuidString)")!
        let action = sut.universalLinkAction(url: url)
        XCTAssertNil(action)
        XCTAssertNil(capturedConversationID)
    }

    func testUniversalLinkConversationPathWithInvalidUUIDReturnsNil() {
        let url = URL(string: "https://app.example.com/conversations/bad-id")!
        let action = sut.universalLinkAction(url: url)
        XCTAssertNil(action)
        XCTAssertNil(capturedConversationID)
    }

    func testUniversalLinkUnrelatedPathReturnsNil() {
        let url = URL(string: "https://app.example.com/settings/profile")!
        let action = sut.universalLinkAction(url: url)
        XCTAssertNil(action)
        XCTAssertNil(capturedConversationID)
    }

    func testUniversalLinkConversationPathDoesNotPresentModalWhenInboxDisabled() {
        sut = makeSUT(inboxEnabled: false, deeplink: URL(string: "rv-rover://hub"))

        let id = UUID(uuidString: "019cbce7-86de-7610-94f0-cf590c499243")!
        let url = URL(string: "https://app.example.com/conversations/\(id.uuidString)")!
        let action = sut.universalLinkAction(url: url)

        XCTAssertNil(action)
        XCTAssertNil(capturedPresentedConversationID)
        XCTAssertNil(capturedConversationID)
    }

    func testUniversalLinkConversationPathReturnsNilWhenDeeplinkUnavailable() {
        sut = makeSUT(inboxEnabled: true, deeplink: nil)

        let id = UUID(uuidString: "019cbce7-86de-7610-94f0-cf590c499243")!
        let url = URL(string: "https://app.example.com/conversations/\(id.uuidString)")!
        let action = sut.universalLinkAction(url: url)

        XCTAssertNil(action)
        XCTAssertNil(capturedPresentedConversationID)
        XCTAssertNil(capturedConversationID)
    }

    func testDeepLinkConversationURLPresentsModalWhenInboxDisabled() {
        sut = makeSUT(inboxEnabled: false, deeplink: URL(string: "rv-rover://hub"))

        let id = UUID(uuidString: "019cbce7-86de-7610-94f0-cf590c499243")!
        let url = URL(string: "rv-rover://conversations/\(id.uuidString)")!
        _ = sut.deepLinkAction(url: url, domain: nil)

        XCTAssertEqual(capturedPresentedConversationID, id)
        XCTAssertNil(capturedConversationID)
    }

    func testDeepLinkConversationURLPresentsModalWhenDeeplinkUnavailable() {
        sut = makeSUT(inboxEnabled: true, deeplink: nil)

        let id = UUID(uuidString: "019cbce7-86de-7610-94f0-cf590c499243")!
        let url = URL(string: "rv-rover://conversations/\(id.uuidString)")!
        _ = sut.deepLinkAction(url: url, domain: nil)

        XCTAssertEqual(capturedPresentedConversationID, id)
        XCTAssertNil(capturedConversationID)
    }

    // MARK: - Posts still work

    func testDeepLinkPostURLStillWorks() {
        // With default config (no deeplink URL configured), posts route through presentPostActionProvider
        var capturedPostID: String?
        let coordinator = makeCoordinator(inboxEnabled: true, deeplink: nil)
        let handler = HubRouteHandler(
            coordinator: coordinator,
            presentPostActionProvider: { id in
                capturedPostID = id
                return nil
            },
            navigateToPostActionProvider: { _ in nil },
            presentConversationActionProvider: { _ in nil },
            navigateToConversationActionProvider: { _ in nil }
        )
        let url = URL(string: "rv-rover://posts/some-post-id")!
        _ = handler.deepLinkAction(url: url, domain: nil)
        XCTAssertEqual(capturedPostID, "some-post-id")
    }

    private func makeSUT(inboxEnabled: Bool, deeplink: URL?) -> HubRouteHandler {
        let coordinator = makeCoordinator(inboxEnabled: inboxEnabled, deeplink: deeplink)
        return HubRouteHandler(
            coordinator: coordinator,
            presentPostActionProvider: { _ in nil },
            navigateToPostActionProvider: { _ in nil },
            presentConversationActionProvider: { [weak self] uuid in
                self?.capturedPresentedConversationID = uuid
                return nil
            },
            navigateToConversationActionProvider: { [weak self] uuid in
                self?.capturedConversationID = uuid
                return nil
            }
        )
    }

    private func makeCoordinator(inboxEnabled: Bool, deeplink: URL?) -> HubCoordinator {
        let userDefaults = testUserDefaults!
        let configManager = ConfigManager(userDefaults: userDefaults)
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
        configManager.updateFromBackend(
            RoverConfig(
                hub: .init(
                    isHomeEnabled: false,
                    isInboxEnabled: inboxEnabled,
                    isSettingsViewEnabled: false,
                    deeplink: deeplink
                )
            )
        )
        return HubCoordinator(
            configManager: configManager,
            homeViewManager: homeViewManager,
            notificationHandler: SpyNotificationHandler()
        )
    }
}
