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

/// Dynamic content state for NHL Live Activities, containing the current game state,
/// statistics for both teams, and information about the most recent play.
public struct NHLContentState: Codable, Hashable {
    /// Current state of the game including clock, score, and phase
    public let game: NHLGameState
    
    /// Comprehensive statistics for both teams
    public let stats: NHLStats
    
    /// Information about the most recent play, or nil if no recent play
    public let lastPlay: NHLLastPlay?
    
    /// Creates NHLContentState with game and stats, optionally including last play information
    /// - Parameters:
    ///   - game: Current state of the game
    ///   - stats: Statistics for both teams
    ///   - lastPlay: Information about the most recent play, if any
    public init(
        game: NHLGameState,
        stats: NHLStats,
        lastPlay: NHLLastPlay? = nil
    ) {
        self.game = game
        self.stats = stats
        self.lastPlay = lastPlay
    }
}
