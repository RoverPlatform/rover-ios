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
    public init() {}

    public var body: some View {
        HubContentView(coordinator: coordinator)
            .environment(\.hubContainer, persistentContainer)
            .environment(\.managedObjectContext, persistentContainer.viewContext)
            .environment(\.refreshHub, { await refreshHub() })
            .environment(\.inboxSync, inboxSync)
            .environment(\.eventQueue, Rover.shared.eventQueue)
            .environment(\.configSync, configSync)
    }

    var coordinator: HubCoordinator {
        Rover.shared.resolve(HubCoordinator.self)!
    }

    var persistentContainer: InboxPersistentContainer {
        Rover.shared.resolve(InboxPersistentContainer.self)!
    }

    var inboxSync: InboxSync {
        Rover.shared.resolve(InboxSync.self)!
    }

    var configSync: ConfigSync {
        Rover.shared.resolve(ConfigSync.self)!
    }

    func refreshHub() async {
        await Rover.shared.resolve(SyncCoordinator.self)!.syncAsync()
    }
}
