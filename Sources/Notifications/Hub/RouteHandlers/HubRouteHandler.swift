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
import os.log

/// Route handler for Hub deep links and universal links.
/// Handles URLs in the format:
/// - Deep links: rv-myapp://posts/{id}
/// - Universal links: https://yourdomain.com/posts/{id}
@MainActor
class HubRouteHandler: RouteHandler {
    private let coordinator: HubCoordinator
    private let presentPostActionProvider: (String?) -> Action?
    private let navigateToPostActionProvider: (String) -> Action?

    /// Initializes the route handler with a Hub coordinator and action providers.
    /// - Parameters:
    ///   - coordinator: The Hub coordinator to use for navigation.
    ///   - presentPostActionProvider: Closure that provides modal post presentation action.
    ///   - navigateToPostActionProvider: Closure that provides navigation to post action.
    init(
        coordinator: HubCoordinator,
        presentPostActionProvider: @escaping (String?) -> Action?,
        navigateToPostActionProvider: @escaping (String) -> Action?
    ) {
        self.coordinator = coordinator
        self.presentPostActionProvider = presentPostActionProvider
        self.navigateToPostActionProvider = navigateToPostActionProvider
    }

    /// Handles deep link URLs for Hub navigation.
    /// - Parameters:
    ///   - url: The deep link URL to process.
    ///   - domain: The domain associated with the URL (unused for this handler).
    /// - Returns: An action to execute for the URL, or nil if the URL is not handled.
    func deepLinkAction(url: URL, domain: String?) -> Action? {
        return processURL(url)
    }

    /// Handles universal link URLs for Hub navigation.
    /// - Parameter url: The universal link URL to process.
    /// - Returns: An action to execute for the URL, or nil if the URL is not handled.
    func universalLinkAction(url: URL) -> Action? {
        return processURL(url)
    }

    /// Processes a URL and returns the appropriate action.
    /// - Parameter url: The URL to process.
    /// - Returns: An action to execute for the URL, or nil if the URL is not handled.
    private func processURL(_ url: URL) -> Action? {
        guard let host = url.host else {
            return nil
        }

        // Handle deep links with rover://... format
        let lowercasedHost = host.lowercased()
        if lowercasedHost == "posts" {
            return handleHubPath("/" + lowercasedHost + url.path)
        }

        // Handle universal links with /posts/ paths
        if url.path.hasPrefix("/posts/") {
            return handleHubPath(url.path)
        }

        return nil
    }

    /// Handles Hub specific paths and returns the appropriate action.
    /// - Parameter path: The path component (e.g., /posts/{id})
    /// - Returns: An action to execute for the path, or nil if the path is not handled.
    private func handleHubPath(_ path: String) -> Action? {
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }

        guard !components.isEmpty else {
            return nil
        }

        let action = components[0]

        switch action {
        case "posts":
            guard components.count >= 2 else {
                return nil
            }
            let postID = components[1]

            // If we have a deeplink URL and the Inbox is enabled, navigate within the Hub
            if coordinator.config.hub.deeplink != nil && coordinator.isInboxEnabled {
                os_log("Navigating to Post Detail", log: .hub, type: .debug)
                return navigateToPostActionProvider(postID)
            } else {
                // Otherwise, present post modally outside Hub context
                os_log("Presenting Post Detail", log: .hub, type: .debug)
                return presentPostActionProvider(postID)
            }

        default:
            return nil
        }
    }
}
