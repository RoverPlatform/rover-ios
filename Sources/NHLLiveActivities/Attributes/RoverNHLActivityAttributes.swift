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

/// Activity attributes for NHL game live activities.
///
/// Use this type with `Activity<RoverNHLActivityAttributes>` to display live NHL game
/// updates on the Lock Screen and Dynamic Island. This struct contains static information
/// about the game that doesn't change during the live activity lifecycle.
@available(iOS 16.1, *)
public struct RoverNHLActivityAttributes: ActivityAttributes {
    /// The activity name used for push-to-start token registration.
    public static let activityName = "RoverNHLActivityAttributes"

    // MARK: - Static Attributes

    /// Unique identifier for the game
    public let gameID: String

    /// Display title for the matchup (e.g., "Maple Leafs vs Canadiens")
    public let matchupTitle: String

    /// Name of the venue where the game is being played
    public let venueName: String

    /// Whether the user's team is the home team
    public let isHomeTeam: Bool

    /// Information about broadcasting for the game
    public let broadcasters: String?

    /// Information about the user's preferred team
    public let ourTeam: NHLTeamInfo

    /// Information about the opposing team
    public let theirTeam: NHLTeamInfo

    /// Type alias for the dynamic content state that updates during the game
    public typealias ContentState = NHLContentState

    /// Creates a new RoverNHLActivityAttributes instance
    /// - Parameters:
    ///   - gameID: Unique identifier for the game
    ///   - matchupTitle: Display title for the matchup
    ///   - venueName: Name of the venue where the game is being played
    ///   - isHomeTeam: Whether the user's team is the home team
    ///   - broadcasters: Information about broadcasting for the game
    ///   - ourTeam: Information about the user's preferred team
    ///   - theirTeam: Information about the opposing team
    public init(
        gameID: String,
        matchupTitle: String,
        venueName: String,
        isHomeTeam: Bool,
        broadcasters: String?,
        ourTeam: NHLTeamInfo,
        theirTeam: NHLTeamInfo
    ) {
        self.gameID = gameID
        self.matchupTitle = matchupTitle
        self.venueName = venueName
        self.isHomeTeam = isHomeTeam
        self.broadcasters = broadcasters
        self.ourTeam = ourTeam
        self.theirTeam = theirTeam
    }
}
