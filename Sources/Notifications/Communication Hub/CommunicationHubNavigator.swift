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
import SwiftUI

/// Navigator object for managing Communication Hub navigation state and operations.
/// Users should instantiate this object, hold onto it, and pass it to CommunicationHubView.
@MainActor
public class CommunicationHubNavigator: ObservableObject {
  @Published private(set) var navigationState: NavigationState = .idle
  @Published private(set) var pendingPostID: String?
  private var processingPostID: String?

  /// The navigation path managed by this navigator
  @Published public var navigationPath = NavigationPath()

  public init() {}

  /// Navigate to a specific post by ID
  public func navigateToPost(id: String) {
    // Only set pending if we're not already processing this same post
    if id != processingPostID {
      pendingPostID = id
      navigationState = .navigatingToPost(id)
    }
  }

  /// Navigate to supported content. Only will use relevant query parameters from the URL, but the URL can otherwise be your own custom deep linking scheme.
  public func navigateToURL(_ url: URL) {
    if let postID = extractPostID(from: url) {
      navigateToPost(id: postID)
    }
  }

  // MARK: - Internal methods for CommunicationHubView

  /// Clear any pending navigation
  internal func clearNavigation() {
    pendingPostID = nil
    navigationState = .idle
    processingPostID = nil
  }

  /// Reset navigation path to root
  internal func popToRoot() {
    navigationPath = NavigationPath()
    clearNavigation()
  }

  internal func consumePendingPostID() -> String? {
    guard let postID = pendingPostID else { return nil }
    // Mark as currently processing and clear pending state
    processingPostID = postID
    pendingPostID = nil
    navigationState = .idle
    return postID
  }

  /// Mark navigation as complete, allowing re-navigation to the same post
  internal func completeNavigation() {
    processingPostID = nil
  }

  internal func setNavigationState(_ state: NavigationState) {
    navigationState = state
  }

  // MARK: - Private helpers

  private func extractPostID(from url: URL) -> String? {
    return URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?
      .first(where: { $0.name == "postID" })?
      .value
  }
}

/// Navigation state for the Communication Hub
public enum NavigationState: Equatable {
  case idle
  case navigatingToPost(String)

  public static func == (lhs: NavigationState, rhs: NavigationState) -> Bool {
    switch (lhs, rhs) {
    case (.idle, .idle):
      return true
    case (.navigatingToPost(let lhsID), .navigatingToPost(let rhsID)):
      return lhsID == rhsID
    default:
      return false
    }
  }
}
