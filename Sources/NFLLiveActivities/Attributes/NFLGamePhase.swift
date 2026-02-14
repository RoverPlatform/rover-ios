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

// MARK: - NFL Game Phase

/// Represents the current phase of an NFL game with a description of the phase.
public struct NFLGamePhase: Codable, Hashable {
    public let description: String
    public let phase: NFLPhase

    public init(description: String, phase: NFLPhase) {
        self.description = description
        self.phase = phase
    }

    public var isPlaying: Bool {
        switch self.phase {
        case .q1, .q2, .q3, .q4, .overtime:
            return true
        case .pregame, .q1End, .q2End, .halfTime, .q3End, .q4End, .final:
            return false
        }
    }

    public var shouldShowLastPlay: Bool {
        switch self.phase {
        case .q1, .q1End, .q2, .q2End, .halfTime, .q3, .q3End, .q4, .q4End, .overtime:
            return true
        case .pregame, .final:
            return false
        }
    }
}
