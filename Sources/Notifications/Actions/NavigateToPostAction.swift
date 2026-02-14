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

/// Action that navigates to a specific post in the Hub.
/// This action uses the HubCoordinator to navigate to a post detail view.
class NavigateToPostAction: HubAction, @unchecked Sendable {
    /// The ID of the post to navigate to.
    let postID: String

    /// Initializes the action with a coordinator and post ID.
    /// - Parameters:
    ///   - coordinator: The Hub coordinator to use for navigation.
    ///   - postID: The ID of the post to navigate to.
    init(coordinator: HubCoordinator, postID: String) {
        self.postID = postID
        super.init(coordinator: coordinator)
        name = "Navigate to Post"
    }

    /// Executes the navigation to the post.
    override func execute() {
        DispatchQueue.main.async {
            if !self.postID.isEmpty {
                self.presentHub()
                self.coordinator.navigateToPost(id: self.postID)
            }
            self.finish()
        }
    }
}
