import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - NHL Live Activity Widget

public struct RoverNHLLiveActivity: Widget {

    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoverNHLActivityAttributes.self) { context in
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
                            endDate: context.state.game.clockEndDate, 
                            clockString: context.state.game.clockString,
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

extension ActivityViewContext where Attributes == RoverNHLActivityAttributes {
    /// Label for the away team (leading position)
    var awayTeamLabel: String {
        attributes.isHomeTeam ? attributes.theirTeam.abbreviation : attributes.ourTeam.abbreviation
    }

    /// Score for the away team (leading position)
    var awayTeamScore: Int {
        attributes.isHomeTeam ? state.stats.theirTeam.scores.totalScore : state.stats.ourTeam.scores.totalScore
    }

    /// Label for the home team (trailing position)
    var homeTeamLabel: String {
        attributes.isHomeTeam ? attributes.ourTeam.abbreviation : attributes.theirTeam.abbreviation
    }

    /// Score for the home team (trailing position)
    var homeTeamScore: Int {
        attributes.isHomeTeam ? state.stats.ourTeam.scores.totalScore : state.stats.theirTeam.scores.totalScore
    }

    /// TeamInfo for the away team (leading position)
    var awayTeamInfo: NHLTeamInfo {
        attributes.isHomeTeam ? attributes.theirTeam : attributes.ourTeam
    }

    /// TeamInfo for the home team (trailing position)
    var homeTeamInfo: NHLTeamInfo {
        attributes.isHomeTeam ? attributes.ourTeam : attributes.theirTeam
    }
}

// MARK: - Reusable Components

private struct LockScreenView: View {
    let context: ActivityViewContext<RoverNHLActivityAttributes>

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
    let context: ActivityViewContext<RoverNHLActivityAttributes>

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
    let context: ActivityViewContext<RoverNHLActivityAttributes>

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
    let context: ActivityViewContext<RoverNHLActivityAttributes>

    var body: some View {
        if context.state.game.gamePhase.isPlaying {
            PlayingStateView(context: context)
        } else {
            NonPlayingStateView(context: context)
        }
    }
}

private struct PlayingStateView: View {
    let context: ActivityViewContext<RoverNHLActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            // Top: Matchup title
            Text(context.attributes.matchupTitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 16) {
                TeamBadgeView(teamInfo: context.awayTeamInfo)

                HStack(alignment: .center) {
                    ScoreView(score: context.awayTeamScore)
                    Spacer()

                    GameClockView(
                        startDate: .now,
                        endDate: context.state.game.clockEndDate,
                        clockString: context.state.game.clockString,
                        phase: context.state.game.gamePhase,
                        isClockPaused: context.state.game.isClockPaused
                    )

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
    let context: ActivityViewContext<RoverNHLActivityAttributes>

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
    let phase: NHLGamePhase
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
            .font(.system(size: 48, weight: .medium, design: .default))
            .fontWidth(.compressed)
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}

private struct LastPlayView: View {
    let context: ActivityViewContext<RoverNHLActivityAttributes>

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
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // This keeps the neutral as the same height as the away and home states
                    RoundedRectangle(cornerRadius: 1)
                        .opacity(0)
                        .frame(width: 3, height: 40)
                }
            }
        }
    }
}

private struct TeamBadgeView: View {
    let teamInfo: NHLTeamInfo
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

#Preview("NHL", as: .content, using: RoverNHLActivityAttributes.preview) {
    RoverNHLLiveActivity()
} contentStates: {
    NHLContentState.previewWinning
    NHLContentState.previewLosing
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
                    scores: NHLScoreStats(totalScore: 2, p1Score: 1, p2Score: 1, p3Score: 0, overtimeScore: 0),
                    shotsOnGoal: NHLShotStats(totalShots: 25, p1Shots: 12, p2Shots: 13, p3Shots: 0, overtimeShots: 0),
                    hits: NHLHitStats(totalHits: 18, p1Hits: 8, p2Hits: 10, p3Hits: 0, overtimeHits: 0)
                ),
                theirTeam: NHLTeamStats(
                    scores: NHLScoreStats(totalScore: 1, p1Score: 0, p2Score: 1, p3Score: 0, overtimeScore: 0),
                    shotsOnGoal: NHLShotStats(totalShots: 22, p1Shots: 10, p2Shots: 12, p3Shots: 0, overtimeShots: 0),
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
                    scores: NHLScoreStats(totalScore: 1, p1Score: 0, p2Score: 1, p3Score: 0, overtimeScore: 0),
                    shotsOnGoal: NHLShotStats(totalShots: 28, p1Shots: 12, p2Shots: 10, p3Shots: 6, overtimeShots: 0),
                    hits: NHLHitStats(totalHits: 22, p1Hits: 8, p2Hits: 9, p3Hits: 5, overtimeHits: 0)
                ),
                theirTeam: NHLTeamStats(
                    scores: NHLScoreStats(totalScore: 3, p1Score: 1, p2Score: 1, p3Score: 1, overtimeScore: 0),
                    shotsOnGoal: NHLShotStats(totalShots: 31, p1Shots: 11, p2Shots: 12, p3Shots: 8, overtimeShots: 0),
                    hits: NHLHitStats(totalHits: 19, p1Hits: 6, p2Hits: 8, p3Hits: 5, overtimeHits: 0)
                )
            ),
            lastPlay: NHLLastPlay(description: "Goal by Nathan MacKinnon", attribution: .away)
        )
    }
}
