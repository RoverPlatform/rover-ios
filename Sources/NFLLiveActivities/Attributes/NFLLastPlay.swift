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

// MARK: - Last Play

/// Information about the last significant play
public struct NFLLastPlay: Codable, Hashable {
    /// Description of the play
    /// Examples:
    /// - "P.Mahomes pass to T.Kelce for 15 yards"
    /// - "J.Hurts rushes for 3 yards, TOUCHDOWN"
    /// - "J.Tucker 52 yard field goal is GOOD"
    public let description: String

    /// Which team the play is attributed to
    /// Values: "home", "away", "neutral"
    public let attribution: NFLPlayAttribution

    public init(description: String, attribution: NFLPlayAttribution) {
        self.description = description
        self.attribution = attribution
    }
}
