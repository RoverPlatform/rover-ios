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

import RoverData
import RoverFoundation
import SwiftUI

/// Embed this view within a tab to integrate the Rover Hub
public struct CommunicationHubView: View {
    /// Presentation state shared with an owning `CommunicationHubHostingController`,
    /// mirroring `HubView`'s own `presentation` plumbing. Its `onDismissButtonPressed`
    /// is `nil` while embedded (a bare `CommunicationHubView()`) and a real dismissal
    /// only once the controller confirms it is presented modally; observing it here
    /// threads that live value into the underlying `HubView` so a presented Hub honors
    /// the `openURL { dismiss: true }` teardown and shows the close affordance.
    ///
    /// This deliberately duplicates `HubView`'s state threading rather than sharing a
    /// common base. `CommunicationHubView` / `CommunicationHubHostingController` are
    /// compatibility shims (renamed, soon to be deprecated) whose public
    /// `UIHostingController<CommunicationHubView>` specialization must be preserved —
    /// customers may name that exact type — so the wiring is copied here on purpose. See
    /// [[HubView]] for the canonical implementation this mirrors.
    @ObservedObject private(set) var presentation: HubPresentationState

    public init() {
        // A bare `CommunicationHubView()` owns its own state, whose dismissal handler
        // stays `nil` — non-dismissable, no close chrome, exactly like `HubView()`.
        self.presentation = HubPresentationState()
    }

    /// Creates the Rover Hub view for modal presentation, such as in a SwiftUI sheet.
    /// Use this overload (`onDismissButtonPressed` provided) when presenting the Hub
    /// modally. The Hub will include a close button that will call back to
    /// `onDismissButtonPressed`.
    ///
    /// - Parameter onDismissButtonPressed: Supply a closure that will be called when
    ///   the button is pressed. If this closure is not provided, then no close button
    ///   will appear.
    public init(onDismissButtonPressed: (() -> Void)?) {
        let presentation = HubPresentationState()
        presentation.onDismissButtonPressed = onDismissButtonPressed
        self.presentation = presentation
    }

    public init(
        navigator: CommunicationHubNavigator,
        title: String? = nil,
        accentColor: Color = .accentColor,
        navigationBarBackgroundColor: Color? = nil,
        navigationBarColorScheme: ColorScheme? = nil
    ) {
        // Configuration is now automatically managed via ConfigManager.
        self.presentation = HubPresentationState()
    }

    /// Internal initializer used by `CommunicationHubHostingController` to share its
    /// presentation state, so a modal presentation resolved at `viewWillAppear` threads
    /// the dismissal handler into the underlying `HubView` without re-rooting the tree.
    init(presentation: HubPresentationState) {
        self.presentation = presentation
    }

    public var body: some View {
        HubView(presentation: presentation)
    }
}
