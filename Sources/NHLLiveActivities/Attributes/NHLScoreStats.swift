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

/// Tracks goals scored by period, including regulation periods and overtime.
/// overtimeScore accumulates goals from all overtime periods combined.
public struct NHLScoreStats: Codable, Hashable {
    /// Total goals scored across all periods
    public let totalScore: Int

    /// Goals scored in the first period
    public let p1Score: Int

    /// Goals scored in the second period
    public let p2Score: Int

    /// Goals scored in the third period
    public let p3Score: Int

    /// Goals scored in overtime periods (combined across all OT periods)
    public let overtimeScore: Int

    /// Creates NHLScoreStats
    public init(totalScore: Int, p1Score: Int, p2Score: Int, p3Score: Int, overtimeScore: Int) {
        self.totalScore = totalScore
        self.p1Score = p1Score
        self.p2Score = p2Score
        self.p3Score = p3Score
        self.overtimeScore = overtimeScore
    }   
}
