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
import RoverFoundation
import SwiftUI
import UIKit

/// Embed this view within a tab to integrate the Rover Hub.
public struct HubView: View {
    /// Presentation state carrying the Hub's dismissal handler. It is populated from
    /// exactly two places, and the close affordance appears exactly when it is non-`nil`:
    /// an owning `HubHostingController` injects a handler once it confirms it is
    /// presented modally, and an integrator supplies one through
    /// `init(onDismissButtonPressed:)` when presenting a bare `HubView` themselves
    /// (e.g. inside a `.sheet`). The SDK never infers dismissability from the SwiftUI
    /// environment: `\.isPresented` is `true` for pushed views too, so an environment
    /// fallback would show a close button that pops the host's navigation stack.
    @ObservedObject private(set) var presentation: HubPresentationState

    @Environment(\.isPresented) private var isPresented
    @Environment(\.dismiss) private var dismiss

    /// Creates the Hub view for an embedded placement — a tab or other persistent
    /// placement. No close chrome is added.
    public init() {
        self.presentation = HubPresentationState()
    }

    /// Creates the Rover Hub view for modal presentation, such as in a SwiftUI sheet.
    /// Use this overload (`onDismissButtonPressed` provided) when presenting the Hub
    /// modally. The Hub will include a close button that will call back to
    /// `onDismissButtonPressed`.
    ///
    /// - Parameter onDismissButtonPressed: Supply a closure that will be called when
    ///   the button is pressed. If this closure is not provided, then no close button
    ///   will appear.
    public init(onDismissButtonPressed: (() -> Void)?) {
        let presentation = HubPresentationState()
        presentation.onDismissButtonPressed = onDismissButtonPressed
        self.presentation = presentation
    }

    /// Internal initializer used by `HubHostingController` to share its presentation
    /// state, so a modal presentation resolved at `viewWillAppear` threads the
    /// dismissal handler into the App Screens home view without re-rooting the tree.
    init(presentation: HubPresentationState) {
        self.presentation = presentation
    }

    public var body: some View {
        HubContentView(
            coordinator: coordinator,
            badge: roverBadge,
            onDismissButtonPressed: presentation.onDismissButtonPressed,
            onOpenExternalURL: effectiveOpenExternalURL
        )
        .environmentObject(coordinator)
        .environment(\.hubContainer, persistentContainer)
        .environment(\.managedObjectContext, persistentContainer.viewContext)
        .environment(\.refreshHub, { await refreshHub() })
        .environment(\.postSync, postSync)
        .environment(\.inboxSeenWatermark, inboxSeenWatermark)
        .environment(\.eventQueue, Rover.shared.eventQueue)
        .environment(\.configSync, configSync)
        .environment(\.conversationSync, conversationSync)
        .environment(\.replySync, replySync)
    }

    /// UIKit-hosted Hubs supply `presentation.onOpenExternalURL` (see `HubHostingController`).
    /// A bare SwiftUI-presented `HubView` supplies its own: when this view is itself
    /// presented (`isPresented`), a `dismiss:true` deep link dismisses this presentation
    /// (cascading its App Screens sheets away) then opens. When embedded (not presented),
    /// no owner handler — the App Screens layer collapses only its sheets.
    private var effectiveOpenExternalURL: ((URL, Bool) -> Void)? {
        if let injected = presentation.onOpenExternalURL {
            return injected
        }
        guard isPresented else {
            return nil
        }
        return { url, shouldDismiss in
            guard shouldDismiss else {
                UIApplication.shared.openLoggingHubFailure(url)
                return
            }
            dismiss()
            UIApplication.shared.openLoggingHubFailure(url)
        }
    }

    var coordinator: HubCoordinator {
        Rover.shared.resolve(HubCoordinator.self)!
    }

    var persistentContainer: InboxPersistentContainer {
        Rover.shared.resolve(InboxPersistentContainer.self)!
    }

    var postSync: PostSync {
        Rover.shared.resolve(PostSync.self)!
    }

    var inboxSeenWatermark: InboxSeenWatermark {
        Rover.shared.resolve(InboxSeenWatermark.self)!
    }

    var configSync: ConfigSync {
        Rover.shared.resolve(ConfigSync.self)!
    }

    var conversationSync: ConversationSync {
        Rover.shared.resolve(ConversationSync.self)!
    }

    var roverBadge: RoverBadge {
        Rover.shared.resolve(RoverBadge.self)!
    }

    var replySync: ReplySync {
        Rover.shared.resolve(ReplySync.self)!
    }

    func refreshHub() async {
        await Rover.shared.resolve(SyncCoordinator.self)!.syncAsync()
    }
}
