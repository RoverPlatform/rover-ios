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
import UIKit

/// Base class for Hub navigation actions.
/// Provides common functionality for actions that interact with the HubCoordinator.
open class HubAction: Action, @unchecked Sendable {
    /// The Hub coordinator used for navigation.
    let coordinator: HubCoordinator

    /// Initializes the action with a coordinator.
    /// - Parameter coordinator: Hub coordinator to use for navigation.
    init(coordinator: HubCoordinator) {
        self.coordinator = coordinator
        super.init()
    }

    /// Ensure Hub is presented by calling the configured deeplink.
    /// Call this before setting navigation state to ensure the hub is visible.
    @MainActor
    internal func presentHub() {
        guard let url = coordinator.config.hub.deeplink else {
            return
        }

        UIApplication.shared.open(url)
    }
}

@available(*, deprecated, renamed: "HubAction")
public typealias CommHubAction = HubAction
