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
import SwiftUI
import os.log
import RoverData

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

// Environment key for accessing the InboxSync service throughout the app
struct InboxSyncKey: EnvironmentKey {
    static let defaultValue: InboxSync? = nil
}

// Environment key for accessing the EventQueue service throughout the app
struct EventQueueKey: EnvironmentKey {
    static let defaultValue: EventQueue? = nil
}

// Environment key for accessing the ConfigSync service throughout the app
struct ConfigSyncKey: EnvironmentKey {
    static let defaultValue: ConfigSync? = nil
}

extension EnvironmentValues {
    /// Rover Hub Core Data persistent container.
    var hubContainer: InboxPersistentContainer? {
        get { self[HubPersistentContainerKey.self] }
        set { self[HubPersistentContainerKey.self] = newValue }
    }

    /// Rover Hub sync service
    var inboxSync: InboxSync? {
        get { self[InboxSyncKey.self] }
        set { self[InboxSyncKey.self] = newValue }
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
}

extension View {
    func refreshPosts(_ refreshPosts: @escaping @Sendable () async -> Void) -> some View {
        environment(\.refreshHub, refreshPosts)
    }
}

