import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - NFL Live Activity Widget

public struct RoverNFLLiveActivity: Widget {

    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoverNFLActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            let isNotPregame = context.state.game.gamePhase.phase != .pregame
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 12) {
                        TeamBadgeView(teamInfo: context.awayTeamInfo, size: 28)
                        if isNotPregame {
                            ScoreView(score: context.awayTeamScore)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 12) {
                        if isNotPregame {
                            ScoreView(score: context.homeTeamScore)
                        }
                        TeamBadgeView(teamInfo: context.homeTeamInfo, size: 28)
                    }
                    .padding(.horizontal, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    if context.state.game.gamePhase.isPlaying {
                        GameClockView(
                            startDate: .now,
                            endDate: context.state.game.clockEndDate, clockString: context.state.game.clockString,
                            phase: context.state.game.gamePhase,
                            isClockPaused: context.state.game.isClockPaused
                        )
                    } else {
                        Text(context.state.game.gamePhase.description)
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.game.gamePhase.shouldShowLastPlay {
                        LastPlayView(context: context)
                            .padding(.horizontal, 8)
                            .padding(.bottom)
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    TeamBadgeView(teamInfo: context.awayTeamInfo, size: 20, showAbbreviation: false)
                    if isNotPregame {
                        Text("\(context.awayTeamScore)")
                            .fontWeight(.bold)
                            .contentTransition(.numericText())
                    }
                }
            } compactTrailing: {
                HStack {
                    if isNotPregame {
                        Text("\(context.homeTeamScore)")
                            .fontWeight(.bold)
                            .contentTransition(.numericText())
                    }
                    TeamBadgeView(teamInfo: context.homeTeamInfo, size: 20, showAbbreviation: false)
                }
            } minimal: {
                ZStack {
                    TeamBadgeView(teamInfo: context.awayTeamInfo, size: 20, showAbbreviation: false)
                        .offset(x: -4)
                    TeamBadgeView(teamInfo: context.homeTeamInfo, size: 20, showAbbreviation: false)
                        .offset(x: 4)
                }
            }
        }
        .applySupplementalActivityFamilies()
    }
}


private extension WidgetConfiguration {
    // Allows the application of supplemental Activity Families
    func applySupplementalActivityFamilies() -> some WidgetConfiguration {
        if #available(iOS 18.0, *) {
            return self.supplementalActivityFamilies([.small, .medium])
        } else {
            return self
        }
    }
}

// MARK: - Context Helpers

extension ActivityViewContext where Attributes == RoverNFLActivityAttributes {
    /// Label for the away team (leading position)
    var awayTeamLabel: String {
        attributes.isHomeTeam ? attributes.theirTeam.abbreviation : attributes.ourTeam.abbreviation
    }

    /// Score for the away team (leading position)
    var awayTeamScore: Int {
        attributes.isHomeTeam ? state.stats.theirTeam.totalScore : state.stats.ourTeam.totalScore
    }

    /// Label for the home team (trailing position)
    var homeTeamLabel: String {
        attributes.isHomeTeam ? attributes.ourTeam.abbreviation : attributes.theirTeam.abbreviation
    }

    /// Score for the home team (trailing position)
    var homeTeamScore: Int {
        attributes.isHomeTeam ? state.stats.ourTeam.totalScore : state.stats.theirTeam.totalScore
    }

    /// TeamInfo for the away team (leading position)
    var awayTeamInfo: NFLTeamInfo {
        attributes.isHomeTeam ? attributes.theirTeam : attributes.ourTeam
    }

    /// TeamInfo for the home team (trailing position)
    var homeTeamInfo: NFLTeamInfo {
        attributes.isHomeTeam ? attributes.ourTeam : attributes.theirTeam
    }
}

// MARK: - Reusable Components

private struct LockScreenView: View {
    let context: ActivityViewContext<RoverNFLActivityAttributes>

    var body: some View {
        if #available(iOS 18.0, *) {
            SupplementalLockScreenView(context: context)
        } else {
            MediumLockScreenView(context: context)
        }
    }
}

@available(iOS 18.0, *)
private struct SupplementalLockScreenView: View {
    @Environment(\.activityFamily) private var activityFamily
    let context: ActivityViewContext<RoverNFLActivityAttributes>

    var body: some View {
        switch activityFamily {
        case .small:
            SmallLockScreenView(context: context)
        case .medium:
            MediumLockScreenView(context: context)
        @unknown default:
            MediumLockScreenView(context: context)
        }
    }
}

// ContentSmall (compact)
private struct SmallLockScreenView: View {
    let context: ActivityViewContext<RoverNFLActivityAttributes>

    var body: some View {
        HStack {
            // Away team
            HStack(spacing: 6) {
                TeamBadgeView(teamInfo: context.awayTeamInfo, size: 28, showAbbreviation: false)
                Text("\(context.awayTeamScore)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            Spacer()

            // Home team
            HStack(spacing: 6) {
                Text("\(context.homeTeamScore)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                TeamBadgeView(teamInfo: context.homeTeamInfo, size: 28, showAbbreviation: false)
            }
        }
        .padding(.horizontal, 8)
    }
}


// Content Medium
private struct MediumLockScreenView: View {
    let context: ActivityViewContext<RoverNFLActivityAttributes>

    var body: some View {
        if context.state.game.gamePhase.isPlaying {
            PlayingStateView(context: context)
        } else {
            NonPlayingStateView(context: context)
        }
    }
}

private struct PlayingStateView: View {
    let context: ActivityViewContext<RoverNFLActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            // Top: Phase and clock
            HStack(spacing: 8) {
                Text(context.state.game.gamePhase.description)
                    .font(.caption)
                Text(context.state.game.clockString)
                    .font(.caption)
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 16) {
                TeamBadgeView(teamInfo: context.awayTeamInfo)

                HStack(alignment: .center) {
                    ScoreView(score: context.awayTeamScore)

                    Spacer()

                    VStack(spacing: 4) {
                        Text(context.attributes.matchupTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()

                    ScoreView(score: context.homeTeamScore)
                }
                .offset(y: -10)

                TeamBadgeView(teamInfo: context.homeTeamInfo)
            }

            LastPlayView(context: context)
        }
        .padding()
    }
}

private struct NonPlayingStateView: View {
    let context: ActivityViewContext<RoverNFLActivityAttributes>

    var body: some View {
        let isNotPregame = context.state.game.gamePhase.phase != .pregame
        VStack(spacing: 12) {
            // Top: Matchup title
            Text(context.attributes.matchupTitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: isNotPregame ? .top : .center, spacing: 16) {
                TeamBadgeView(teamInfo: context.awayTeamInfo)

                HStack(alignment: .center) {
                    // Conditionally show scores (hide during pregame)
                    if isNotPregame {
                        ScoreView(score: context.awayTeamScore)
                    }

                    Spacer()

                    // Static text instead of countdown timer
                    Text(context.state.game.gamePhase.description)
                        .font(.headline)
                        .fontWeight(.bold)

                    Spacer()

                    // Conditionally show scores (hide during pregame)
                    if isNotPregame {
                        ScoreView(score: context.homeTeamScore)
                    }
                }
                .offset(y: -10)

                TeamBadgeView(teamInfo: context.homeTeamInfo)
            }

            // Show last play for quarter and half time ends
            if context.state.game.gamePhase.shouldShowLastPlay {
                LastPlayView(context: context)
            }
        }
        .padding()
    }
}

private struct GameClockView: View {
    let startDate: Date
    let endDate: Date?
    let clockString: String
    let phase: NFLGamePhase
    let isClockPaused: Bool

    var body: some View {
        if let endDate = endDate, endDate > startDate {
            HStack {
                Text(phase.description)

                // This is a workaround because Text(timerInterval:pauseTime:countsDown:showsHours:) is greedy and fills the whole space
                Text(clockString)
                    .monospacedDigit()
                    .hidden()
                    .accessibilityHidden(true)
                    .overlay {
                        if isClockPaused {
                            Text(clockString)
                                .monospacedDigit()
                        } else {
                            Text(
                                timerInterval: startDate...endDate,
                                countsDown: true,
                                showsHours: false
                            )
                            .monospacedDigit()
                            .multilineTextAlignment(.center)
                        }
                    }
            }
            .font(.headline)
            .fontWeight(.medium)

        } else {
            Text(phase.description)
                .font(.headline)
                .fontWeight(.medium)
        }
    }
}

private struct ScoreView: View {
    let score: Int

    var body: some View {
        Text("\(score)")
            .font(.system(size: 40))
            .fontWeight(.bold)
            .contentTransition(.numericText())
            .monospacedDigit()
    }
}

private struct LastPlayView: View {
    let context: ActivityViewContext<RoverNFLActivityAttributes>

    var body: some View {
        if let lastPlay = context.state.lastPlay {
            HStack(alignment: .top, spacing: 8) {
                switch lastPlay.attribution {
                case .away:
                    // Accent bar on left (away team made the play)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(context.awayTeamInfo.brandColor)
                        .frame(width: 3, height: 40)
                    Text(lastPlay.description)
                        .font(.subheadline)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .home:
                    // Accent bar on right (home team made the play)
                    Text(lastPlay.description)
                        .font(.subheadline)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(context.homeTeamInfo.brandColor)
                        .frame(width: 3, height: 40)
                case .neutral:
                    // No team associated
                    Text(lastPlay.description)
                        .font(.subheadline)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // This keeps the neutral as the same height as the away and home states
                    RoundedRectangle(cornerRadius: 1)
                        .opacity(0)
                        .frame(width: 3, height: 40)
                }
            }
            .frame(maxHeight: 60)
        } else {
            EmptyView()
        }
    }
}


private struct TeamBadgeView: View {
    let teamInfo: NFLTeamInfo
    var size: CGFloat = 28
    var showAbbreviation: Bool = true

    var body: some View {
        VStack(spacing: 4) {
            teamInfo.logo
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(teamInfo.brandColor)
                        .frame(width: size, height: size)
                )
                .clipShape(Circle())
            if showAbbreviation {
                Text(teamInfo.abbreviation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

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
