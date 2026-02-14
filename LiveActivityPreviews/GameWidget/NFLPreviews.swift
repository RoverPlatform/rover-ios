import RoverNFLLiveActivities
import SwiftUI
import WidgetKit

// MARK: - Previews

#Preview("NFL", as: .content, using: RoverNFLActivityAttributes.preview) {
    RoverNFLLiveActivity()
} contentStates: {
    NFLContentState.previewPregame
    NFLContentState.previewWinning
    NFLContentState.previewEndOfQuarter
    NFLContentState.previewHalftime
    NFLContentState.previewLosing
    NFLContentState.previewFinal
}

// MARK: - Preview Helpers

extension RoverNFLActivityAttributes {
    fileprivate static var preview: RoverNFLActivityAttributes {
        RoverNFLActivityAttributes(
            gameID: "preview-game",
            week: 1,
            matchupTitle: "Eagles vs Cowboys",
            ourTeam: NFLTeamInfo(name: "Eagles", city: "Philadelphia", abbreviation: "PHI"),
            theirTeam: NFLTeamInfo(name: "Cowboys", city: "Dallas", abbreviation: "DAL"),
            venueName: "Lincoln Financial Field",
            isHomeTeam: true
        )
    }
}

extension NFLContentState {
    fileprivate static var previewWinning: NFLContentState {
        NFLContentState(
            game: .init(
                gamePhase: .init(description: "2nd", phase: .q2),
                clock: "8:42",
                timeRemaining: 522,
                inPossession: true,
                scoreDifferential: 6,
                winning: true,
                isClockPaused: false,
                clockEndDate: Date().addingTimeInterval(522)
            ),
            stats: NFLStats(
                ourTeam: .init(totalScore: 21),
                theirTeam: .init(totalScore: 15)
            ),
            lastPlay: NFLLastPlay(
                description: "J.Hurts pass to A.Brown for 18 yards",
                attribution: .home
            )
        )
    }
    
    fileprivate static var previewEndOfQuarter: NFLContentState {
        NFLContentState(
            game: .init(
                gamePhase: .init(description: "1st End", phase: .q1End),
                clock: nil,
                timeRemaining: 0,
                inPossession: false,
                scoreDifferential: 0,
                winning: false,
                isClockPaused: false,
                clockEndDate: nil
            ),
            stats: NFLStats(
                ourTeam: .init(totalScore: 7),
                theirTeam: .init(totalScore: 7)
            ),
            lastPlay: NFLLastPlay(
                description: "End of 1st Quarter",
                attribution: .neutral
            )
        )
    }
    
    fileprivate static var previewLosing: NFLContentState {
        NFLContentState(
            game: .init(
                gamePhase: .init(description: "4th", phase: .q4),
                clock: "2:15",
                timeRemaining: 135,
                inPossession: false,
                scoreDifferential: 5,
                winning: false,
                isClockPaused: false,
                clockEndDate: Date().addingTimeInterval(135)
            ),
            stats: NFLStats(
                ourTeam: .init(totalScore: 24),
                theirTeam: .init(totalScore: 29)
            ),
            lastPlay: NFLLastPlay(
                description: "D.Prescott pass to C.Lamb for 35 yards, TOUCHDOWN",
                attribution: .away
            )
        )
    }
    
    fileprivate static var previewPregame: NFLContentState {
        NFLContentState(
            game: .init(
                gamePhase: .init(description: "Starting Soon", phase: .pregame),
                clock: nil,
                timeRemaining: 0,
                inPossession: false,
                scoreDifferential: 0,
                winning: false,
                isClockPaused: false,
                clockEndDate: nil
            ),
            stats: NFLStats(
                ourTeam: .init(totalScore: 0),
                theirTeam: .init(totalScore: 0)
            ),
            lastPlay: nil
        )
    }
    
    fileprivate static var previewHalftime: NFLContentState {
        NFLContentState(
            game: .init(
                gamePhase: .init(description: "Half Time", phase: .halfTime),
                clock: nil,
                timeRemaining: 0,
                inPossession: true,
                scoreDifferential: 3,
                winning: true,
                isClockPaused: false,
                clockEndDate: nil
            ),
            stats: NFLStats(
                ourTeam: .init(totalScore: 17),
                theirTeam: .init(totalScore: 14)
            ),
            lastPlay: NFLLastPlay(
                description: "End of 1st Half",
                attribution: .home
            )
        )
    }
    
    fileprivate static var previewFinal: NFLContentState {
        NFLContentState(
            game: .init(
                gamePhase: .init(description: "Final", phase: .final),
                clock: nil,
                timeRemaining: 0,
                inPossession: false,
                scoreDifferential: 7,
                winning: true,
                isClockPaused: false,
                clockEndDate: nil
            ),
            stats: NFLStats(
                ourTeam: .init(totalScore: 31),
                theirTeam: .init(totalScore: 24)
            ),
            lastPlay: nil
        )
    }
}
