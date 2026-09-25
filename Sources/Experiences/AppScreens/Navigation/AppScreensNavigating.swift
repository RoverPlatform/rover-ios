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

/// The complete navigation surface a screen can request. Intent-level and free of
/// UIKit/SwiftUI types, so the same screen code drives whichever host owns the stack.
/// There is deliberately no `pop`: back navigation belongs to the stack owner (the
/// system back button / interactive swipe / the host's `NavigationPath`).
@MainActor
package protocol AppScreensNavigating: AnyObject {
    func pushScreen(address: AppScreenAddress, targetRequest: URLRequest?)
    func presentSheet(address: AppScreenAddress, targetRequest: URLRequest?, sheetToken: AppScreensToken)
    func presentWebsite(url: URL)
    func dismissRoot()
}
