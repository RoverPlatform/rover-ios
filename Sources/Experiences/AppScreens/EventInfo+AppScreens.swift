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
import RoverData

extension EventInfo {
    /// Creates an "App Screen Viewed" event for analytics.
    /// - Parameter screenURL: The absolute URL of the App Screen being viewed,
    ///   query included. An App Screen has no ID the SDK ever sees, so the URL is
    ///   the screen's whole identity.
    /// - Returns: EventInfo configured for App Screen view tracking.
    static func appScreenViewed(screenURL: URL) -> EventInfo {
        return EventInfo(
            name: "App Screen Viewed",
            namespace: "rover",
            attributes: [
                "screenURL": screenURL.absoluteString
            ]
        )
    }

    /// Creates an "App Screen Link Clicked" event for analytics.
    /// - Parameters:
    ///   - screenURL: The absolute URL of the App Screen the link was tapped on.
    ///   - linkURL: The resolved absolute URL of the tapped link.
    /// - Returns: EventInfo configured for App Screen link click tracking.
    static func appScreenLinkClicked(screenURL: URL, linkURL: URL) -> EventInfo {
        return EventInfo(
            name: "App Screen Link Clicked",
            namespace: "rover",
            attributes: [
                "screenURL": screenURL.absoluteString,
                "linkURL": linkURL.absoluteString
            ]
        )
    }
}
