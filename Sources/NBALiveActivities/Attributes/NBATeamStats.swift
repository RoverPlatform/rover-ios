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

/// Team statistics for an NBA game
public struct NBATeamStats: Codable, Hashable {
    
    // MARK: - Score Totals
    
    /// Total points scored in the game
    public var totalScore: Int
    
    /// Points scored in the first quarter
    public var q1Score: Int
    
    /// Points scored in the second quarter
    public var q2Score: Int
    
    /// Points scored in the third quarter
    public var q3Score: Int
    
    /// Points scored in the fourth quarter
    public var q4Score: Int
    
    /// Points scored in all overtime periods combined
    public var overtimeScore: Int
    
    /// Total number of made field goals (2PT + 3PT, not including free throws)
    public var totalScoringPlays: Int
    
    // MARK: - Field Goals (2-pointers and all shots)
    
    /// Total field goal attempts (2PT + 3PT)
    public var fieldGoalsAttempted: Int
    
    /// Total field goals made (2PT + 3PT)
    public var fieldGoalsMade: Int
    
    /// Field goal percentage (0.0-100.0)
    /// Calculated: (fieldGoalsMade / fieldGoalsAttempted) * 100
    public var fieldGoalPercentage: Double
    
    // MARK: - Three-Pointers
    
    /// Three-point shot attempts
    public var threePointersAttempted: Int
    
    /// Three-point shots made (3 points each)
    public var threePointersMade: Int
    
    /// Three-point percentage (0.0-100.0)
    public var threePointersPercentage: Double
    
    // MARK: - Free Throws
    
    /// Free throw attempts
    public var freeThrowsAttempted: Int
    
    /// Free throws made (1 point each)
    public var freeThrowsMade: Int
    
    /// Free throw percentage (0.0-100.0)
    public var freeThrowsPercentage: Double
    
    // MARK: - Rebounds
    
    /// Total rebounds (offensive + defensive)
    public var totalRebounds: Int
    
    /// Offensive rebounds (chances for second-chance points)
    public var offensiveRebounds: Int
    
    /// Defensive rebounds
    public var defensiveRebounds: Int
    
    // MARK: - Fouls
    
    /// Total team fouls (all types combined)
    public var totalFouls: Int
    
    /// Personal fouls committed
    public var personalFouls: Int
    
    /// Technical fouls assessed
    public var technicalFouls: Int
    
    /// Flagrant fouls (flagrant 1 or flagrant 2)
    public var flagrantFouls: Int
    
    /// Fouls drawn (fouls committed by opponent against this team)
    public var foulsDrawn: Int
    
    // MARK: - Defensive Stats
    
    /// Steals (taking ball from opponent)
    public var steals: Int
    
    /// Blocked shots
    public var blocks: Int
    
    /// Shot clock violations forced on opponent
    public var shotClockViolations: Int
    
    /// Offensive fouls (charges) drawn
    public var chargesDrawn: Int
    
    // MARK: - Ball Movement
    
    /// Assists (passes leading directly to made baskets)
    public var assists: Int
    
    /// Turnovers (lost possessions)
    public var turnovers: Int
    
    /// Assist-to-turnover ratio
    /// Calculated: assists / turnovers (0.0 if no turnovers)
    /// Higher is better (e.g., 2.0 means 2 assists per turnover)
    public var assistToTurnoverRatio: Double
    
    // MARK: - Timeouts
    
    /// Timeouts used in the game
    public var timeoutsCalled: Int
    
    /// Timeouts remaining
    /// NBA teams get 7 timeouts per game (4 in 4th quarter max)
    public var timeoutsRemaining: Int
    
    public init(
        totalScore: Int = 0,
        q1Score: Int = 0,
        q2Score: Int = 0,
        q3Score: Int = 0,
        q4Score: Int = 0,
        overtimeScore: Int = 0,
        totalScoringPlays: Int = 0,
        fieldGoalsAttempted: Int = 0,
        fieldGoalsMade: Int = 0,
        fieldGoalPercentage: Double = 0.0,
        threePointersAttempted: Int = 0,
        threePointersMade: Int = 0,
        threePointersPercentage: Double = 0.0,
        freeThrowsAttempted: Int = 0,
        freeThrowsMade: Int = 0,
        freeThrowsPercentage: Double = 0.0,
        totalRebounds: Int = 0,
        offensiveRebounds: Int = 0,
        defensiveRebounds: Int = 0,
        totalFouls: Int = 0,
        personalFouls: Int = 0,
        technicalFouls: Int = 0,
        flagrantFouls: Int = 0,
        foulsDrawn: Int = 0,
        steals: Int = 0,
        blocks: Int = 0,
        shotClockViolations: Int = 0,
        chargesDrawn: Int = 0,
        assists: Int = 0,
        turnovers: Int = 0,
        assistToTurnoverRatio: Double = 0.0,
        timeoutsCalled: Int = 0,
        timeoutsRemaining: Int = 0
    ) {
        self.totalScore = totalScore
        self.q1Score = q1Score
        self.q2Score = q2Score
        self.q3Score = q3Score
        self.q4Score = q4Score
        self.overtimeScore = overtimeScore
        self.totalScoringPlays = totalScoringPlays
        self.fieldGoalsAttempted = fieldGoalsAttempted
        self.fieldGoalsMade = fieldGoalsMade
        self.fieldGoalPercentage = fieldGoalPercentage
        self.threePointersAttempted = threePointersAttempted
        self.threePointersMade = threePointersMade
        self.threePointersPercentage = threePointersPercentage
        self.freeThrowsAttempted = freeThrowsAttempted
        self.freeThrowsMade = freeThrowsMade
        self.freeThrowsPercentage = freeThrowsPercentage
        self.totalRebounds = totalRebounds
        self.offensiveRebounds = offensiveRebounds
        self.defensiveRebounds = defensiveRebounds
        self.totalFouls = totalFouls
        self.personalFouls = personalFouls
        self.technicalFouls = technicalFouls
        self.flagrantFouls = flagrantFouls
        self.foulsDrawn = foulsDrawn
        self.steals = steals
        self.blocks = blocks
        self.shotClockViolations = shotClockViolations
        self.chargesDrawn = chargesDrawn
        self.assists = assists
        self.turnovers = turnovers
        self.assistToTurnoverRatio = assistToTurnoverRatio
        self.timeoutsCalled = timeoutsCalled
        self.timeoutsRemaining = timeoutsRemaining
    }
}
