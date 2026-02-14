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

/// Navigator object for managing Hub navigation state and operations.
/// Users should instantiate this object, hold onto it, and pass it to CommunicationHubView.
@MainActor
public class CommunicationHubNavigator: ObservableObject {
    @Published private(set) var navigationState: NavigationState = .idle
    @Published private(set) var pendingPostID: String?

    /// The navigation path managed by this navigator
    @Published public var navigationPath = NavigationPath()

    public init() {}

    /// Navigate to a specific post by ID
    public func navigateToPost(id: String) {}

    /// Navigate to supported content. Only will use relevant query parameters from the URL, but the URL can otherwise be your own custom deep linking scheme.
    public func navigateToURL(_ url: URL) {}
}

/// Navigation state for the Hub
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
