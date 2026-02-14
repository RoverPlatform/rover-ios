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

    private(set) var configManager: ConfigManager
    private let homeViewManager: HomeViewManager
    private var cancellables = Set<AnyCancellable>()

    init(configManager: ConfigManager, homeViewManager: HomeViewManager) {
        self.configManager = configManager
        self.homeViewManager = homeViewManager
        self.config = configManager.config
        self.homeViewExperienceURL = homeViewManager.experienceURL

        // Forward config changes from ConfigManager and reset navigation
        configManager.$config
            .removeDuplicates()
            .sink { [weak self] newConfig in
                guard let self = self else { return }
                self.config = newConfig
                self.navigationPath = NavigationPath()
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
        // Reset the NavigationPath
        navigationPath = NavigationPath()

        // If in Hub mode with messages enabled, first navigate to messages view
        if isHomeEnabled && homeViewExperienceURL != nil && isInboxEnabled {
            navigationPath.append(HubPath.messages)
        }
        // Then navigate to the post
        navigationPath.append(PostDestination(postID: id))
    }
}
