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

/// Represents information about the most recent play or event in an NHL game.
public struct NHLLastPlay: Codable, Hashable {
    /// Human-readable description of the play (e.g., "Goal by Auston Matthews")
    public let description: String

    /// Which team is attributed to this play
    public let attribution: NHLPlayAttribution

    /// Creates a new NHLLastPlay instance
    /// - Parameters:
    ///   - description: Human-readable description of the play
    ///   - attribution: Which team is attributed to this play
    public init(description: String, attribution: NHLPlayAttribution) {
        self.description = description
        self.attribution = attribution
    }
}
