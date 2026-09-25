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
import RoverData
import SwiftUI
import os.log

private struct RefreshHubKey: EnvironmentKey {
    static let defaultValue: @Sendable () async -> Void = {
        assertionFailure("Refresh Hub requested, but not defined in environment!")
        os_log(.info, log: .hub, "Refresh posts requested, but not defined in environment!")
    }
}

private struct AccentColorKey: EnvironmentKey {
    static let defaultValue: Color = .accentColor
}

// Environment key for accessing the persistent container throughout the app
struct HubPersistentContainerKey: EnvironmentKey {
    static let defaultValue: InboxPersistentContainer? = nil
}

// Environment key for accessing the inbox seen watermark throughout the app
struct InboxSeenWatermarkKey: EnvironmentKey {
    static let defaultValue: InboxSeenWatermark? = nil
}

// Environment key for accessing the PostSync service throughout the app
struct PostSyncKey: EnvironmentKey {
    static let defaultValue: PostSync? = nil
}

// Environment key for accessing the EventQueue service throughout the app
struct EventQueueKey: EnvironmentKey {
    static let defaultValue: EventQueue? = nil
}

// Environment key for accessing the ConfigSync service throughout the app
struct ConfigSyncKey: EnvironmentKey {
    static let defaultValue: ConfigSync? = nil
}

// Environment key for accessing the ConversationSync service throughout the app
struct ConversationSyncKey: EnvironmentKey {
    static let defaultValue: ConversationSync? = nil
}

// Environment key for accessing the ReplySync service throughout the app
struct ReplySyncKey: EnvironmentKey {
    static let defaultValue: ReplySync? = nil
}

/// Environment key for the surface's dismiss-then-open handler (see `HubLinkOpenDecision`).
struct HubDismissThenOpenKey: EnvironmentKey {
    static let defaultValue: ((URL) -> Void)? = nil
}

extension EnvironmentValues {
    /// Rover Hub Core Data persistent container.
    var hubContainer: InboxPersistentContainer? {
        get { self[HubPersistentContainerKey.self] }
        set { self[HubPersistentContainerKey.self] = newValue }
    }

    /// Timestamp of the user's last inbox visit, which the Hub badge counts posts against.
    var inboxSeenWatermark: InboxSeenWatermark? {
        get { self[InboxSeenWatermarkKey.self] }
        set { self[InboxSeenWatermarkKey.self] = newValue }
    }

    /// Rover Hub sync service
    var postSync: PostSync? {
        get { self[PostSyncKey.self] }
        set { self[PostSyncKey.self] = newValue }
    }

    var refreshHub: @Sendable () async -> Void {
        get { self[RefreshHubKey.self] }
        set { self[RefreshHubKey.self] = newValue }
    }

    var roverHubAccentColor: Color {
        get { self[AccentColorKey.self] }
        set { self[AccentColorKey.self] = newValue }
    }

    /// Rover event queue for tracking events
    var eventQueue: EventQueue? {
        get { self[EventQueueKey.self] }
        set { self[EventQueueKey.self] = newValue }
    }

    var configSync: ConfigSync? {
        get { self[ConfigSyncKey.self] }
        set { self[ConfigSyncKey.self] = newValue }
    }

    /// Rover conversation sync service
    var conversationSync: ConversationSync? {
        get { self[ConversationSyncKey.self] }
        set { self[ConversationSyncKey.self] = newValue }
    }

    /// Rover reply sync service
    var replySync: ReplySync? {
        get { self[ReplySyncKey.self] }
        set { self[ReplySyncKey.self] = newValue }
    }

    /// Dismisses the modal presentation the Post or Conversation is showing in, then
    /// opens the URL once that dismissal has completed. `nil` when the surface is not
    /// presented modally in its own right (embedded in a tab, or pushed), in which
    /// case links open in place. Supplied by `HubContentView` for a Hub, and by the
    /// standalone `ShowPostHostingController` / `ShowConversationHostingController`.
    ///
    /// What ships, stated plainly: the UIKit-hosted surfaces (`HubHostingController`,
    /// `CommunicationHubHostingController`, the two standalone detail controllers) open
    /// from the dismissal's completion and are fixed. A Hub the integrator presents as
    /// `HubView(onDismissButtonPressed:)` in a SwiftUI `.sheet` is NOT: that closure has
    /// no completion, so `HubView` dismisses and opens back to back, and a host that
    /// presents the destination with UIKit can still lose the race. Closing that needs
    /// a completion-capable dismiss on the public `HubView` initializer, a separate
    /// change.
    var hubDismissThenOpen: ((URL) -> Void)? {
        get { self[HubDismissThenOpenKey.self] }
        set { self[HubDismissThenOpenKey.self] = newValue }
    }
}

extension View {
    func refreshPosts(_ refreshPosts: @escaping @Sendable () async -> Void) -> some View {
        environment(\.refreshHub, refreshPosts)
    }
}
