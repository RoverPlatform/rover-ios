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
    @Environment(\.conversationSync) private var conversationSync
    @Environment(\.eventQueue) private var eventQueue
    @Environment(\.hubDismissThenOpen) private var dismissThenOpen

    @EnvironmentObject private var hubCoordinator: HubCoordinator

    @FetchRequest private var conversationResult: FetchedResults<Conversation>

    @State private var pollingTask: Task<Void, Never>?
    @State private var orchestrator: ConversationDetailOrchestrator?
    @State private var hasTrackedOpen = false

    /// How far this screen has got in obtaining its conversation. Drives the content, which is
    /// why the not-found outcome cannot live only in the alert below: a presentation raised while
    /// another transition is in flight can be dropped and never retried.
    @State private var loadState: ConversationLoadState = .idle
    /// The on-demand fetch, so leaving the screen mid-fetch cancels it and nothing runs afterwards.
    @State private var fetchTask: Task<Void, Never>?
    /// Presents the not-found alert. Best-effort, on top of the content `loadState` already
    /// guarantees, and separate from it because SwiftUI writes this one back on dismissal.
    @State private var showNotFoundAlert = false

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

    /// What the screen shows, decided from the data rather than from which callback ran last.
    private var phase: ConversationDetailPhase {
        ConversationDetailPhase(hasConversation: conversation != nil, load: loadState)
    }

    /// The thread, a progress indicator, or the not-found state.
    @ViewBuilder
    private var conversationContent: some View {
        switch phase {
        case .loading:
            // Nothing to show yet, and no composer: a reply must not be typed into a
            // conversation that is not in the store.
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .notFound:
            ConversationNotFoundView { dismiss() }
        case .thread:
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
                    },
                    onOpenURL: openReplyLink
                )
                .ignoresSafeArea(.container, edges: .top)
            }
        }
    }

    var body: some View {
        ZStack {
            conversationContent

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
        .alert("Conversation not found", isPresented: $showNotFoundAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("This conversation could not be found.")
        }
        .navigationTitle(conversation?.subject ?? "Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard conversation != nil else {
                // Not in the store yet: a deep link or push tap for a conversation the list
                // has not synced (a fresh install, or a link fired before the forward poll).
                // Fetch it on demand rather than dismiss, matching the post detail screen and
                // the Android detail screen. Only if the server does not have it either does
                // the user see an alert whose dismissal pops back.
                fetchMissingConversation()
                return
            }
            beginShowing()
        }
        .onDisappear {
            stopFetching()
            hubCoordinator.conversationDidDisappear(conversationID)
            stopSync()
            // Back to square one: the sync has stopped and the fetch is cancelled, so a genuine
            // reappearance must be able to start both again.
            loadState = .idle
        }
        .onReceive(collectionCoordinator.reachedBottom) {
            guard let orchestrator else { return }
            Task { await orchestrator.onReachedBottom(conversationID: conversationID) }
        }
        .onChange(of: conversation?.objectID) { _, newID in
            // If the fetched conversation disappears while the screen is visible (a 410-driven
            // reset), the navigation destination is no longer valid. Pop back to the list
            // using the standard SwiftUI navigation animation.
            guard newID != nil else {
                dismiss()
                return
            }
            // A conversation arriving late flips the phase to `.thread` on the data alone, so
            // without this the thread would render with neither display tracking nor reply sync
            // running. The alert goes too: the store has since answered its question.
            //
            // Only while the screen is live, which is what `.idle` rules out. A retained
            // offscreen view would otherwise undo its own teardown and resume polling out of
            // sight.
            guard loadState != .idle else { return }
            showNotFoundAlert = false
            beginShowing()
        }
    }

    // MARK: - Links

    /// Policy for a link tapped in a reply bubble. A deep link into this app from a
    /// modally presented surface must dismiss first or land behind the modal
    /// (SDK-425); everything else keeps the system behaviour, including web links.
    /// Installed on the bubble cells by the collection view (not via this view's
    /// environment, which `UIHostingConfiguration` content does not inherit).
    private func openReplyLink(_ url: URL) -> OpenURLAction.Result {
        switch HubLinkOpenClassifier.live.decide(url, canDismiss: dismissThenOpen != nil) {
        case .dismissThenOpen:
            dismissThenOpen?(url)
            return .handled
        case .openInPlace, .presentInAppBrowser:
            return .systemAction
        }
    }

    // MARK: - Availability

    /// The conversation is in the store: report it displayed and start the reply sync.
    ///
    /// Idempotent for one appearance, because `onChange` and the fetch's success path can both
    /// reach it for the same arrival, and a second call would cancel the reply sync the first
    /// just started. `onDisappear` returns the state to `.idle`, so a real reappearance starts
    /// again.
    private func beginShowing() {
        guard loadState != .showing else { return }
        loadState = .showing
        hubCoordinator.conversationDidAppear(conversationID)
        startSync()
    }

    /// Fetches a conversation that was absent on appear, then either shows it or reports it
    /// missing. Without a sync service there is nothing to fetch with, so report missing at once.
    /// A fetch already in flight is left alone: `onAppear` can fire again while it runs.
    private func fetchMissingConversation() {
        guard fetchTask == nil else { return }
        guard let container, let conversationSync else {
            reportNotFound()
            return
        }
        // Supersedes any previous `.notFound`, so a retry shows progress rather than a stale error.
        loadState = .fetching
        let loader = ConversationDetailLoader(container: container, conversationSync: conversationSync)
        fetchTask = Task { @MainActor in
            let available = await loader.ensureAvailable(conversationID: conversationID)
            // The screen was left while the fetch ran: it has already reported itself gone
            // and stopped its sync, so showing it now would leave both running unowned.
            guard !Task.isCancelled else { return }
            fetchTask = nil
            guard available else {
                reportNotFound()
                return
            }
            beginShowing()
        }
    }

    /// Records the missing conversation in the screen's own state, and asks for the alert.
    ///
    /// Both, not just the alert: SwiftUI drops a presentation requested while another transition
    /// is in flight and never retries it, which a deep link dismissing a sheet on its way in
    /// reliably produces. The state is what guarantees the screen says something.
    private func reportNotFound() {
        loadState = .notFound
        showNotFoundAlert = true
    }

    /// Cancels an in-flight fetch. Leaves `loadState` alone: the only caller is `onDisappear`,
    /// which resets it, and a cancelled fetch has reported nothing worth recording.
    private func stopFetching() {
        fetchTask?.cancel()
        fetchTask = nil
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
