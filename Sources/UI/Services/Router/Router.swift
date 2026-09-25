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

public protocol Router {
    func addHandler(_ handler: RouteHandler)
    
    @discardableResult
    func handle(_ userActivity: NSUserActivity) -> Bool
    
    func action(for userActivity: NSUserActivity) -> Action?
    
    @discardableResult
    func handle(_ url: URL) -> Bool
    
    func action(for url: URL) -> Action?
    
    func isValidDomain(for url: URL) -> Bool
}

/// Answers whether the router would claim a URL, without building the action for it.
///
/// `Router.action(for:)` materializes the matching `Action` — for an experience link
/// that is an `ExperienceViewController` and a fetch — so a caller that only needs a
/// yes or no (the Hub's link classifier deciding whether a tapped link is Rover's) asks
/// this instead. Package-visible rather than public on purpose: `Router` is public API
/// and stays as it is; `RouterService` conforms.
package protocol RouterLinkClassifying {
    /// `true` for a URL on one of the Rover URL schemes this router was configured with.
    func isDeepLink(url: URL) -> Bool

    /// `true` for an http(s) URL on one of the associated domains this router was
    /// configured with.
    func isUniversalLink(url: URL) -> Bool
}
