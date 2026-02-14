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

// MARK: - Game State

/// Current state of the NFL game
public struct NFLGameState: Codable, Hashable {
    /// Current phase of the game
    public let gamePhase: NFLGamePhase

    /// Game clock display string or nil during breaks
    /// Format: "MM:SS" (e.g., "15:00", "2:30", "0:14")
    /// nil during halftime or other breaks
    public let clock: String?

    /// Time remaining in the current quarter in seconds
    /// Range: 0-900 (15 minutes per quarter, 10 min OT regular season)
    public let timeRemaining: Int

    /// Whether our team currently has possession of the ball
    public let inPossession: Bool

    /// Absolute point difference between teams (always positive)
    public let scoreDifferential: Int

    /// Whether our team is currently winning (ourScore > theirScore)
    public let winning: Bool

    /// The date when the current quarter ends, provided by the backend as an ISO8601 string.
    /// Optional because pre-game states don't have a running clock.
    public var clockEndDate: Date?

    /// Whether the game clock is currently stopped
    /// true during timeouts, between plays, reviews, etc.
    public let isClockPaused: Bool

    public var clockString: String {
        clock ?? "--:--"
    }

    private enum CodingKeys: String, CodingKey {
        case gamePhase
        case clock
        case timeRemaining
        case inPossession
        case scoreDifferential
        case winning
        case clockEndDate
        case isClockPaused
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gamePhase = try container.decode(NFLGamePhase.self, forKey: .gamePhase)
        clock = try container.decodeIfPresent(String.self, forKey: .clock)
        timeRemaining = try container.decode(Int.self, forKey: .timeRemaining)
        inPossession = try container.decode(Bool.self, forKey: .inPossession)
        scoreDifferential = try container.decode(Int.self, forKey: .scoreDifferential)
        winning = try container.decode(Bool.self, forKey: .winning)

        // clockEndDate is provided by the backend as an ISO8601 string.
        // We decode it as a String (not Date) because the backend may send dates with or without
        // fractional seconds, and Swift's default Date decoding doesn't handle both formats.
        if let clockEndDateString = try container.decodeIfPresent(String.self, forKey: .clockEndDate) {
            clockEndDate = ISO8601DateDecoder.decode(clockEndDateString)
        } else {
            clockEndDate = nil
        }

        isClockPaused = try container.decodeIfPresent(Bool.self, forKey: .isClockPaused) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(gamePhase, forKey: .gamePhase)
        try container.encodeIfPresent(clock, forKey: .clock)
        try container.encode(timeRemaining, forKey: .timeRemaining)
        try container.encode(inPossession, forKey: .inPossession)
        try container.encode(scoreDifferential, forKey: .scoreDifferential)
        try container.encode(winning, forKey: .winning)
        // Encode clockEndDate as an ISO8601 string to maintain format consistency with the backend
        // and ensure stable rehydration when iOS restores the Live Activity.
        if let clockEndDate = clockEndDate {
            try container.encode(ISO8601DateEncoder.encode(clockEndDate), forKey: .clockEndDate)
        }
        try container.encode(isClockPaused, forKey: .isClockPaused)
    }

    public init(
        gamePhase: NFLGamePhase,
        clock: String?,
        timeRemaining: Int,
        inPossession: Bool,
        scoreDifferential: Int,
        winning: Bool,
        isClockPaused: Bool,
        clockEndDate: Date?
    ) {
        self.gamePhase = gamePhase
        self.clock = clock
        self.timeRemaining = timeRemaining
        self.inPossession = inPossession
        self.scoreDifferential = scoreDifferential
        self.winning = winning
        self.clockEndDate = clockEndDate
        self.isClockPaused = isClockPaused
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
