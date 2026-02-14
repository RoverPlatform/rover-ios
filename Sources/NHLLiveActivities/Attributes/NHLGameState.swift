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

/// Represents the current state of an NHL game, including clock, score, and game phase.
/// This struct uses custom Codable implementation to preserve clockEndDate across encoding/decoding cycles,
/// ensuring timer stability when iOS restores Live Activities.
public struct NHLGameState: Codable, Hashable {
    /// Current period number (1, 2, 3, or overtime period number)
    public let period: Int

    /// Display string for the game clock (e.g., "15:00", "2:30"), or nil if not available
    public let clock: String?

    /// Whether the game clock is currently paused
    public let isClockPaused: Bool

    /// Time remaining in the current period in seconds
    public let timeRemaining: Int

    /// The absolute score differential between the two teams. Always a non-negative value
    public let scoreDifferential: Int

    /// Whether the user's team is currently winning
    public let winning: Bool

    /// Current phase of the game
    public let gamePhase: NHLGamePhase

    /// The date when the current period ends, provided by the backend as an ISO8601 string.
    /// Optional because pre-game states don't have a running clock.
    public var clockEndDate: Date?

    /// Returns a formatted clock string, defaulting to "--:--" if no clock is available
    public var clockString: String {
        clock ?? "--:--"
    }

    /// Coding keys for custom serialization
    private enum CodingKeys: String, CodingKey {
        case period
        case clock
        case isClockPaused
        case timeRemaining
        case scoreDifferential
        case winning
        case gamePhase
        case clockEndDate
    }

    /// Decodes an NHLGameState from the given decoder.
    /// clockEndDate is decoded if present (preserving timer stability), otherwise computed from timeRemaining.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        period = try container.decode(Int.self, forKey: .period)
        clock = try container.decodeIfPresent(String.self, forKey: .clock)
        isClockPaused = try container.decode(Bool.self, forKey: .isClockPaused)
        timeRemaining = try container.decode(Int.self, forKey: .timeRemaining)
        scoreDifferential = try container.decode(Int.self, forKey: .scoreDifferential)
        winning = try container.decode(Bool.self, forKey: .winning)
        gamePhase = try container.decode(NHLGamePhase.self, forKey: .gamePhase)

        // clockEndDate is provided by the backend as an ISO8601 string.
        // We decode it as a String (not Date) because the backend may send dates with or without
        // fractional seconds, and Swift's default Date decoding doesn't handle both formats.
        if let clockEndDateString = try container.decodeIfPresent(String.self, forKey: .clockEndDate) {
            clockEndDate = ISO8601DateDecoder.decode(clockEndDateString)
        } else {
            clockEndDate = nil
        }
    }

    /// Encodes this NHLGameState to the given encoder.
    /// clockEndDate is always encoded to preserve timer stability.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(period, forKey: .period)
        try container.encodeIfPresent(clock, forKey: .clock)
        try container.encode(isClockPaused, forKey: .isClockPaused)
        try container.encode(timeRemaining, forKey: .timeRemaining)
        try container.encode(scoreDifferential, forKey: .scoreDifferential)
        try container.encode(winning, forKey: .winning)
        try container.encode(gamePhase, forKey: .gamePhase)
        // Encode clockEndDate as an ISO8601 string to maintain format consistency with the backend
        // and ensure stable rehydration when iOS restores the Live Activity.
        if let clockEndDate = clockEndDate {
            try container.encode(ISO8601DateEncoder.encode(clockEndDate), forKey: .clockEndDate)
        }
    }

    /// Creates a new NHLGameState with the specified parameters.
    public init(
        period: Int,
        clock: String?,
        isClockPaused: Bool,
        timeRemaining: Int,
        scoreDifferential: Int,
        winning: Bool,
        gamePhase: NHLGamePhase,
        clockEndDate: Date?
    ) {
        self.period = period
        self.clock = clock
        self.isClockPaused = isClockPaused
        self.timeRemaining = timeRemaining
        self.scoreDifferential = scoreDifferential
        self.winning = winning
        self.gamePhase = gamePhase
        self.clockEndDate = clockEndDate
    }
}

// MARK: - ISO8601 Date Coding

private enum ISO8601DateDecoder {
    private static let withFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func decode(_ dateString: String) -> Date? {
        withFractional.date(from: dateString) ?? standard.date(from: dateString)
    }
}

private enum ISO8601DateEncoder {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func encode(_ date: Date) -> String {
        formatter.string(from: date)
    }
}
