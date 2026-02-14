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

// MARK: - NHL Game Phase

/// Represents the current phase of an NHL game with a description of the phase.
public struct NHLGamePhase: Codable, Hashable {
    public let description: String
    public let phase: NHLPhase

    public init(description: String, phase: NHLPhase) {
        self.description = description
        self.phase = phase
    }

    public var isPlaying: Bool {
        switch self.phase {
        case .period1, .period2, .period3, .overtime, .overtime1, .overtime2, .overtime3, .overtime4, .overtime5:
            return true
        case .pregame, .intermission1, .intermission2, .shootout, .final:
            return false
        }
    }

    public var shouldShowLastPlay: Bool {
        switch self.phase {
        case .period1, .intermission1, .period2, .intermission2, .period3, .shootout, .final:
            return true
        case .pregame:
            return false
        case .overtime, .overtime1, .overtime2, .overtime3, .overtime4, .overtime5:
            return true
        }
    }
}
