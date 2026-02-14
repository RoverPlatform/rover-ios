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

    @State private var searchText: String = ""

    @Binding private var navigationPath: NavigationPath

    // Core Data fetch requests
    @FetchRequest private var posts: FetchedResults<Post>

    private let title: String

    init(navigationPath: Binding<NavigationPath>, title: String? = nil) {
        // Initialize the fetch request for posts
        _posts = FetchRequest(fetchRequest: InboxPersistentContainer.fetchPosts())
        _navigationPath = navigationPath
        self.title = title ?? "Messages"
    }

    var body: some View {
        List {
            ForEach(filteredPosts) { post in
                PostRowView(post: post, navigationPath: $navigationPath)
            }
        }
        .refreshable {
            await refreshHub()
        }
        .listStyle(.plain)
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inlineLarge)
        .searchable(text: $searchText)
    }

    var filteredPosts: [Post] {
        if searchText.isEmpty {
            return Array(posts)
        } else {
            return posts.filter {
                $0.subject?.localizedCaseInsensitiveContains(searchText) == true
                    || $0.previewText?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
}

private struct PostRowView: View {
    @ObservedObject var post: Post
    @Binding var navigationPath: NavigationPath

    var body: some View {
        Button {
            // In-app navigation: append destination directly to path
            guard let postID = post.id?.uuidString else {
                os_log("Post missing ID, cannot navigate", log: .hub, type: .error)
                return
            }
            let destination = PostDestination(postID: postID)
            navigationPath.append(destination)
        } label: {
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SubscriptionCaptionView: View {
    @ObservedObject var subscription: Subscription

    @ViewBuilder
    var body: some View {
        if let name = subscription.name {
            Text("•")
            Text(name)
                .lineLimit(1)
        }
    }
}
