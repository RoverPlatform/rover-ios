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

/// Tracks hits by period, including regulation periods and overtime.
public struct NHLHitStats: Codable, Hashable {
    /// Total hits across all periods
    public let totalHits: Int

    /// Hits in the first period
    public let p1Hits: Int

    /// Hits in the second period
    public let p2Hits: Int

    /// Hits in the third period
    public let p3Hits: Int

    /// Hits in overtime periods (combined across all OT periods)
    public let overtimeHits: Int

    /// Creates NHLHitStats
    public init(totalHits: Int, p1Hits: Int, p2Hits: Int, p3Hits: Int, overtimeHits: Int) {
        self.totalHits = totalHits
        self.p1Hits = p1Hits
        self.p2Hits = p2Hits
        self.p3Hits = p3Hits
        self.overtimeHits = overtimeHits
    }
}
