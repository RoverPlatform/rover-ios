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

import CoreData
import SwiftUI

/// Thin SwiftUI shell for the conversation detail screen.
///
/// Hosts:
/// - `ConversationCollectionViewRepresentable` — the UIKit collection view with FRC, scroll coordinator,
///   and the hosted `ComposerView` pinned to `keyboardLayoutGuide`
/// - `NewMessagesPillView` — floating "N new messages" overlay padded above the composer
///
/// Uses `@FetchRequest` only for the `Conversation` entity (subject, read state).
/// Replies are driven entirely by `NSFetchedResultsController` inside the representable.
struct ConversationDetailView: View {
    let conversationID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.hubContainer) private var container
    @Environment(\.replySync) private var replySync
    @Environment(\.eventQueue) private var eventQueue

    @EnvironmentObject private var hubCoordinator: HubCoordinator

    @FetchRequest private var conversationResult: FetchedResults<Conversation>

    @State private var pollingTask: Task<Void, Never>?
    @State private var orchestrator: ConversationDetailOrchestrator?
    @State private var hasTrackedOpen = false

    @StateObject private var collectionCoordinator = ConversationScrollCoordinator()

    init(conversationID: UUID) {
        self.conversationID = conversationID
        _conversationResult = FetchRequest(
            fetchRequest: {
                let request = Conversation.fetchRequest()
                request.predicate = NSPredicate(
                    format: "id == %@",
                    conversationID as CVarArg
                )
                request.sortDescriptors = [
                    NSSortDescriptor(key: "createdAt", ascending: true)
                ]
                request.fetchLimit = 1
                return request
            }()
        )
    }

    private var conversation: Conversation? {
        conversationResult.first
    }

    var body: some View {
        ZStack {
            if let container, let replySync {
                ConversationCollectionViewRepresentable(
                    conversationID: conversationID,
                    container: container,
                    scrollCoordinator: collectionCoordinator,
                    onLoadOlderMessages: { [conversationID] in
                        await replySync.syncBackwards(conversationID: conversationID)
                    },
                    onSend: { [conversationID] text in
                        Task {
                            await replySync.sendReply(conversationID: conversationID, text: text)
                        }
                    }
                )
                .ignoresSafeArea(.container, edges: .top)
            }

            // "N new messages" pill — floats above the composer.
            // composerHeight is published from viewDidLayoutSubviews (on the child VC).
            // UIKit's additionalSafeAreaInsets on a child VC do NOT propagate up to the
            // SwiftUI hosting view's safe area, so the pill requires explicit padding.
            if collectionCoordinator.pendingNewMessageCount > 0
                && !collectionCoordinator.isAtBottom
            {
                NewMessagesPillView(
                    count: collectionCoordinator.pendingNewMessageCount,
                    onTap: {
                        collectionCoordinator.scrollToBottom(animated: true)
                    }
                )
                .padding(.bottom, collectionCoordinator.composerHeight)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .transition(.opacity)
                .animation(.spring(response: 0.3), value: collectionCoordinator.pendingNewMessageCount)
            }
        }
        .navigationTitle(conversation?.subject ?? "Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // A 410-driven reset can remove the backing conversation before this screen
            // fully appears. Dismiss immediately rather than leaving the user on an
            // invalid detail destination with no data behind it.
            guard conversation != nil else {
                dismiss()
                return
            }
            hubCoordinator.conversationDidAppear(conversationID)
            startSync()
        }
        .onDisappear {
            hubCoordinator.conversationDidDisappear(conversationID)
            stopSync()
        }
        .onReceive(collectionCoordinator.reachedBottom) {
            guard let orchestrator else { return }
            Task { await orchestrator.onReachedBottom(conversationID: conversationID) }
        }
        .onChange(of: conversation?.objectID) { _, newID in
            // If the fetched conversation disappears while the screen is visible,
            // the navigation destination is no longer valid. Pop back to the list
            // using the standard SwiftUI navigation animation.
            guard newID == nil else { return }
            dismiss()
        }
    }

    // MARK: - Sync

    @MainActor
    private func startSync() {
        stopSync()
        guard let replySync, let container else { return }
        trackConversationOpened()
        let orchestrator = ConversationDetailOrchestrator(sync: replySync, container: container)
        self.orchestrator = orchestrator
        pollingTask = Task { @MainActor in
            await orchestrator.onOpen(conversationID: conversationID)
            // Catch-up: the initial reachedBottom from viewDidLayoutSubviews may have fired
            // before .onReceive was installed (viewDidLayoutSubviews runs before onAppear).
            // After onOpen settles — which may have loaded newer server-confirmed replies —
            // check isAtBottom and mark read if the user is still at the bottom.
            if collectionCoordinator.isAtBottom {
                await orchestrator.onReachedBottom(conversationID: conversationID)
            }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    break
                }
                await orchestrator.onPoll(conversationID: conversationID)
            }
        }
    }

    // MARK: - Analytics

    private func trackConversationOpened() {
        guard !hasTrackedOpen, let eventQueue else { return }
        hasTrackedOpen = true
        eventQueue.addEvent(.conversationOpened(conversationID: conversationID))
    }

    @MainActor
    private func stopSync() {
        pollingTask?.cancel()
        pollingTask = nil
        orchestrator = nil
    }
}
