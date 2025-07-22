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
        assertionFailure("Refresh communication hub requested, but not defined in environment!")
        os_log(.info, log: .communicationHub, "Refresh posts requested, but not defined in environment!")
     }
}

private struct AccentColorKey: EnvironmentKey {
    static let defaultValue: Color = .accentColor
}

// Environment key for accessing the persistent container throughout the app
struct CommunicationHubPersistentContainerKey: EnvironmentKey {
    static let defaultValue: RCHPersistentContainer? = nil
}

// Environment key for accessing the RCHSync service throughout the app
struct RCHSyncKey: EnvironmentKey {
    static let defaultValue: RCHSync? = nil
}

// Environment key for accessing the EventQueue service throughout the app
struct EventQueueKey: EnvironmentKey {
    static let defaultValue: EventQueue? = nil
}

extension EnvironmentValues {
    /// Rover communication hub Core Data persistent container.
    var communicationHubContainer: RCHPersistentContainer? {
        get { self[CommunicationHubPersistentContainerKey.self] }
        set { self[CommunicationHubPersistentContainerKey.self] = newValue }
    }

    /// Rover communication hub sync service
    var rchSync: RCHSync? {
        get { self[RCHSyncKey.self] }
        set { self[RCHSyncKey.self] = newValue }
    }

    var refreshCommunicationHub: @Sendable () async -> Void {
        get { self[RefreshHubKey.self] }
        set { self[RefreshHubKey.self] = newValue }
    }

    var roverCommunicationHubAccentColor: Color {
        get { self[AccentColorKey.self] }
        set { self[AccentColorKey.self] = newValue }
    }
    
    /// Rover event queue for tracking events
    var eventQueue: EventQueue? {
        get { self[EventQueueKey.self] }
        set { self[EventQueueKey.self] = newValue }
    }
}

extension View {
    func refreshPosts(_ refreshPosts: @escaping @Sendable () async -> Void) -> some View {
        environment(\.refreshCommunicationHub, refreshPosts)
    }
}

