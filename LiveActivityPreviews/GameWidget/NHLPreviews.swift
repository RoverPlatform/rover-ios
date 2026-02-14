import RoverNHLLiveActivities
import SwiftUI
import WidgetKit

// MARK: - Previews

#Preview("NHL", as: .content, using: RoverNHLActivityAttributes.preview) {
    RoverNHLLiveActivity()
} contentStates: {
    NHLContentState.previewPregame
    NHLContentState.previewWinning
    NHLContentState.previewEndOfPeriod
    NHLContentState.previewIntermission
    NHLContentState.previewLosing
    NHLContentState.previewFinal
}

// MARK: - Preview Helpers

extension RoverNHLActivityAttributes {
    fileprivate static var preview: RoverNHLActivityAttributes {
        RoverNHLActivityAttributes(
            gameID: "preview-game",
            matchupTitle: "Maple Leafs vs Canadiens",
            venueName: "Scotiabank Arena",
            isHomeTeam: true,
            broadcasters: "TSN",
            ourTeam: NHLTeamInfo(name: "Toronto Maple Leafs", city: "Toronto", abbreviation: "TOR"),
            theirTeam: NHLTeamInfo(name: "Montreal Canadiens", city: "Montreal", abbreviation: "MTL")
        )
    }
}

extension NHLContentState {
    fileprivate static var previewWinning: NHLContentState {
        NHLContentState(
            game: NHLGameState(
                period: 2,
                clock: "12:34",
                isClockPaused: false,
                timeRemaining: 754,
                scoreDifferential: 1,
                winning: true,
                gamePhase: .init(description: "2nd", phase: .period2),
                clockEndDate: Date().addingTimeInterval(754)
            ),
            stats: NHLStats(
                ourTeam: NHLTeamStats(
                    scores: NHLScoreStats(
                        totalScore: 2, p1Score: 1, p2Score: 1, p3Score: 0, overtimeScore: 0),
                    shotsOnGoal: NHLShotStats(
                        totalShots: 25, p1Shots: 12, p2Shots: 13, p3Shots: 0, overtimeShots: 0),
                    hits: NHLHitStats(totalHits: 18, p1Hits: 8, p2Hits: 10, p3Hits: 0, overtimeHits: 0)
                ),
                theirTeam: NHLTeamStats(
                    scores: NHLScoreStats(
                        totalScore: 1, p1Score: 0, p2Score: 1, p3Score: 0, overtimeScore: 0),
                    shotsOnGoal: NHLShotStats(
                        totalShots: 22, p1Shots: 10, p2Shots: 12, p3Shots: 0, overtimeShots: 0),
                    hits: NHLHitStats(totalHits: 15, p1Hits: 7, p2Hits: 8, p3Hits: 0, overtimeHits: 0)
                )
            ),
            lastPlay: NHLLastPlay(description: "Goal by Auston Matthews", attribution: .home)
        )
    }
    
    fileprivate static var previewLosing: NHLContentState {
        NHLContentState(
            game: NHLGameState(
                period: 3,
                clock: "2:00",
                isClockPaused: false,
                timeRemaining: 120,
                scoreDifferential: -2,
                winning: false,
                gamePhase: .init(description: "3rd", phase: .period3),
                clockEndDate: Date().addingTimeInterval(120)
            ),
            stats: NHLStats(
                ourTeam: NHLTeamStats(
                    scores: NHLScoreStats(
                        totalScore: 1, p1Score: 0, p2Score: 1, p3Score: 0, overtimeScore: 0),
                    shotsOnGoal: NHLShotStats(
                        totalShots: 28, p1Shots: 12, p2Shots: 10, p3Shots: 6, overtimeShots: 0),
                    hits: NHLHitStats(totalHits: 22, p1Hits: 8, p2Hits: 9, p3Hits: 5, overtimeHits: 0)
                ),
                theirTeam: NHLTeamStats(
                    scores: NHLScoreStats(
                        totalScore: 3, p1Score: 1, p2Score: 1, p3Score: 1, overtimeScore: 0),
                    shotsOnGoal: NHLShotStats(
                        totalShots: 31, p1Shots: 11, p2Shots: 12, p3Shots: 8, overtimeShots: 0),
                    hits: NHLHitStats(totalHits: 19, p1Hits: 6, p2Hits: 8, p3Hits: 5, overtimeHits: 0)
                )
            ),
            lastPlay: NHLLastPlay(description: "Goal by Nathan MacKinnon", attribution: .away)
        )
    }
    
    fileprivate static var previewPregame: NHLContentState {
        NHLContentState(
            game: NHLGameState(
                period: 0,
                clock: nil,
                isClockPaused: false,
                timeRemaining: 0,
                scoreDifferential: 0,
                winning: false,
                gamePhase: .init(description: "Starting Soon", phase: .pregame),
                clockEndDate: nil
            ),
            stats: NHLStats(
                ourTeam: NHLTeamStats(
                    scores: NHLScoreStats(
                        totalScore: 0, p1Score: 0, p2Score: 0, p3Score: 0, overtimeScore: 0),
                    shotsOnGoal: NHLShotStats(
                        totalShots: 0, p1Shots: 0, p2Shots: 0, p3Shots: 0, overtimeShots: 0),
                    hits: NHLHitStats(totalHits: 0, p1Hits: 0, p2Hits: 0, p3Hits: 0, overtimeHits: 0)
                ),
                theirTeam: NHLTeamStats(
                    scores: NHLScoreStats(
                        totalScore: 0, p1Score: 0, p2Score: 0, p3Score: 0, overtimeScore: 0),
                    shotsOnGoal: NHLShotStats(
                        totalShots: 0, p1Shots: 0, p2Shots: 0, p3Shots: 0, overtimeShots: 0),
                    hits: NHLHitStats(totalHits: 0, p1Hits: 0, p2Hits: 0, p3Hits: 0, overtimeHits: 0)
                )
            ),
            lastPlay: nil
        )
    }
    
    fileprivate static var previewEndOfPeriod: NHLContentState {
        NHLContentState(
            game: NHLGameState(
                period: 1,
                clock: nil,
                isClockPaused: false,
                timeRemaining: 0,
                scoreDifferential: 0,
                winning: false,
                gamePhase: .init(description: "1st End", phase: .period1),
                clockEndDate: nil
            ),
            stats: NHLStats(
                ourTeam: NHLTeamStats(
                    scores: NHLScoreStats(
                        totalScore: 1, p1Score: 1, p2Score: 0, p3Score: 0, overtimeScore: 0),
                    shotsOnGoal: NHLShotStats(
                        totalShots: 12, p1Shots: 12, p2Shots: 0, p3Shots: 0, overtimeShots: 0),
                    hits: NHLHitStats(totalHits: 8, p1Hits: 8, p2Hits: 0, p3Hits: 0, overtimeHits: 0)
                ),
                theirTeam: NHLTeamStats(
                    scores: NHLScoreStats(
                        totalScore: 1, p1Score: 1, p2Score: 0, p3Score: 0, overtimeScore: 0),
                    shotsOnGoal: NHLShotStats(
                        totalShots: 10, p1Shots: 10, p2Shots: 0, p3Shots: 0, overtimeShots: 0),
                    hits: NHLHitStats(totalHits: 7, p1Hits: 7, p2Hits: 0, p3Hits: 0, overtimeHits: 0)
                )
            ),
            lastPlay: NHLLastPlay(description: "End of 1st Period", attribution: .neutral)
        )
    }
    
    fileprivate static var previewIntermission: NHLContentState {
        NHLContentState(
            game: NHLGameState(
                period: 2,
                clock: nil,
                isClockPaused: false,
                timeRemaining: 0,
                scoreDifferential: 1,
                winning: true,
                gamePhase: .init(description: "Intermission", phase: .intermission2),
                clockEndDate: nil
            ),
            stats: NHLStats(
                ourTeam: NHLTeamStats(
                    scores: NHLScoreStats(
                        totalScore: 3, p1Score: 1, p2Score: 2, p3Score: 0, overtimeScore: 0),
                    shotsOnGoal: NHLShotStats(
                        totalShots: 24, p1Shots: 12, p2Shots: 12, p3Shots: 0, overtimeShots: 0),
                    hits: NHLHitStats(totalHits: 16, p1Hits: 8, p2Hits: 8, p3Hits: 0, overtimeHits: 0)
                ),
                theirTeam: NHLTeamStats(
                    scores: NHLScoreStats(
                        totalScore: 2, p1Score: 1, p2Score: 1, p3Score: 0, overtimeScore: 0),
                    shotsOnGoal: NHLShotStats(
                        totalShots: 21, p1Shots: 10, p2Shots: 11, p3Shots: 0, overtimeShots: 0),
                    hits: NHLHitStats(totalHits: 14, p1Hits: 7, p2Hits: 7, p3Hits: 0, overtimeHits: 0)
                )
            ),
            lastPlay: NHLLastPlay(description: "End of 2nd Period", attribution: .neutral)
        )
    }
    
    fileprivate static var previewFinal: NHLContentState {
        NHLContentState(
            game: NHLGameState(
                period: 3,
                clock: nil,
                isClockPaused: false,
                timeRemaining: 0,
                scoreDifferential: 2,
                winning: true,
                gamePhase: .init(description: "Final", phase: .final),
                clockEndDate: nil
            ),
            stats: NHLStats(
                ourTeam: NHLTeamStats(
                    scores: NHLScoreStats(
                        totalScore: 4, p1Score: 1, p2Score: 2, p3Score: 1, overtimeScore: 0),
                    shotsOnGoal: NHLShotStats(
                        totalShots: 32, p1Shots: 12, p2Shots: 12, p3Shots: 8, overtimeShots: 0),
                    hits: NHLHitStats(totalHits: 24, p1Hits: 8, p2Hits: 8, p3Hits: 8, overtimeHits: 0)
                ),
                theirTeam: NHLTeamStats(
                    scores: NHLScoreStats(
                        totalScore: 2, p1Score: 1, p2Score: 1, p3Score: 0, overtimeScore: 0),
                    shotsOnGoal: NHLShotStats(
                        totalShots: 28, p1Shots: 10, p2Shots: 11, p3Shots: 7, overtimeShots: 0),
                    hits: NHLHitStats(totalHits: 20, p1Hits: 7, p2Hits: 7, p3Hits: 6, overtimeHits: 0)
                )
            ),
            lastPlay: nil
        )
    }
}
