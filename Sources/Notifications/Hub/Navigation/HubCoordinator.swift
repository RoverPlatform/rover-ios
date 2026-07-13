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

import Combine
import Foundation
import RoverData
import SwiftUI

@MainActor
class HubCoordinator: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var config: RoverConfig
    @Published var showPostAlert: Bool = false
    /// The most recent home view experience URL from the cache or the latest fetch.
    @Published private(set) var homeViewExperienceURL: URL?

    /// Monotonic counter bumped every time the coordinator resets its navigation
    /// path (a push-notification tap to a post/conversation, or a config change).
    /// An embedded V3 App Screens home view observes this through the
    /// `ExperienceView` package channel and, on each increment, pops its own child
    /// navigation stack to root — dismissing any App Screens sheets it presented —
    /// so a coordinator-driven navigation never leaves a stale pushed detail behind
    /// the home root to be revealed on back-out.
    @Published private(set) var appScreensResetGeneration = 0

    private(set) var configManager: ConfigManager
    private let homeViewManager: HomeViewManager
    private let notificationHandler: NotificationHandler
    private var cancellables = Set<AnyCancellable>()

    init(
        configManager: ConfigManager,
        homeViewManager: HomeViewManager,
        notificationHandler: NotificationHandler
    ) {
        self.configManager = configManager
        self.homeViewManager = homeViewManager
        self.notificationHandler = notificationHandler
        self.config = configManager.config
        self.homeViewExperienceURL = homeViewManager.experienceURL

        // Forward config changes from ConfigManager and reset navigation
        configManager.$config
            .removeDuplicates()
            .sink { [weak self] newConfig in
                guard let self = self else { return }
                self.config = newConfig
                self.navigationPath = NavigationPath()
                // A config change tears the path down to root; signal the embedded
                // App Screens flow to pop its child stack to root too.
                self.appScreensResetGeneration += 1
            }
            .store(in: &cancellables)

        // Forward HomeViewManager changes
        homeViewManager.$experienceURL
            .sink { [weak self] url in
                if url != self?.homeViewExperienceURL {
                    self?.homeViewExperienceURL = url
                }
            }
            .store(in: &cancellables)
    }

    var isHomeEnabled: Bool {
        config.hub.isHomeEnabled
    }

    var isInboxEnabled: Bool {
        config.hub.isInboxEnabled
    }

    var accentColor: Color {
        config.accentColor.flatMap { Color(hex: $0) } ?? .accentColor
    }

    /// Converts HubColorScheme to SwiftUI ColorScheme.
    /// Returns nil for .auto or when not set, allowing system to decide.
    var colorScheme: ColorScheme? {
        config.colorScheme?.swiftUIColorScheme
    }

    // MARK: - Home View

    /// Fetches the home view URL from the server and updates `homeViewExperienceURL`.
    func fetchHomeView() async {
        await homeViewManager.fetch()
    }

    // MARK: - Navigation

    func navigateToPost(id: String) {
        resetNavigationPath()
        navigationPath.append(PostDestination(postID: id))
    }

    func navigateToConversation(id: UUID) {
        resetNavigationPath()
        navigationPath.append(ConversationDestination(conversationID: id))
    }

    private func resetNavigationPath() {
        navigationPath = NavigationPath()
        // Signal the embedded App Screens flow to pop its child navigation stack to
        // root: a coordinator-driven navigation (e.g. a conversation push tap) must
        // not leave a stale App Screens detail behind the home root.
        appScreensResetGeneration += 1
        if isHomeEnabled && homeViewExperienceURL != nil && isInboxEnabled {
            navigationPath.append(HubPath.messages)
        }
    }

    // MARK: - Conversation display tracking

    private(set) var displayedConversationID: UUID?

    @discardableResult
    func conversationDidAppear(_ id: UUID) -> Task<Void, Never>? {
        guard displayedConversationID != id else { return nil }
        displayedConversationID = id
        return Task {
            await notificationHandler.clearDeliveredNotifications(for: id)
        }
    }

    func conversationDidDisappear(_ id: UUID) {
        if displayedConversationID == id {
            displayedConversationID = nil
        }
    }
}
