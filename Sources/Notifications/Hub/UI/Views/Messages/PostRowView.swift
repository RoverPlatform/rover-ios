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
import os.log

struct PostRowView: View {
    @ObservedObject var post: Post
    @Binding var navigationPath: NavigationPath

    var body: some View {
        if let subscription = post.subscription, !subscription.isDeleted {
            PostRowBody(post: post, subscription: subscription, navigationPath: $navigationPath)
        } else {
            MessageRowView(
                isRead: post.isRead,
                avatarURL: nil,
                senderKind: .subscription,
                senderName: nil,
                date: post.receivedAt,
                subject: post.subject,
                previewText: post.previewText
            ) {
                guard let postID = post.id?.uuidString else {
                    os_log("Post missing ID, cannot navigate", log: .hub, type: .error)
                    return
                }
                navigationPath.append(PostDestination(postID: postID))
            }
        }
    }
}

private struct PostRowBody: View {
    @ObservedObject var post: Post
    @ObservedObject var subscription: Subscription
    @Binding var navigationPath: NavigationPath

    var body: some View {
        MessageRowView(
            isRead: post.isRead,
            avatarURL: subscription.logoURL,
            senderKind: .subscription,
            senderName: subscription.name,
            date: post.receivedAt,
            subject: post.subject,
            previewText: post.previewText
        ) {
            guard let postID = post.id?.uuidString else {
                os_log("Post missing ID, cannot navigate", log: .hub, type: .error)
                return
            }
            navigationPath.append(PostDestination(postID: postID))
        }
    }
}
