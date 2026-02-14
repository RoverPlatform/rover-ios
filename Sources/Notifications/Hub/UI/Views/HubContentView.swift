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
import RoverExperiences
import SwiftUI

struct HubContentView: View {
    @ObservedObject var coordinator: HubCoordinator
    @Environment(\.configSync) private var configSync

    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            ZStack {
                if coordinator.isHomeEnabled, let url = coordinator.homeViewExperienceURL {
                    ExperienceView(url: url, path: $coordinator.navigationPath)
                        // The experience rendered by ExperienceView may
                        // have its root screen configured without a navigation bar.
                        // In that case, ScreenView sets the navigation bar visibility
                        // to `.hidden`. However, HubContentView needs the navigation bar to
                        // be visible so it can display the inbox toolbar button.
                        //
                        // By explicitly setting `.toolbar(.visible, for: .navigationBar)`
                        // here, we override the hidden state set by ScreenView and
                        // ensure the inbox button is always accessible. This works
                        // because SwiftUI resolves toolbar visibility from the
                        // outermost modifier, so this parent-level override takes
                        // precedence over the child ScreenView's hidden setting.
                        .toolbar(.visible, for: .navigationBar)
                        .toolbar {
                            if coordinator.isInboxEnabled {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button {
                                        coordinator.navigationPath.append(HubPath.messages)
                                    } label: {
                                        Image(systemName: "envelope")
                                            .badge(unreadPostsCount)
                                    }
                                }
                            }
                        }
                } else {
                    inboxOrEmpty
                }
            }
            .onAppear {
                Task {
                    await configSync?.sync()
                }

                if coordinator.isHomeEnabled {
                    Task {
                        await coordinator.fetchHomeView()
                    }
                }
            }
            .navigationDestination(for: HubPath.self) { path in
                switch path {
                case .messages:
                    MessagesView(navigationPath: $coordinator.navigationPath)
                }
            }
            .navigationDestination(for: PostDestination.self) { postDestination in
                PostDetailView(
                    postID: postDestination.postID,
                    accentColor: coordinator.accentColor,
                    showAlert: $coordinator.showPostAlert
                )
            }
        }
        .tint(coordinator.accentColor)
        .optionalColorScheme(coordinator.colorScheme)
    }

    @ViewBuilder
    private var inboxOrEmpty: some View {
        if coordinator.isInboxEnabled {
            MessagesView(navigationPath: $coordinator.navigationPath)
        }
    }

    @FetchRequest(
        sortDescriptors: [], predicate: NSPredicate(format: "isRead == %@", NSNumber(value: false)), animation: nil)
    private var unreadPosts: FetchedResults<Post>

    private var unreadPostsCount: Int {
        unreadPosts.count
    }
}
