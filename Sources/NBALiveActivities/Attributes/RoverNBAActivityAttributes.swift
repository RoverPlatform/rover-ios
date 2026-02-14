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

/// Activity attributes for NBA game live activities.
///
/// Use this type with `Activity<RoverNBAActivityAttributes>` to display live NBA game
/// updates on the Lock Screen and Dynamic Island.
/// Server type reference: NBALiveActivityEvent in live-activities/types.ts
public struct RoverNBAActivityAttributes: ActivityAttributes {
    
    // MARK: - Activity Name
    
    /// The activity name used for push-to-start token registration.
    public static let activityName = "RoverNBAActivityAttributes"
    
    // MARK: - Static Attributes (NBAMatchup)
    // These values are set when the Live Activity starts and do not change
    
    /// Unique identifier for the game
    public var gameID: String
    
    /// Week number in the season
    public var week: Int
    
    /// Display title for the matchup (e.g., "Lakers vs Celtics")
    public var matchupTitle: String
    
    /// Name of the arena (e.g., "TD Garden", "Crypto.com Arena")
    public var venueName: String
    
    /// Whether our team is playing at home (true) or away (false)
    public var isHomeTeam: Bool
    
    /// Information about our team
    public var ourTeam: NBATeamInfo
    
    /// Information about the opponent team
    public var theirTeam: NBATeamInfo
    
    // MARK: - Optional Broadcast Information
    
    /// TV broadcast summary (e.g., "ESPN, TNT") - optional
    public var tvBroadcastSummary: String?
    
    /// Local TV broadcaster abbreviation (e.g., "NESN") - optional
    public var localTvBroadcasterAbbreviation: String?
    
    /// National TV broadcaster abbreviation (e.g., "ESPN") - optional
    public var nationalTvBroadcasterAbbreviation: String?
    
    /// Radio broadcast summary - optional
    public var radioBroadcastSummary: String?
    
    /// Local radio broadcaster abbreviation - optional
    public var localRadioBroadcasterAbbreviation: String?
    
    /// National radio broadcaster abbreviation - optional
    public var nationalRadioBroadcasterAbbreviation: String?
    
    // MARK: - Content State
    // Dynamic values that update throughout the game
    
    public typealias ContentState = NBAContentState
    
    public init(
        gameID: String,
        week: Int,
        matchupTitle: String,
        ourTeam: NBATeamInfo,
        theirTeam: NBATeamInfo,
        venueName: String,
        isHomeTeam: Bool,
        tvBroadcastSummary: String? = nil,
        localTvBroadcasterAbbreviation: String? = nil,
        nationalTvBroadcasterAbbreviation: String? = nil,
        radioBroadcastSummary: String? = nil,
        localRadioBroadcasterAbbreviation: String? = nil,
        nationalRadioBroadcasterAbbreviation: String? = nil
    ) {
        self.gameID = gameID
        self.week = week
        self.matchupTitle = matchupTitle
        self.ourTeam = ourTeam
        self.theirTeam = theirTeam
        self.venueName = venueName
        self.isHomeTeam = isHomeTeam
        self.tvBroadcastSummary = tvBroadcastSummary
        self.localTvBroadcasterAbbreviation = localTvBroadcasterAbbreviation
        self.nationalTvBroadcasterAbbreviation = nationalTvBroadcasterAbbreviation
        self.radioBroadcastSummary = radioBroadcastSummary
        self.localRadioBroadcasterAbbreviation = localRadioBroadcasterAbbreviation
        self.nationalRadioBroadcasterAbbreviation = nationalRadioBroadcasterAbbreviation
    }
}
