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
public struct NBALastPlay: Codable, Hashable {
    /// Description of the play
    /// Examples:
    /// - "L. James 3PT Jump Shot (25 PTS)"
    /// - "S. Curry driving layup (18 PTS) (D. Green AST)"
    /// - "J. Tatum free throw 2 of 2"
    public let description: String
    
    /// Which team the play is attributed to
    /// Values: "home", "away", "neutral"
    public let attribution: NBAPlayAttribution
    
    public init(description: String, attribution: NBAPlayAttribution) {
        self.description = description
        self.attribution = attribution
    }
}
