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
import os.log

/// Displays the Hub as a UIViewController (suitable for modal presentation within the routing system), or when embedding in a UIKit UITabBarController.
public class HubHostingController: UIHostingController<HubView> {

    /// Presentation state shared with the hosted `HubView`. Starts with a `nil`
    /// dismissal handler (the embedded default) and is published as a real dismissal
    /// only once `viewWillAppear` confirms this controller is genuinely presented
    /// modally — see `viewWillAppear`.
    private let presentation = HubPresentationState()

    /// Instantiate a Rover Hub view controller.
    public init() {
        // Seed with a placeholder so `super.init` has a root view, then immediately
        // re-root with a `HubView` sharing this controller's `presentation` state.
        // Both happen at init time, BEFORE the view first renders, so — unlike
        // re-rooting later in the lifecycle — no re-render or App Screens web-view
        // reload results. The dismissal handler itself is threaded LATER, not here:
        // at init `self` cannot yet know whether it will be presented or embedded, so
        // `presentation.onDismissButtonPressed` stays `nil` until `viewWillAppear`
        // resolves the hosting relationship and publishes the real closure (if any).
        super.init(rootView: HubView())
        rootView = HubView(presentation: presentation)
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // The hosting relationship is only established once this controller is
        // appearing (never at init/`viewDidLoad`), so decide HERE whether the Hub is a
        // genuine modal presentation, then publish the dismissal handler accordingly:
        // a real closure when presented, `nil` when embedded. That single handler is
        // the whole gate — the App Screens home installs the xmark close item AND
        // honors an `openURL { dismiss: true }` teardown iff it is non-`nil`, so an
        // embedded (tabbed/pushed) Hub gets neither a dead xmark nor a stray dismiss.
        //
        // Publishing rides `presentation` → the existing
        // `AppScreensExperienceRepresentable.updateUIViewController` live path (the
        // same one an inbox-badge update takes), so the flip never re-roots the
        // SwiftUI tree or reloads the App Screens web view. Only publish on an actual
        // change (a fresh closure would otherwise re-fire on every re-appearance).
        let shouldBeDismissable = isPresentedModally
        guard shouldBeDismissable != (presentation.onDismissButtonPressed != nil) else {
            return
        }
        presentation.onDismissButtonPressed =
            shouldBeDismissable ? { [weak self] in self?.dismissIfPresentedModally() } : nil
    }

    /// `true` only when this controller is actually presented modally in its own
    /// right — not when it is embedded (in a tab, or pushed). The `tabBarController ==
    /// nil` guard rejects an embedded-in-a-tab Hub (even one inside a presented tab
    /// bar), and `presentedViewController === self` confirms this controller is itself
    /// the modally-presented one.
    private var isPresentedModally: Bool {
        tabBarController == nil && presentingViewController?.presentedViewController === self
    }

    /// Dismisses this controller. Wired as the App Screens home's dismissal handler
    /// only while this controller is presented modally (see `viewWillAppear`), so the
    /// `isPresentedModally` guard is cheap belt-and-suspenders insurance against a
    /// stale invocation after the hosting relationship changed.
    private func dismissIfPresentedModally() {
        guard isPresentedModally else {
            os_log("openURL dismiss ignored: Hub is embedded, not presented modally", log: .hub, type: .info)
            return
        }
        dismiss(animated: true)
    }
}

/// Live presentation state a `HubHostingController` shares with its `HubView`.
/// `HubHostingController.viewWillAppear` publishes the dismissal handler here once
/// the hosting relationship is established; `HubView`/`HubContentView` observe it and
/// thread it into the App Screens home view. Publishing rides SwiftUI's normal diff
/// into `AppScreensExperienceRepresentable.updateUIViewController` — the same
/// non-disruptive path an inbox-badge update takes — so it never re-roots the tree or
/// reloads the web view.
final class HubPresentationState: ObservableObject {
    /// The Hub's dismissal handler: a real closure ONLY when the Hub is genuinely
    /// presented modally (drives the `openURL { dismiss: true }` teardown and the App
    /// Screens xmark, which installs iff this is non-`nil`), `nil` when embedded in a
    /// tab (no teardown, no close chrome).
    @Published var onDismissButtonPressed: (() -> Void)?
}
