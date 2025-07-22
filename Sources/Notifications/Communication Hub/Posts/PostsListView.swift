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

import SwiftUI
import UIKit
import CoreData
import os.log

struct PostsListView: View {
    var initialPostID: String? = nil

    @Environment(\.communicationHubContainer) private var container
    @Environment(\.refreshCommunicationHub) var refreshCommunicationHub
    @Environment(\.rchSync) private var rchSync

    @State private var searchText: String = ""
    @State private var hasNavigatedToInitialPost = false

    @Binding private var navigationPath: NavigationPath
    @State private var postNavigationState: PostNavigationState = .idle

    // Core Data fetch requests
    @FetchRequest private var posts: FetchedResults<Post>

    init(navigationPath: Binding<NavigationPath>, initialPostID: String? = nil) {
        self.initialPostID = initialPostID

        // Initialize the fetch request for posts
        _posts = FetchRequest(fetchRequest: RCHPersistentContainer.fetchPosts())

        _navigationPath = navigationPath
    }

    var body: some View {
        List {
            ForEach(filteredPosts, id: \.id) { post in
                PostRowView(post: post)
            }

        }
        .refreshable {
            await refreshCommunicationHub()
        }
        .listStyle(.plain)
        .navigationDestination(for: Post.self) { post in
            PostDetailView(post: post)
        }
        .task {
            os_log("PostsListView: navigating to Post ID", log: .communicationHub, type: .debug)
            if let initialPostID = initialPostID, !hasNavigatedToInitialPost {
                hasNavigatedToInitialPost = true
                await navigateToPost(id: initialPostID)
            }
        }
        .onChange(of: initialPostID) { _ in
            hasNavigatedToInitialPost = false
        }
        .overlay {
            if case .loading = postNavigationState {
                VStack {
                    ProgressView("Loading post...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3))
            }
        }
        .alert("Post Not Found", isPresented: .constant(postNavigationState == .notFound)) {
            Button("OK") {
                postNavigationState = .idle
            }
        } message: {
            Text("The requested post could not be found.")
        }
        .alert("Error", isPresented: .constant(postNavigationState.isError)) {
            Button("OK") {
                postNavigationState = .idle
            }
        } message: {
            if case .error(let message) = postNavigationState {
                Text(message)
            }
        }
        .searchable(text: $searchText)
    }
    
    func navigateToPost(id: String) async {
        guard let container = container else { return }
        
        // Phase 1: Fast local lookup
        if let post = container.fetchPostByID(uuidString: id) {
            // FAST PATH: Post exists locally, navigate immediately
            navigationPath.append(post)
            return
        }
        
        // Phase 2: Post missing, sync and retry
        postNavigationState = .loading
        
        guard let rchSync = rchSync else {
            postNavigationState = .error("Sync service not available")
            return
        }
        
        let syncSuccess = await rchSync.sync()
        
        if syncSuccess, let post = container.fetchPostByID(uuidString: id) {
            // Post found after sync
            postNavigationState = .found(post)
            navigationPath.append(post)
        } else {
            // Post still not found
            postNavigationState = .notFound
        }
    }

    var filteredPosts: [Post] {
        if searchText.isEmpty {
            return Array(posts)
        } else {
            return posts.filter {
                $0.subject?.localizedCaseInsensitiveContains(searchText) == true ||
                $0.previewText?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }

    private func markPostAsRead(_ post: Post) {
        guard let container = container else { return }
        container.markPostAsRead(post)
    }
}

private struct PostRowView: View {
    @ObservedObject var post: Post

    var body: some View {
        NavigationLink(value: post) {
            HStack(alignment: .top, spacing: 0) {
                // Content column
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if !post.isRead {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 10, height: 10)
                        }
                        Text(post.subject ?? "")
                            .bold()
                            .lineLimit(1)
                            .foregroundColor(post.isRead ? .secondary : .primary)
                    }
                    Text(post.previewText ?? "")
                        .font(.subheadline)
                        .foregroundColor(post.isRead ? .secondary : .primary)
                        .lineLimit(2)
                    HStack(spacing: 4) {
                        Text(post.receivedAt?.formattedTimestamp() ?? "")

                        if let subscription = post.subscription {
                            SubscriptionCaptionView(subscription: subscription)
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }

                Spacer(minLength: 4)

                // Cover image as square thumbnail
                if let coverImageURL = post.coverImageURL {
                    AsyncImage(url: coverImageURL) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(width: 70, height: 70)
                                .cornerRadius(8)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 70, height: 70)
                                .cornerRadius(8)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color(.systemGray6))
                                .frame(width: 70, height: 70)
                                .cornerRadius(8)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
        }
    }
}

private struct SubscriptionCaptionView: View {
    @ObservedObject var subscription: Subscription

    @ViewBuilder
    var body: some View {
        if let name = subscription.name {
            Text("•")
            Text(name)
        }
    }
}
