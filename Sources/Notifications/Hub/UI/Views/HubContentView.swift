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

import RoverData
import RoverExperiences
import RoverFoundation
import SwiftUI

struct HubContentView: View {
    @ObservedObject var coordinator: HubCoordinator
    @ObservedObject var badge: RoverBadge
    @Environment(\.configSync) private var configSync
    @Environment(\.conversationSync) private var conversationSync

    /// A dismissal closure threaded down from a modally-presented Hub; passed to the
    /// App Screens home view so `openURL { dismiss: true }` and the close affordance
    /// can dismiss the presentation. `nil` when the Hub is embedded in a tab.
    var onDismissButtonPressed: (() -> Void)? = nil

    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            ZStack {
                if coordinator.isHomeEnabled, let url = coordinator.homeViewExperienceURL {
                    if ExperienceURLClassifier.classify(url) == .appScreens {
                        // V3 App Screens owns its chrome: the child navigation
                        // controller renders liquid-glass buttons over the
                        // full-bleed webview and the page pads itself with
                        // env(safe-area-inset-*). Forcing the outer SwiftUI bar
                        // visible (as the document path below does) would stack a
                        // second bar's safe area on top of the page's own insets, so
                        // let the .toolbar(.hidden) inside ExperienceView win here.
                        //
                        // The inbox affordance is therefore surfaced NOT through the
                        // outer SwiftUI toolbar but as a native root bar item handed
                        // to the App Screens flow: it installs an envelope
                        // (liquid-glass, with the live unread badge) on the ROOT host
                        // only, so it shows on home and disappears when a detail is
                        // pushed. Tapping it appends HubPath.messages, matching the
                        // document path's InboxToolbarButton. It re-renders (and the
                        // badge updates) because this view observes RoverBadge.
                        ExperienceView(
                            url: url,
                            path: $coordinator.navigationPath,
                            appScreensResetGeneration: coordinator.appScreensResetGeneration,
                            appScreensRootBarItem: coordinator.isInboxEnabled
                                ? AppScreensRootBarItem(
                                    systemImageName: "envelope",
                                    badgeText: badge.newBadge,
                                    accessibilityLabel: NSLocalizedString(
                                        "Inbox",
                                        comment: "Rover Hub inbox button accessibility label"
                                    ),
                                    accessibilityIdentifier: "rover.hub.inbox",
                                    action: { coordinator.navigationPath.append(HubPath.messages) }
                                )
                                : nil,
                            onDismissButtonPressed: onDismissButtonPressed
                        )
                    } else {
                        ExperienceView(url: url, path: $coordinator.navigationPath)
                            // The experience rendered by ExperienceView may
                            // have its root screen configured without a navigation bar.
                            // In that case, ScreenView sets the navigation bar visibility
                            // to `.hidden`. However, HubContentView needs the navigation bar to
                            // be visible so it can display the inbox toolbar button.
                            //
                            // By explicitly setting `.toolbar(.visible, for: .navigationBar)`
                            // here, we override the hidden state set by ScreenView and
                            // ensure the inbox button is always accessible. This works
                            // because SwiftUI resolves toolbar visibility from the
                            // outermost modifier, so this parent-level override takes
                            // precedence over the child ScreenView's hidden setting.
                            .toolbar(.visible, for: .navigationBar)
                            .toolbar {
                                if coordinator.isInboxEnabled {
                                    ToolbarItem(placement: .topBarTrailing) {
                                        CompatibleInboxToolbarButton(badge: badge.newBadge) {
                                            coordinator.navigationPath.append(HubPath.messages)
                                        }
                                    }
                                }
                            }
                    }
                } else {
                    inboxOrEmpty
                }
            }
            .resetNavBarAppearance()
            .onAppear {
                Task {
                    await configSync?.sync()
                }

                if coordinator.isHomeEnabled {
                    Task {
                        await coordinator.fetchHomeView()
                    }
                }
            }
            .navigationDestination(for: HubPath.self) { path in
                switch path {
                case .messages:
                    MessagesView(navigationPath: $coordinator.navigationPath)
                        .environment(\.conversationSync, conversationSync)
                }
            }
            .navigationDestination(for: PostDestination.self) { postDestination in
                PostDetailView(
                    postID: postDestination.postID,
                    accentColor: coordinator.accentColor,
                    showAlert: $coordinator.showPostAlert
                )
            }
            .navigationDestination(for: ConversationDestination.self) { destination in
                ConversationDetailView(conversationID: destination.conversationID)
            }
        }
        .tint(coordinator.accentColor)
        .optionalColorScheme(coordinator.colorScheme)
    }

    @ViewBuilder
    private var inboxOrEmpty: some View {
        if coordinator.isInboxEnabled {
            MessagesView(navigationPath: $coordinator.navigationPath)
                .environment(\.conversationSync, conversationSync)
        }
    }

}


