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

    /// A dismissal closure threaded down from a modally-presented Hub; drives the
    /// leading close item on both home view branches, and is passed to the App
    /// Screens home view so `openURL { dismiss: true }` and the close affordance
    /// can dismiss the presentation. `nil` when the Hub is embedded in a tab.
    var onDismissButtonPressed: (() -> Void)? = nil

    /// The Hub's completion-capable dismiss-then-open handler, threaded down from
    /// `HubHostingController` via `HubView`; passed to the App Screens home view so an
    /// `openURL { dismiss }` bridge message dismisses the presentation THEN opens (or
    /// opens immediately without dismissing). `nil` when the Hub is embedded in a tab.
    var onOpenExternalURL: ((URL, Bool) -> Void)? = nil

    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            ZStack {
                if coordinator.isHomeEnabled, let url = coordinator.homeViewExperienceURL {
                    if ExperienceURLClassifier.classify(url) == .appScreens {
                        // V3 App Screens is hosted directly on this NavigationStack
                        // (RoverExperiences' `AppScreensHostView`), so it renders
                        // like any other Hub destination: the standard SwiftUI
                        // navigation bar is visible and the inbox affordance is the
                        // same `CompatibleInboxToolbarButton` the document path below
                        // uses, rather than a bespoke native root bar item. Keying the
                        // view `.id(url)` means a home-URL change deterministically
                        // tears down the old flow (releasing its sessions) and builds
                        // a fresh one for the new URL; there is no `.onDisappear`
                        // release, since that would also fire when the inbox is
                        // merely pushed over the App Screens root.
                        AppScreensHostView(
                            url: url,
                            path: $coordinator.navigationPath,
                            onDismiss: onDismissButtonPressed,
                            onOpenURL: nil,
                            onOpenExternalURL: onOpenExternalURL
                        )
                        .id(url)
                        .toolbar(.visible, for: .navigationBar)
                        .toolbar {
                            // A dismissable Hub (`onDismissButtonPressed != nil`,
                            // injected by `HubHostingController` when presented modally,
                            // or supplied by the integrator via
                            // `HubView(onDismissButtonPressed:)` for a SwiftUI `.sheet`)
                            // installs the xmark close item. Embedded/tabbed and pushed
                            // Hubs leave it `nil`: no close chrome.
                            if onDismissButtonPressed != nil {
                                ToolbarItem(placement: .topBarLeading) {
                                    AppScreensCloseButton { onDismissButtonPressed?() }
                                }
                            }
                            if coordinator.isInboxEnabled {
                                ToolbarItem(placement: .topBarTrailing) {
                                    CompatibleInboxToolbarButton(badge: badge.newBadge) {
                                        coordinator.navigationPath.append(HubPath.messages)
                                    }
                                }
                            }
                        }
                        .resetNavBarAppearance()
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
                                // Same close-affordance contract as the App Screens
                                // branch above: a modally-presented Hub installs the
                                // SDK's leading xmark item, regardless of which home
                                // view type it renders. Any close button authored in
                                // the experience file itself renders separately as
                                // screen content, wherever its author placed it.
                                if onDismissButtonPressed != nil {
                                    ToolbarItem(placement: .topBarLeading) {
                                        AppScreensCloseButton { onDismissButtonPressed?() }
                                    }
                                }
                                if coordinator.isInboxEnabled {
                                    ToolbarItem(placement: .topBarTrailing) {
                                        CompatibleInboxToolbarButton(badge: badge.newBadge) {
                                            coordinator.navigationPath.append(HubPath.messages)
                                        }
                                    }
                                }
                            }
                            .resetNavBarAppearance()
                    }
                } else {
                    inboxOrEmpty
                }
            }
            // The stack root's content decides its bar style: home experiences own
            // their chrome and stay fully transparent, while a root-level messages
            // list (inbox-only Hubs, or while the home view URL is still loading) is
            // a content screen and needs the scrolled background like the pushed
            // destinations below. Applied per-branch inside the ZStack rather than
            // here, so exactly one reset is active for whichever branch is showing.
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
                        // Pushed destinations are separate screens with their own
                        // navigation items; the reset on the stack root above doesn't
                        // reach them, so each destination pins its own appearance.
                        // Content screens show the system background once content
                        // scrolls under the bar so the title and back button stay
                        // legible; only the home experience stays fully transparent.
                        .resetNavBarAppearance(.systemScrolledBackground)
                }
            }
            .navigationDestination(for: PostDestination.self) { postDestination in
                PostDetailView(
                    postID: postDestination.postID,
                    accentColor: coordinator.accentColor,
                    showAlert: $coordinator.showPostAlert
                )
                .resetNavBarAppearance(.systemScrolledBackground)
            }
            .navigationDestination(for: ConversationDestination.self) { destination in
                ConversationDetailView(conversationID: destination.conversationID)
                    .resetNavBarAppearance(.systemScrolledBackground)
            }
        }
        .tint(coordinator.accentColor)
        .optionalColorScheme(coordinator.colorScheme)
        // Set on the stack (not per destination) so the messages list, and every Post
        // or Conversation pushed from it or reached by deep link, inherit it.
        .environment(\.hubDismissThenOpen, dismissThenOpen)
    }

    /// The Post/Conversation dismiss-then-open handler (see `HubLinkOpenDecision`),
    /// derived from the same owner handler the App Screens home uses for
    /// `openURL { dismiss: true }`, and gated on the same signal as the close
    /// affordance: `onDismissButtonPressed` is non-`nil` exactly when the Hub is
    /// declared dismissable (injected by a hosting controller once it confirms a
    /// modal presentation, or supplied by the integrator for a SwiftUI `.sheet`). A
    /// Hub that has nothing to dismiss (embedded, pushed) yields `nil` and links open
    /// in place. `HubView`'s fallback opener alone is not enough for that: it is
    /// derived from `\.isPresented`, which is also `true` for a pushed `HubView()`,
    /// and would pop the host's navigation stack. On the `HubHostingController` path
    /// the open fires in the dismissal's completion. On the SwiftUI-sheet path
    /// (`HubView(onDismissButtonPressed:)`) the integrator's handler has no
    /// completion, so `HubView` dismisses and opens back to back; a host that
    /// presents the deep link's destination with UIKit may see that race.
    private var dismissThenOpen: ((URL) -> Void)? {
        guard onDismissButtonPressed != nil, let onOpenExternalURL else {
            return nil
        }
        return { url in onOpenExternalURL(url, true) }
    }

    /// The stack root when there is no home view to show (messages-only Hubs, or while
    /// the home view URL is still loading). It carries the same gated leading close
    /// item as the home view branches, so a modally presented messages-only Hub can
    /// be closed. Applied here rather than inside `MessagesView`, which is also the
    /// `HubPath.messages` destination pushed over a home view, where only the back
    /// button belongs. A dismissable Hub also drops the list's `.inlineLarge` title
    /// to `.inline`, which is what keeps the close item in the leading slot on iOS 26
    /// rather than folded into an overflow menu.
    @ViewBuilder
    private var inboxOrEmpty: some View {
        if coordinator.isInboxEnabled {
            MessagesView(
                navigationPath: $coordinator.navigationPath,
                titleDisplayMode: onDismissButtonPressed != nil ? .inline : .inlineLarge
            )
            .environment(\.conversationSync, conversationSync)
            .toolbar {
                if onDismissButtonPressed != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        AppScreensCloseButton { onDismissButtonPressed?() }
                    }
                }
            }
            .resetNavBarAppearance(.systemScrolledBackground)
        }
    }

}
