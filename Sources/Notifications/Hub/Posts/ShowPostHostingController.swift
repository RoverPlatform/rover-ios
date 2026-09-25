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

public class ShowPostHostingController: UIHostingController<AnyView> {
    /// Whether a link in the post may dismiss this presentation before opening;
    /// resolved in `viewWillAppear`, once it is known if this controller is presented.
    private let presentation: HubDetailPresentationState

    public init(postID: String?) {
        let presentation = HubDetailPresentationState()
        self.presentation = presentation
        super.init(rootView: AnyView(ShowPostView(postID: postID, presentation: presentation)))
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presentation.update(for: self)
    }
}

private struct ShowPostView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented
    @ObservedObject var presentation: HubDetailPresentationState
    @State private var showAlert: Bool = false
    let postID: String?

    init(postID: String?, presentation: HubDetailPresentationState) {
        self.postID = postID
        self.presentation = presentation
    }

    var body: some View {
        NavigationView {
            PostDetailView(postID: postID, accentColor: accentColor, showAlert: $showAlert)
                .navigationTitle("Post")
                .navigationBarTitleDisplayMode(.inline)
                // This standalone presentation never passes through HubContentView,
                // so it needs its own appearance reset to shield the bar from the
                // host app's global appearance proxy.
                .resetNavBarAppearance(.systemScrolledBackground)
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
        .environment(\.hubContainer, Rover.shared.resolve(InboxPersistentContainer.self)!)
        .environment(\.eventQueue, Rover.shared.eventQueue)
        .environment(\.postSync, Rover.shared.resolve(PostSync.self)!)
        .environment(\.hubDismissThenOpen, presentation.dismissThenOpen)
        .optionalColorScheme(colorScheme)
    }

    var accentColor: Color {
        Rover.shared.resolve(HubCoordinator.self)!.accentColor
    }

    var colorScheme: ColorScheme? {
        Rover.shared.resolve(HubCoordinator.self)!.colorScheme
    }
}
