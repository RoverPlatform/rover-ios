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
import Foundation

// MARK: - Content State

/// The dynamic content state that updates throughout the game
public struct NFLContentState: Codable, Hashable {
    /// Current game state (quarter, clock, possession)
    public let game: NFLGameState

    /// Statistics for both teams
    public let stats: NFLStats

    /// Information about the last significant play
    /// Examples:
    /// - "P.Mahomes pass to T.Kelce for 15 yards"
    /// - "J.Hurts rushes for 3 yards, TOUCHDOWN"
    /// - "J.Tucker 52 yard field goal is GOOD"
    /// null when no play description is available
    public let lastPlay: NFLLastPlay?

    public init(
        game: NFLGameState,
        stats: NFLStats,
        lastPlay: NFLLastPlay?
    ) {
        self.game = game
        self.stats = stats
        self.lastPlay = lastPlay
    }
}
