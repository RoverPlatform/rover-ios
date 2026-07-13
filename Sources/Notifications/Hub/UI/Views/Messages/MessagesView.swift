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

    @State private var searchText: String = ""
    @State private var pollingTask: Task<Void, Never>?
    @State private var backfillTask: Task<Void, Never>?
    // Stored as @State rather than a computed var to avoid re-sorting on every render.
    // Rebuilt only when the set of post/conversation objectIDs changes (see onChange handlers).
    @State private var sortedItems: [HubItem] = []

    @Binding private var navigationPath: NavigationPath

    @FetchRequest private var posts: FetchedResults<Post>
    @FetchRequest private var conversations: FetchedResults<Conversation>

    private let title: String

    init(navigationPath: Binding<NavigationPath>, title: String? = nil) {
        _posts = FetchRequest(fetchRequest: InboxPersistentContainer.fetchPosts())
        _conversations = FetchRequest(fetchRequest: InboxPersistentContainer.fetchConversations())
        _navigationPath = navigationPath
        self.title = title ?? "Messages"
    }

    var body: some View {
        List {
            ForEach(filteredItems) { item in
                switch item {
                case .post(let post):
                    PostRowView(post: post, navigationPath: $navigationPath)
                case .conversation(let conversation):
                    ConversationRowView(conversation: conversation, navigationPath: $navigationPath)
                }
            }
        }
        .refreshable { await refreshHub() }
        .listStyle(.plain)
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inlineLarge)
        .searchable(text: $searchText)
        .onAppear {
            startSync()
        }
        .onDisappear {
            stopSync()
        }
        .onChange(of: posts.map(\.objectID)) { rebuildSortedItems() }
        .onChange(of: conversations.map(\.objectID)) { rebuildSortedItems() }
        .task {
            // Required to populate the sorted items when the view launches
            rebuildSortedItems()
        }
    }

    private func rebuildSortedItems() {
        let postItems = posts.map { HubItem.post($0) }
        let convItems = conversations.map { HubItem.conversation($0) }
        sortedItems = (postItems + convItems).sorted { $0.activityAt > $1.activityAt }
    }

    var filteredItems: [HubItem] {
        guard !searchText.isEmpty else { return sortedItems }
        return sortedItems.filter { item in
            switch item {
            case .post(let p):
                return p.subject?.localizedCaseInsensitiveContains(searchText) == true
                    || p.previewText?.localizedCaseInsensitiveContains(searchText) == true
            case .conversation(let c):
                return c.subject?.localizedCaseInsensitiveContains(searchText) == true
                    || c.lastReplyPreview?.localizedCaseInsensitiveContains(searchText) == true
            }
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
