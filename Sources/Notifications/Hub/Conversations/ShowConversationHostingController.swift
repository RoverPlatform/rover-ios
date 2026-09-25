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
    /// Whether a link in a reply may dismiss this presentation before opening;
    /// resolved in `viewWillAppear`, once it is known if this controller is presented.
    private let presentation: HubDetailPresentationState

    init(conversationID: UUID) {
        let presentation = HubDetailPresentationState()
        self.presentation = presentation
        super.init(
            rootView: AnyView(ShowConversationView(conversationID: conversationID, presentation: presentation))
        )
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presentation.update(for: self)
    }
}

private struct ShowConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented
    @ObservedObject var presentation: HubDetailPresentationState

    let conversationID: UUID

    init(conversationID: UUID, presentation: HubDetailPresentationState) {
        self.conversationID = conversationID
        self.presentation = presentation
    }

    var body: some View {
        NavigationView {
            ConversationDetailView(conversationID: conversationID)
                .navigationBarTitleDisplayMode(.inline)
                // This standalone presentation never passes through HubContentView,
                // so it needs its own appearance reset to shield the bar from the
                // host app's global appearance proxy.
                .resetNavBarAppearance(.systemScrolledBackground)
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
        .environment(\.conversationSync, Rover.shared.resolve(ConversationSync.self)!)
        .environment(\.eventQueue, Rover.shared.eventQueue)
        .environment(\.hubDismissThenOpen, presentation.dismissThenOpen)
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
