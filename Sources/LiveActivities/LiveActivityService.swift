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

import ActivityKit
import RoverData

/// Public protocol for Live Activity token management.
public protocol LiveActivityService: AnyObject {
    /// Set up observation to automatically register the push-to-start token for a given activity type.
    ///
    /// Note: this feature will only operate on iOS 18.0+. It is a no-op on any earlier version.
    ///
    /// Uses ActivityKit's ``Activity.pushToStartTokenUpdates`` to observe push-to-start tokens.
    /// - Parameters:
    ///   - attributes: The activity attributes type relevant to your app (e.g., `RoverNFLActivityAttributes.self` or `RoverNBAActivityAttributes.self`)
    ///   - name: A string identifier for this activity type
    /// - Returns: A task that can be cancelled to stop observing token updates
    @discardableResult
    func registerLiveActivity<T: ActivityAttributes>(
        attributes: T.Type,
        name: String
    ) -> Task<Void, Never>

    /// Manually register a Live Activity push-to-start token with Rover.
    ///
    /// - Parameters:
    ///   - name: Activity type name
    ///   - pushToStartToken: The push-to-start token.
    func registerToken(
        name: String,
        pushToStartToken: Context.PushToken?,
    )

    /// Remove token for a given activity name.
    func removeToken(name: String)
}
