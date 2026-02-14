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

// MARK: - NHL Phase

/// Represents the current phase of an NHL game, including regulation periods,
/// intermissions, overtime periods, and special situations like shootouts.
public enum NHLPhase: String, Codable, Hashable {
    /// Game has not started yet
    case pregame

    /// First regulation period
    case period1

    /// Intermission between first and second periods
    case intermission1

    /// Second regulation period
    case period2

    /// Intermission between second and third periods
    case intermission2

    /// Third regulation period
    case period3

    /// Overtime period (generic)
    case overtime

    /// First overtime period (5-minute sudden death)
    case overtime1

    /// Second overtime period (5-minute sudden death)
    case overtime2

    /// Third overtime period (5-minute sudden death)
    case overtime3

    /// Fourth overtime period (5-minute sudden death)
    case overtime4

    /// Fifth overtime period (5-minute sudden death)
    case overtime5

    /// Shootout to determine winner
    case shootout

    /// Game has concluded
    case final
}
