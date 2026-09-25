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
import UIKit
import os.log

struct MessagesView: View {
    @Environment(\.hubContainer) private var container
    @Environment(\.refreshHub) var refreshHub
    @Environment(\.conversationSync) private var conversationSync
    @Environment(\.inboxSeenWatermark) private var inboxSeenWatermark
    @Environment(\.scenePhase) private var scenePhase

    @State private var searchText: String = ""
    // Tracks whether the inbox is the view on screen, so the backgrounding hook below only fires
    // while it actually is — scenePhase changes are delivered to every live view.
    @State private var isVisible = false
    @State private var searchTokens: [HubSearchToken] = []
    @State private var pollingTask: Task<Void, Never>?
    @State private var backfillTask: Task<Void, Never>?
    // Stored as @State rather than a computed var to avoid re-sorting on every render.
    // Rebuilt only when the set of post/conversation objectIDs changes (see onChange handlers).
    @State private var sortedItems: [HubItem] = []

    @Binding private var navigationPath: NavigationPath

    @FetchRequest private var posts: FetchedResults<Post>
    @FetchRequest private var conversations: FetchedResults<Conversation>

    private let title: String
    // `.inlineLarge` puts the title in the bar's leading slot, and iOS 26 folds any
    // leading toolbar item into a trailing overflow menu to make room. A caller that
    // installs a leading item (the modal Hub's close button) passes `.inline` instead.
    private let titleDisplayMode: ToolbarTitleDisplayMode

    init(
        navigationPath: Binding<NavigationPath>,
        title: String? = nil,
        titleDisplayMode: ToolbarTitleDisplayMode = .inlineLarge
    ) {
        _posts = FetchRequest(fetchRequest: InboxPersistentContainer.fetchPosts())
        _conversations = FetchRequest(fetchRequest: InboxPersistentContainer.fetchConversations())
        _navigationPath = navigationPath
        self.title = title ?? "Messages"
        self.titleDisplayMode = titleDisplayMode
    }

    var body: some View {
        let suggestions = suggestedTokens
        List {
            // Suggestions render inside the list (rather than via
            // .searchSuggestions) so token suggestions and matching results
            // stay visible together, the way Mail presents Top Hits
            // alongside Suggestions.
            if !suggestions.isEmpty {
                Section("Suggestions") {
                    ForEach(suggestions) { token in
                        Button {
                            searchTokens = [token]
                            searchText = ""
                        } label: {
                            HStack(spacing: 12) {
                                suggestionImage(for: token)
                                Text(token.name)
                            }
                        }
                    }
                }
            }
            Section {
                ForEach(filteredItems) { item in
                    switch item {
                    case .post(let post):
                        PostRowView(post: post, navigationPath: $navigationPath)
                    case .conversation(let conversation):
                        ConversationRowView(conversation: conversation, navigationPath: $navigationPath)
                    }
                }
            } header: {
                // A results header only when the suggestions section is
                // visible, so hub items don't read as belonging to the last
                // suggested contact or subscription.
                if !suggestions.isEmpty {
                    Text("Results")
                }
            }
        }
        .refreshable { await refreshHub() }
        .listStyle(.plain)
        .navigationTitle(title)
        .toolbarTitleDisplayMode(titleDisplayMode)
        .modifier(
            SearchTokenModifier(searchText: $searchText, searchTokens: $searchTokens)
        )
        .onAppear {
            startSync()
            isVisible = true
            // This view is the inbox body for both entry paths — the pushed `HubPath.messages`
            // route and the inbox-as-root case when home is disabled — so hooking the watermark
            // here covers both.
            markInboxSeen()
        }
        .onDisappear {
            stopSync()
            isVisible = false
            // Mark again on the way out: items that arrived while the list was open were also
            // seen, and the `onAppear` watermark predates them.
            markInboxSeen()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Neither `onAppear` nor `onDisappear` fires across a background/foreground round trip
            // while this view stays in the hierarchy, so both directions need marking here:
            // `.background` because an item that lands while the inbox is on screen would otherwise
            // leave a stale icon badge behind, and `.active` because an item that arrives *while
            // backgrounded* would otherwise badge over the open list until the user navigates
            // away. `.inactive` is deliberately not handled — it also fires for Notification
            // Center pulls, the app switcher, and Control Center, none of which take the inbox off
            // screen, and the return to `.active` marks seen anyway.
            guard isVisible, newPhase == .background || newPhase == .active else { return }
            markInboxSeen()
        }
        .onChange(of: posts.map(\.objectID)) {
            rebuildSortedItems()
            // Absorb posts that sync in while the user is looking at the list. A device-time
            // watermark used to cover this for free — a mark taken at reveal was already ahead of
            // the `receivedAt` of anything that landed later — but a watermark written only from
            // observed item timestamps moves only when it is told to, so without this a post
            // arriving mid-view badges over the very list the user is reading until they navigate
            // away.
            guard isVisible else { return }
            markInboxSeen()
        }
        .onChange(of: conversations.map(\.objectID)) { rebuildSortedItems() }
        .onChange(of: conversations.compactMap(\.badgeActivityAt).max()) {
            // Absorb incoming conversation replies that sync in while the user is looking at the
            // list — the same mid-view case the posts handler above covers. Keyed on the incoming
            // activity max rather than the objectID set because a reply usually lands as an
            // in-place timestamp bump on an existing row, which changes no objectIDs. Outgoing
            // optimistic replies update `lastReplyAt` only and must not advance the seen watermark.
            guard isVisible else { return }
            markInboxSeen()
        }
        .task {
            // Required to populate the sorted items when the view launches
            rebuildSortedItems()
        }
    }

    /// Advances the seen watermark to the newest item in the store — post `receivedAt` or
    /// conversation incoming-reply activity — because everything the list is showing has been
    /// seen. The newest timestamp *is* the mark rather than a floor under some device-clock value,
    /// so the watermark carries only timestamps the badge actually compares against; see
    /// `InboxSeenWatermark`. Outgoing replies are deliberately excluded from both sides.
    private func markInboxSeen() {
        let newestActivity =
            (posts.compactMap(\.receivedAt) + conversations.compactMap(\.badgeActivityAt)).max()
        inboxSeenWatermark?.markSeen(upTo: newestActivity)
    }

    private func rebuildSortedItems() {
        let postItems = posts.map { HubItem.post($0) }
        let convItems = conversations.map { HubItem.conversation($0) }
        sortedItems = (postItems + convItems).sorted { $0.activityAt > $1.activityAt }
    }

    var filteredItems: [HubItem] {
        HubSearchFilter.filter(
            items: sortedItems,
            searchText: searchText,
            token: searchTokens.first
        )
    }

    private var suggestedTokens: [HubSearchToken] {
        guard searchTokens.isEmpty else { return [] }
        return HubSearchFilter.suggestions(items: sortedItems, searchText: searchText)
    }

    /// The same imagery the message rows use, so a suggestion previews
    /// exactly what its results will look like.
    @ViewBuilder
    private func suggestionImage(for token: HubSearchToken) -> some View {
        switch token {
        case .subscription:
            LogoView(url: token.imageURL, size: 32)
        case .sender:
            AvatarView(url: token.imageURL, name: token.name, size: 32)
        }
    }

    private func startSync() {
        stopSync()
        guard let sync = conversationSync else { return }
        pollingTask = Task {
            while !Task.isCancelled {
                await sync.syncForward()
                do {
                    try await Task.sleep(for: .seconds(10))
                } catch {
                    break
                }
            }
        }
        backfillTask = Task {
            await sync.syncBackward()
        }
    }

    private func stopSync() {
        pollingTask?.cancel()
        pollingTask = nil
        backfillTask?.cancel()
        backfillTask = nil
    }
}
