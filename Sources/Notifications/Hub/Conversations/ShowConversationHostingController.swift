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

import RoverFoundation
import SwiftUI
import UIKit

final class ShowConversationHostingController: UIHostingController<AnyView> {
    init(conversationID: UUID) {
        super.init(rootView: AnyView(ShowConversationView(conversationID: conversationID)))
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct ShowConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented

    let conversationID: UUID

    var body: some View {
        NavigationView {
            ConversationDetailView(conversationID: conversationID)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if isPresented {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { dismiss() }
                        }
                    }
                }
        }
        .environmentObject(coordinator)
        .environment(\.hubContainer, persistentContainer)
        .environment(\.managedObjectContext, persistentContainer.viewContext)
        .environment(\.replySync, Rover.shared.resolve(ReplySync.self)!)
        .tint(accentColor)
        .optionalColorScheme(colorScheme)
    }

    private var coordinator: HubCoordinator {
        Rover.shared.resolve(HubCoordinator.self)!
    }

    private var persistentContainer: InboxPersistentContainer {
        Rover.shared.resolve(InboxPersistentContainer.self)!
    }

    private var accentColor: Color {
        coordinator.accentColor
    }

    private var colorScheme: ColorScheme? {
        coordinator.colorScheme
    }
}
