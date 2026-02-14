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

/// Tracks shots on goal by period, including regulation periods and overtime.
public struct NHLShotStats: Codable, Hashable {
    /// Total shots on goal across all periods
    public let totalShots: Int

    /// Shots on goal in the first period
    public let p1Shots: Int

    /// Shots on goal in the second period
    public let p2Shots: Int

    /// Shots on goal in the third period
    public let p3Shots: Int

    /// Shots on goal in overtime periods (combined across all OT periods)
    public let overtimeShots: Int

    /// Creates NHLShotStats
    public init(totalShots: Int, p1Shots: Int, p2Shots: Int, p3Shots: Int, overtimeShots: Int) {
        self.totalShots = totalShots
        self.p1Shots = p1Shots
        self.p2Shots = p2Shots
        self.p3Shots = p3Shots
        self.overtimeShots = overtimeShots
    }
}
