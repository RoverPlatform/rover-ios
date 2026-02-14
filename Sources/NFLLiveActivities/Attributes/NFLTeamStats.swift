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

// MARK: - Team Stats

/// Comprehensive statistics for an NFL team during the game
public struct NFLTeamStats: Codable, Hashable {
    // MARK: - Score Totals

    /// Total points scored in the game
    public let totalScore: Int

    /// Points scored in the first quarter
    public let q1Score: Int

    /// Points scored in the second quarter
    public let q2Score: Int

    /// Points scored in the third quarter
    public let q3Score: Int

    /// Points scored in the fourth quarter
    public let q4Score: Int

    /// Points scored in overtime (0 if no overtime)
    public let overtimeScore: Int

    /// Total scoring plays including offensive and defensive touchdowns, field goals and safeties
    /// Server sends computed: totalTouchdowns + fieldGoalsMade + safeties
    public let totalScoringPlays: Int

    // MARK: - Touchdowns

    /// Total touchdowns scored (all types)
    /// Server sends computed: offensiveTouchdowns + defensiveTouchdowns + otherTouchdowns
    public let totalTouchdowns: Int

    /// Total touchdowns scored by the offense
    /// Server sends computed: passingTouchdowns + rushingTouchdowns
    public let offensiveTouchdowns: Int

    /// Touchdowns from completed passes
    public let passingTouchdowns: Int

    /// Touchdowns from rushing plays
    public let rushingTouchdowns: Int

    /// Touchdowns scored by the defense (pick-six, fumble return, etc.)
    public let defensiveTouchdowns: Int

    /// Other touchdowns (kick/punt returns, blocked kicks, etc.)
    public let otherTouchdowns: Int

    // MARK: - Field Goals & Extra Points

    /// Number of field goal attempts
    public let fieldGoalAttempts: Int

    /// Number of successful field goals (3 points each)
    public let fieldGoalsMade: Int

    /// Number of extra point (PAT) attempts after touchdowns
    public let extraPointAttempts: Int

    /// Number of successful extra points (1 point each)
    public let extraPointsMade: Int

    // MARK: - Two-Point Conversions

    /// Total successful two-point conversions (2 points each)
    /// Server sends computed: twoPointConversionsMadePassing + twoPointConversionsMadeRushing
    public let twoPointConversionsMade: Int

    /// Total two-point conversion attempts by the offense
    /// Server sends computed: twoPointConversionPassingAttempts + twoPointConversionRushingAttempts
    public let twoPointConversionAttempts: Int

    /// Two-point conversion attempts via passing play
    public let twoPointConversionPassingAttempts: Int

    /// Two-point conversion attempts via rushing play
    public let twoPointConversionRushingAttempts: Int

    /// Successful two-point conversions via passing (2 points each)
    public let twoPointConversionsMadePassing: Int

    /// Successful two-point conversions via rushing (2 points each)
    public let twoPointConversionsMadeRushing: Int

    // MARK: - Defensive Stats

    /// Quarterback sacks by this team's defense
    public let sacks: Int

    /// Passes intercepted by this team's defense
    public let interceptions: Int

    /// Opponent fumbles recovered by this team's defense
    public let fumbleRecoveries: Int

    /// Safeties scored (2 points each, tackling opponent in their end zone)
    public let safeties: Int

    // MARK: - Other Stats

    /// Total first downs achieved (keeps drives alive)
    public let totalFirstDowns: Int

    public init(
        totalScore: Int = 0,
        q1Score: Int = 0,
        q2Score: Int = 0,
        q3Score: Int = 0,
        q4Score: Int = 0,
        overtimeScore: Int = 0,
        totalScoringPlays: Int = 0,
        totalTouchdowns: Int = 0,
        offensiveTouchdowns: Int = 0,
        passingTouchdowns: Int = 0,
        rushingTouchdowns: Int = 0,
        defensiveTouchdowns: Int = 0,
        otherTouchdowns: Int = 0,
        fieldGoalAttempts: Int = 0,
        fieldGoalsMade: Int = 0,
        extraPointAttempts: Int = 0,
        extraPointsMade: Int = 0,
        twoPointConversionsMade: Int = 0,
        twoPointConversionAttempts: Int = 0,
        twoPointConversionPassingAttempts: Int = 0,
        twoPointConversionRushingAttempts: Int = 0,
        twoPointConversionsMadePassing: Int = 0,
        twoPointConversionsMadeRushing: Int = 0,
        sacks: Int = 0,
        interceptions: Int = 0,
        fumbleRecoveries: Int = 0,
        safeties: Int = 0,
        totalFirstDowns: Int = 0
    ) {
        self.totalScore = totalScore
        self.q1Score = q1Score
        self.q2Score = q2Score
        self.q3Score = q3Score
        self.q4Score = q4Score
        self.overtimeScore = overtimeScore
        self.totalScoringPlays = totalScoringPlays
        self.totalTouchdowns = totalTouchdowns
        self.offensiveTouchdowns = offensiveTouchdowns
        self.passingTouchdowns = passingTouchdowns
        self.rushingTouchdowns = rushingTouchdowns
        self.defensiveTouchdowns = defensiveTouchdowns
        self.otherTouchdowns = otherTouchdowns
        self.fieldGoalAttempts = fieldGoalAttempts
        self.fieldGoalsMade = fieldGoalsMade
        self.extraPointAttempts = extraPointAttempts
        self.extraPointsMade = extraPointsMade
        self.twoPointConversionsMade = twoPointConversionsMade
        self.twoPointConversionAttempts = twoPointConversionAttempts
        self.twoPointConversionPassingAttempts = twoPointConversionPassingAttempts
        self.twoPointConversionRushingAttempts = twoPointConversionRushingAttempts
        self.twoPointConversionsMadePassing = twoPointConversionsMadePassing
        self.twoPointConversionsMadeRushing = twoPointConversionsMadeRushing
        self.sacks = sacks
        self.interceptions = interceptions
        self.fumbleRecoveries = fumbleRecoveries
        self.safeties = safeties
        self.totalFirstDowns = totalFirstDowns
    }
}
