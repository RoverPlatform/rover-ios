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

// MARK: - Spy

class SpyNotificationHandler: NotificationHandler {
    private(set) var clearedConversationIDs: [UUID] = []

    func handle(_ response: UNNotificationResponse, completionHandler: (() -> Void)?) -> Bool { false }
    func action(for response: UNNotificationResponse) -> Action? { nil }

    func clearDeliveredNotifications(for conversationID: UUID) async {
        clearedConversationIDs.append(conversationID)
    }
}

// MARK: - identifiersToRemove tests

final class NotificationHandlerServiceClearingTests: XCTestCase {

    private let handler = NotificationHandlerService(
        dispatcher: MockDispatcher(),
        influenceTracker: MockInfluenceTracker(),
        notificationActionProvider: { _ in nil },
        openURLActionProvider: { _ in nil },
        replySync: MockReplySending(),
        inboxPersistentContainer: nil
    )

    static let conversationID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    static let otherID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000002")!

    func testMatchesViaThreadIdentifier() {
        let delivered = [
            (identifier: "notif-1", threadIdentifier: Self.conversationID.uuidString, userInfo: [AnyHashable: Any]())
        ]
        let result = handler.identifiersToRemove(from: delivered, for: Self.conversationID)
        XCTAssertEqual(result, ["notif-1"])
    }

    func testMatchesViaUserInfoFallbackWhenThreadIdentifierIsEmpty() {
        let delivered = [
            (
                identifier: "notif-2", threadIdentifier: "",
                userInfo: makeConversationUserInfo(conversationID: Self.conversationID)
            )
        ]
        let result = handler.identifiersToRemove(from: delivered, for: Self.conversationID)
        XCTAssertEqual(result, ["notif-2"])
    }

    func testMatchesViaUserInfoWhenThreadIdentifierBelongsToDifferentConversation() {
        let delivered = [
            (
                identifier: "notif-3", threadIdentifier: Self.otherID.uuidString,
                userInfo: makeConversationUserInfo(conversationID: Self.conversationID)
            )
        ]
        let result = handler.identifiersToRemove(from: delivered, for: Self.conversationID)
        XCTAssertEqual(result, ["notif-3"])
    }

    func testNoMatchWhenNeitherPathMatches() {
        let delivered = [
            (
                identifier: "notif-4", threadIdentifier: Self.otherID.uuidString,
                userInfo: makeConversationUserInfo(conversationID: Self.otherID)
            )
        ]
        let result = handler.identifiersToRemove(from: delivered, for: Self.conversationID)
        XCTAssertEqual(result, [])
    }

    func testCaseInsensitiveThreadIdentifierMatch() {
        let lowercaseID = Self.conversationID.uuidString.lowercased()
        let delivered = [(identifier: "notif-5", threadIdentifier: lowercaseID, userInfo: [AnyHashable: Any]())]
        let result = handler.identifiersToRemove(from: delivered, for: Self.conversationID)
        XCTAssertEqual(result, ["notif-5"])
    }

    func testReturnsOnlyMatchingIdentifiers() {
        let delivered = [
            (identifier: "match-1", threadIdentifier: Self.conversationID.uuidString, userInfo: [AnyHashable: Any]()),
            (
                identifier: "no-match", threadIdentifier: Self.otherID.uuidString,
                userInfo: makeConversationUserInfo(conversationID: Self.otherID)
            ),
            (
                identifier: "match-2", threadIdentifier: "",
                userInfo: makeConversationUserInfo(conversationID: Self.conversationID)
            )
        ]
        let result = handler.identifiersToRemove(from: delivered, for: Self.conversationID)
        XCTAssertEqual(Set(result), ["match-1", "match-2"])
    }

}

@MainActor
final class HubCoordinatorClearingTests: XCTestCase {
    private static let userDefaultsSuiteName = "test.HubCoordinatorClearingTests"
    private static let conversationID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000003")!

    private var testUserDefaults: UserDefaults!
    private var notificationHandler: SpyNotificationHandler!
    private var coordinator: HubCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        testUserDefaults = UserDefaults(suiteName: Self.userDefaultsSuiteName)!
        let authContext = AuthenticationContext(userDefaults: testUserDefaults)
        let session = MockURLSession.createConfiguredSession()
        let mockUserInfoManager = MockUserInfoManager()
        let httpClient = HTTPClient(
            accountToken: "test-token",
            endpoint: URL(string: "https://api.test.com")!,
            engageEndpoint: URL(string: "https://engage.test.com")!,
            session: session,
            authContext: authContext,
            userInfoManager: mockUserInfoManager
        )
        let homeViewManager = HomeViewManager(
            httpClient: httpClient,
            userDefaults: testUserDefaults,
            userInfoManager: MockUserInfoManager()
        )
        notificationHandler = SpyNotificationHandler()
        coordinator = HubCoordinator(
            configManager: ConfigManager(userDefaults: testUserDefaults),
            homeViewManager: homeViewManager,
            notificationHandler: notificationHandler
        )
    }

    override func tearDown() async throws {
        coordinator = nil
        notificationHandler = nil
        testUserDefaults.removePersistentDomain(forName: Self.userDefaultsSuiteName)
        testUserDefaults = nil
        try await super.tearDown()
    }

    func testConversationDidAppearSetsDisplayedConversationIDImmediately() async {
        let clearingTask = coordinator.conversationDidAppear(Self.conversationID)

        XCTAssertEqual(coordinator.displayedConversationID, Self.conversationID)

        await clearingTask?.value
    }

    func testConversationDidAppearReturnsTaskThatClearsDeliveredNotificationsForConversation() async {
        let clearingTask = coordinator.conversationDidAppear(Self.conversationID)

        await clearingTask?.value

        XCTAssertEqual(notificationHandler.clearedConversationIDs, [Self.conversationID])
    }

    func testConversationDidAppearIsIdempotentForSameConversation() async {
        await coordinator.conversationDidAppear(Self.conversationID)?.value

        let secondTask = coordinator.conversationDidAppear(Self.conversationID)

        XCTAssertNil(secondTask)
        XCTAssertEqual(notificationHandler.clearedConversationIDs, [Self.conversationID])
    }
}
