import RoverNBALiveActivities
import SwiftUI
import WidgetKit

// MARK: - NBA Previews

#Preview("NBA", as: .content, using: RoverNBAActivityAttributes.preview) {
    RoverNBALiveActivity()
} contentStates: {
    NBAContentState.previewPregame
    NBAContentState.previewWinning
    NBAContentState.previewEndOfQuarter
    NBAContentState.previewHalftime
    NBAContentState.previewLosing
    NBAContentState.previewFinal
}

// MARK: - NBA Preview Helpers

extension RoverNBAActivityAttributes {
    fileprivate static var preview: RoverNBAActivityAttributes {
        RoverNBAActivityAttributes(
            gameID: "preview-game",
            week: 15,
            matchupTitle: "Lakers vs Warriors",
            ourTeam: NBATeamInfo(name: "Lakers", city: "Los Angeles", abbreviation: "LAL"),
            theirTeam: NBATeamInfo(name: "Warriors", city: "Golden State", abbreviation: "GSW"),
            venueName: "Crypto.com Arena",
            isHomeTeam: true
        )
    }
}

extension NBAContentState {
    fileprivate static var previewWinning: NBAContentState {
        NBAContentState(
            game: .init(
                gamePhase: .init(description: "2nd", phase: .q2),
                clock: "8:42",
                timeRemaining: 522,
                inPossession: true,
                scoringRun: 8,
                scoreDifferential: 6,
                winning: true,
                isClockPaused: false,
                clockEndDate: Date().addingTimeInterval(522)
            ),
            stats: NBATeamStatsContainer(
                ourTeam: .init(totalScore: 58),
                theirTeam: .init(totalScore: 52)
            ),
            lastPlay: NBALastPlay(
                description: "James drains a three!",
                attribution: .home
            )
        )
    }

    fileprivate static var previewLosing: NBAContentState {
        NBAContentState(
            game: .init(
                gamePhase: .init(description: "4th", phase: .q4),
                clock: "2:15",
                timeRemaining: 135,
                inPossession: false,
                scoringRun: -10,
                scoreDifferential: -5,
                winning: false,
                isClockPaused: false,
                clockEndDate: Date().addingTimeInterval(135)
            ),
            stats: NBATeamStatsContainer(
                ourTeam: .init(totalScore: 108),
                theirTeam: .init(totalScore: 113)
            ),
            lastPlay: NBALastPlay(
                description: "Curry with the layup",
                attribution: .away
            )
        )
    }

    fileprivate static var previewPregame: NBAContentState {
        NBAContentState(
            game: .init(
                gamePhase: .init(description: "Starting Soon", phase: .pregame),
                clock: nil,
                timeRemaining: 0,
                inPossession: false,
                scoringRun: 0,
                scoreDifferential: 0,
                winning: false,
                isClockPaused: false,
                clockEndDate: nil
            ),
            stats: NBATeamStatsContainer(
                ourTeam: .init(totalScore: 0),
                theirTeam: .init(totalScore: 0)
            ),
            lastPlay: nil
        )
    }

    fileprivate static var previewEndOfQuarter: NBAContentState {
        NBAContentState(
            game: .init(
                gamePhase: .init(description: "1st", phase: .q1End),
                clock: nil,
                timeRemaining: 0,
                inPossession: false,
                scoringRun: 0,
                scoreDifferential: 0,
                winning: false,
                isClockPaused: false,
                clockEndDate: nil
            ),
            stats: NBATeamStatsContainer(
                ourTeam: .init(totalScore: 0),
                theirTeam: .init(totalScore: 0)
            ),
            lastPlay: NBALastPlay(
                description: "End of 1st Quarter.",
                attribution: .neutral
            )
        )
    }

    fileprivate static var previewHalftime: NBAContentState {
        NBAContentState(
            game: .init(
                gamePhase: .init(description: "Half Time", phase: .halfTime),
                clock: nil,
                timeRemaining: 0,
                inPossession: true,
                scoringRun: 5,
                scoreDifferential: 3,
                winning: true,
                isClockPaused: false,
                clockEndDate: nil
            ),
            stats: NBATeamStatsContainer(
                ourTeam: .init(totalScore: 56),
                theirTeam: .init(totalScore: 53)
            ),
            lastPlay: NBALastPlay(
                description: "End of 1st Half.",
                attribution: .home
            )
        )
    }

    fileprivate static var previewFinal: NBAContentState {
        NBAContentState(
            game: .init(
                gamePhase: .init(description: "Final", phase: .final),
                clock: nil,
                timeRemaining: 0,
                inPossession: false,
                scoringRun: 0,
                scoreDifferential: 8,
                winning: true,
                isClockPaused: false,
                clockEndDate: nil
            ),
            stats: NBATeamStatsContainer(
                ourTeam: .init(totalScore: 112),
                theirTeam: .init(totalScore: 104)
            ),
            lastPlay: nil
        )
    }
}
