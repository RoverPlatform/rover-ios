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
    /// Creates a "Post Opened" event for analytics
    /// - Parameter postID: The ID of the post that was opened
    /// - Returns: EventInfo configured for post opened tracking
    static func postOpened(postID: UUID) -> EventInfo {
        return EventInfo(
            name: "Post Opened",
            namespace: "rover",
            attributes: [
                "postID": postID.uuidString
            ]
        )
    }
    
    /// Creates a "Post Link Clicked" event for analytics
    /// - Parameters:
    ///   - postID: The ID of the post containing the link
    ///   - link: The URL of the link that was clicked
    /// - Returns: EventInfo configured for post link click tracking
    static func postLinkClicked(postID: UUID, link: String) -> EventInfo {
        return EventInfo(
            name: "Post Link Clicked",
            namespace: "rover",
            attributes: [
                "postID": postID.uuidString,
                "link": link
            ]
        )
    }
}