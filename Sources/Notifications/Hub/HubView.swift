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

/// Embed this view within a tab to integrate the Rover Hub.
public struct HubView: View {
    /// Presentation state shared with the owning `HubHostingController`. Its
    /// `onDismissButtonPressed` is `nil` while the Hub is embedded (a tab, or a bare
    /// `HubView()`) and a real dismissal only once the controller confirms it is
    /// presented modally; observing it here threads that live value into the App
    /// Screens home view so the `openURL { dismiss: true }` teardown and the close
    /// affordance appear exactly for a presented Hub.
    @ObservedObject private var presentation: HubPresentationState

    public init() {
        // A bare `HubView()` (e.g. embedded directly in a tab) owns its own state,
        // whose dismissal handler stays `nil` — non-dismissable, no close chrome.
        self.presentation = HubPresentationState()
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
            onDismissButtonPressed: presentation.onDismissButtonPressed
        )
        .environmentObject(coordinator)
        .environment(\.hubContainer, persistentContainer)
        .environment(\.managedObjectContext, persistentContainer.viewContext)
        .environment(\.refreshHub, { await refreshHub() })
        .environment(\.postSync, postSync)
        .environment(\.eventQueue, Rover.shared.eventQueue)
        .environment(\.configSync, configSync)
        .environment(\.conversationSync, conversationSync)
        .environment(\.replySync, replySync)
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
