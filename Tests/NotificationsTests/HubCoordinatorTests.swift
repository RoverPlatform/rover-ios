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
import RoverFoundation
import UserNotifications
import XCTest

@testable import RoverData
@testable import RoverNotifications

/// Verifies the coordinator-driven navigation reset: `appScreensResetGeneration`
/// increments on each reset (so the embedded App Screens flow pops to root), and
/// the navigation path contents stay as they are today.
@MainActor
final class HubCoordinatorTests: XCTestCase {

    private let configSuiteName = "io.rover.test.hubCoordinator.config"
    private let homeSuiteName = "io.rover.test.hubCoordinator.home"
    private static let homeStorageKey = "io.rover.homeView.response"

    override func tearDown() {
        UserDefaults(suiteName: configSuiteName)?.removePersistentDomain(forName: configSuiteName)
        UserDefaults(suiteName: homeSuiteName)?.removePersistentDomain(forName: homeSuiteName)
        super.tearDown()
    }

    // MARK: - Fixtures

    private func makeHTTPClient() -> HTTPClient {
        HTTPClient(
            accountToken: "test-token",
            endpoint: URL(string: "https://testbench.rover.io")!,
            engageEndpoint: URL(string: "https://engage.rover.io")!,
            session: .shared,
            authContext: AuthenticationContext(userDefaults: UserDefaults())
        )
    }

    /// Builds a coordinator with real dependencies. `hub` sets the active config;
    /// `homeViewURL` (when non-nil) is seeded into the home-view cache so
    /// `homeViewExperienceURL` is populated at init.
    private func makeCoordinator(
        hub: RoverConfig.Hub,
        homeViewURL: URL?
    ) -> HubCoordinator {
        let configDefaults = UserDefaults(suiteName: configSuiteName)!
        let configManager = ConfigManager(userDefaults: configDefaults)
        configManager.updateFromBackend(RoverConfig(hub: hub))

        let homeDefaults = UserDefaults(suiteName: homeSuiteName)!
        if let homeViewURL {
            let response = HomeViewResponse(experienceURL: homeViewURL)
            homeDefaults.set(try! JSONEncoder().encode(response), forKey: Self.homeStorageKey)
        }
        let homeViewManager = HomeViewManager(
            httpClient: makeHTTPClient(),
            userDefaults: homeDefaults,
            userInfoManager: FakeUserInfoManager()
        )

        return HubCoordinator(
            configManager: configManager,
            homeViewManager: homeViewManager,
            notificationHandler: FakeNotificationHandler()
        )
    }

    // MARK: - Reset generation

    func testResetGenerationIncrementsOnConversationNavigation() {
        let coordinator = makeCoordinator(hub: RoverConfig.Hub(), homeViewURL: nil)
        let base = coordinator.appScreensResetGeneration

        coordinator.navigateToConversation(id: UUID())

        XCTAssertEqual(coordinator.appScreensResetGeneration, base + 1)
    }

    func testResetGenerationIncrementsOnPostNavigation() {
        let coordinator = makeCoordinator(hub: RoverConfig.Hub(), homeViewURL: nil)
        let base = coordinator.appScreensResetGeneration

        coordinator.navigateToPost(id: "post-1")

        XCTAssertEqual(coordinator.appScreensResetGeneration, base + 1)
    }

    func testResetGenerationIncrementsOnEachNavigation() {
        let coordinator = makeCoordinator(hub: RoverConfig.Hub(), homeViewURL: nil)
        let base = coordinator.appScreensResetGeneration

        coordinator.navigateToConversation(id: UUID())
        coordinator.navigateToPost(id: "post-1")

        XCTAssertEqual(coordinator.appScreensResetGeneration, base + 2)
    }

    // MARK: - Navigation path contents (locking in current behavior)

    func testConversationNavigationDoesNotPrependMessagesWhenHomeDisabled() {
        // Default config has home disabled: the reset produces an empty path, so the
        // conversation destination is the only entry.
        let coordinator = makeCoordinator(hub: RoverConfig.Hub(), homeViewURL: nil)

        coordinator.navigateToConversation(id: UUID())

        XCTAssertEqual(coordinator.navigationPath.count, 1)
    }

    func testPostNavigationPrependsMessagesWhenHomeAndInboxEnabled() {
        // Home + inbox enabled and a home view URL present: the reset prepends the
        // messages destination, so the post destination sits behind it.
        let coordinator = makeCoordinator(
            hub: RoverConfig.Hub(isHomeEnabled: true, isInboxEnabled: true),
            homeViewURL: URL(string: "https://testbench.rover.io/a/home")!
        )

        coordinator.navigateToPost(id: "post-1")

        XCTAssertEqual(coordinator.navigationPath.count, 2)
    }

    func testNavigationDoesNotPrependMessagesWhenInboxDisabled() {
        // Home enabled but inbox disabled: no messages destination is prepended.
        let coordinator = makeCoordinator(
            hub: RoverConfig.Hub(isHomeEnabled: true, isInboxEnabled: false),
            homeViewURL: URL(string: "https://testbench.rover.io/a/home")!
        )

        coordinator.navigateToConversation(id: UUID())

        XCTAssertEqual(coordinator.navigationPath.count, 1)
    }

    func testNavigationDoesNotPrependMessagesWhenNoHomeViewURL() {
        // Home + inbox enabled but no home view URL: still no messages prepend.
        let coordinator = makeCoordinator(
            hub: RoverConfig.Hub(isHomeEnabled: true, isInboxEnabled: true),
            homeViewURL: nil
        )

        coordinator.navigateToPost(id: "post-1")

        XCTAssertEqual(coordinator.navigationPath.count, 1)
    }
}

// MARK: - Test doubles

private struct FakeUserInfoManager: UserInfoManager {
    func updateUserInfo(block: (inout Attributes) -> Void) {}
    func clearUserInfo() {}
    var currentUserInfo: [String: Any] { [:] }
}

private final class FakeNotificationHandler: NotificationHandler {
    func handle(_ response: UNNotificationResponse, completionHandler: (() -> Void)?) -> Bool {
        false
    }

    func action(for response: UNNotificationResponse) -> Action? {
        nil
    }
}
