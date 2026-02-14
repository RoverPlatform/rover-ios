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

/// Activity attributes for NFL game live activities.
///
/// Use this type with `Activity<RoverNFLActivityAttributes>` to display live NFL game
/// updates on the Lock Screen and Dynamic Island.
/// Server type reference: NFLLiveActivityEvent in live-activities/types.ts
@available(iOS 16.1, *)
public struct RoverNFLActivityAttributes: ActivityAttributes {

    // MARK: - Activity Name

    /// The activity name used for push-to-start token registration.
    public static let activityName = "RoverNFLActivityAttributes"

    // MARK: - Static Attributes (NFLMatchup)
    // These values are set when the Live Activity starts and do not change

    /// Unique identifier for the game
    public var gameID: String

    /// Week number in the season
    public var week: Int

    /// Display title for the matchup (e.g., "Eagles vs Cowboys")
    public var matchupTitle: String

    /// Name of the stadium where the game is being played
    public var venueName: String

    /// Whether our team is playing at home (true) or away (false)
    public var isHomeTeam: Bool

    /// Information about our team
    public var ourTeam: NFLTeamInfo

    /// Information about the opponent team
    public var theirTeam: NFLTeamInfo

    // MARK: - Content State
    // Dynamic values that update throughout the game

    public typealias ContentState = NFLContentState

    public init(
        gameID: String,
        week: Int,
        matchupTitle: String,
        ourTeam: NFLTeamInfo,
        theirTeam: NFLTeamInfo,
        venueName: String,
        isHomeTeam: Bool
    ) {
        self.gameID = gameID
        self.week = week
        self.matchupTitle = matchupTitle
        self.ourTeam = ourTeam
        self.theirTeam = theirTeam
        self.venueName = venueName
        self.isHomeTeam = isHomeTeam
    }
}
