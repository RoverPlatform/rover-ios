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
import WebKit
import os.log
import RoverData
import RoverFoundation

public struct ShowPostView: View {
    let postID: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented
    @State private var postNavigationState: PostNavigationState = .idle
    @State private var loadedPost: Post?

    public var body: some View {
        // NavigationView just for title bar.
        NavigationView {
            Group {
                if let post = loadedPost {
                    PostDetailView(post: post)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isPresented {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .environment(\.communicationHubContainer, persistentContainer)
        .environment(\.eventQueue, Rover.shared.eventQueue)
        .task {
            await loadPost()
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
                dismiss()
                postNavigationState = .idle
            }
        } message: {
            Text("The requested post could not be found.")
        }
        .alert("Error", isPresented: .constant(postNavigationState.isError)) {
            Button("OK") {
                dismiss()
                postNavigationState = .idle
            }
        } message: {
            if case .error(let message) = postNavigationState {
                Text(message)
            }
        }
    }

    var persistentContainer: RCHPersistentContainer {
        Rover.shared.resolve(RCHPersistentContainer.self)!
    }

    var rchSync: RCHSync {
        Rover.shared.resolve(RCHSync.self)!
    }

    func loadPost() async {
        guard let postID else {
            postNavigationState = .notFound
            return
        }

        // Phase 1: Fast local lookup
        if let post = persistentContainer.fetchPostByID(uuidString: postID) {
            // FAST PATH: Post exists locally, show immediately
            loadedPost = post
            postNavigationState = .found(post)
            return
        }

        // Phase 2: Post missing, sync and retry
        postNavigationState = .loading

        let syncSuccess = await rchSync.sync()

        if syncSuccess, let post = persistentContainer.fetchPostByID(uuidString: postID) {
            // Post found after sync
            loadedPost = post
            postNavigationState = .found(post)
        } else {
            // Post still not found
            postNavigationState = .notFound
        }
    }
}
