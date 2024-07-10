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

/// Describes a user's screen view in a Rover experience. A value of this type is given to the registered screen view callback registered with the shared Rover foundation object.
///
/// This type provides the context for the user screen view, giving the screen, and experience ids and names in addition to the data context (URL parameters, user info, and data from a Web API data source).

public struct ScreenViewedEvent {
    @available(*, deprecated, renamed: "experienceID")
    public let experienceId: String?
    public let experienceID: String?
    public let experienceName: String?
    public let experienceUrl: URL?
    
    @available(*, deprecated, renamed: "screenID")
    public let screenId: String
    public let screenID: String
    public let screenName: String?
    public let screenProperties: [String: String]
    public let screenTags: Set<String>
    
    @available(*, deprecated, renamed: "campaignID")
    public let campaignId: String?
    public let campaignID: String?

    /// This value can be any of the types one might typically find in decoded JSON, ie., String, Int, dictionaries, arrays, and so on.
    public let data: Any?
    public let urlParameters: [String: String]
}
