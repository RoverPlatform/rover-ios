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
import RoverUI
import UIKit
import os.log

/// Route handler for Hub deep links.
/// Handles URLs in the format:
/// - Deep links: rv-myapp://posts/{id}  rv-myapp://conversations/{uuid}
@MainActor
class HubRouteHandler: RouteHandler {
    private let coordinator: HubCoordinator
    private let deepLinkOpenabilityCheck: @MainActor (URL) -> Bool
    private let presentPostActionProvider: (String?) -> Action?
    private let navigateToPostActionProvider: (String) -> Action?
    private let presentConversationActionProvider: (UUID) -> Action?
    private let navigateToConversationActionProvider: (UUID) -> Action?

    private static let knownHubHosts: Set<String> = ["posts", "conversations"]

    /// Initializes the route handler with a Hub coordinator and action providers.
    /// - Parameters:
    ///   - coordinator: The Hub coordinator to use for navigation.
    ///   - deepLinkOpenabilityCheck: Answers whether the app can open a configured reveal deep
    ///     link. Defaults to `UIApplication.shared.canOpenURL`; injectable for tests. A
    ///     custom-scheme reveal deep link is expected to use one of the host app's own
    ///     registered URL schemes, which `canOpenURL` answers for without an
    ///     `LSApplicationQueriesSchemes` entry. A scheme registered by a different app would
    ///     need listing there to pass this check.
    ///   - presentPostActionProvider: Closure that provides modal post presentation action.
    ///   - navigateToPostActionProvider: Closure that provides navigation to post action.
    ///   - presentConversationActionProvider: Closure that provides modal conversation presentation action.
    ///   - navigateToConversationActionProvider: Closure that provides navigation to conversation action.
    init(
        coordinator: HubCoordinator,
        deepLinkOpenabilityCheck: @escaping @MainActor (URL) -> Bool = { UIApplication.shared.canOpenURL($0) },
        presentPostActionProvider: @escaping (String?) -> Action?,
        navigateToPostActionProvider: @escaping (String) -> Action?,
        presentConversationActionProvider: @escaping (UUID) -> Action?,
        navigateToConversationActionProvider: @escaping (UUID) -> Action?
    ) {
        self.coordinator = coordinator
        self.deepLinkOpenabilityCheck = deepLinkOpenabilityCheck
        self.presentPostActionProvider = presentPostActionProvider
        self.navigateToPostActionProvider = navigateToPostActionProvider
        self.presentConversationActionProvider = presentConversationActionProvider
        self.navigateToConversationActionProvider = navigateToConversationActionProvider
    }

    func deepLinkAction(url: URL, domain: String?) -> Action? {
        return processURL(url)
    }

    func universalLinkAction(url: URL) -> Action? {
        return nil
    }

    private func processURL(_ url: URL) -> Action? {
        guard let host = url.host else {
            return nil
        }

        let lowercasedHost = host.lowercased()

        if Self.knownHubHosts.contains(lowercasedHost) {
            return handleHubPath("/" + lowercasedHost + url.path)
        }

        return nil
    }

    /// Whether a configured reveal deep link can actually be opened. A URL the app cannot open
    /// (an unregistered scheme, a misconfigured dashboard value) used to count as revealable:
    /// the open then failed silently and the queued destination surfaced whenever the Hub
    /// next appeared. Falling back to the modal presentation instead matches Android,
    /// which asks PackageManager the same question before revealing.
    ///
    /// Only custom URL schemes are verified. A universal link (https) always passes, because
    /// `canOpenURL` answers for Safari and no synchronous, side-effect-free API tells whether the
    /// associated domain routes back to this app. Android has the same limit.
    private func canReveal(via deepLink: URL?) -> Bool {
        guard let deepLink else {
            return false
        }
        guard deepLinkOpenabilityCheck(deepLink) else {
            os_log(
                "Configured deep link cannot be opened by this app, presenting modally instead: %{public}@",
                log: .hub,
                type: .error,
                deepLink.absoluteString
            )
            return false
        }
        return true
    }

    private func handleHubPath(_ path: String) -> Action? {
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }

        guard !components.isEmpty else {
            return nil
        }

        switch components[0] {
        case "posts":
            guard components.count >= 2 else {
                return nil
            }
            let postID = components[1]

            if coordinator.isInboxEnabled && canReveal(via: coordinator.config.hub.deeplink) {
                os_log("Navigating to Post Detail", log: .hub, type: .debug)
                return navigateToPostActionProvider(postID)
            } else {
                os_log("Presenting Post Detail", log: .hub, type: .debug)
                return presentPostActionProvider(postID)
            }

        case "conversations":
            guard components.count >= 2 else {
                return nil
            }
            guard let uuid = UUID(uuidString: components[1]) else {
                os_log(
                    "HubRouteHandler: conversations path component is not a valid UUID: %{public}@",
                    log: .hub,
                    type: .error,
                    components[1]
                )
                return nil
            }

            if coordinator.isInboxEnabled && canReveal(via: coordinator.config.hub.deeplink) {
                os_log("Navigating to Conversation Detail", log: .hub, type: .debug)
                return navigateToConversationActionProvider(uuid)
            } else {
                os_log("Presenting Conversation Detail", log: .hub, type: .debug)
                return presentConversationActionProvider(uuid)
            }

        default:
            return nil
        }
    }
}
