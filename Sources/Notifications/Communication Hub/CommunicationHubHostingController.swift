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
public class CommunicationHubHostingController: UIHostingController<CommunicationHubView> {

    /// Presentation state shared with the hosted `CommunicationHubView`. Starts with a
    /// `nil` dismissal handler (the embedded default) and is published as a real
    /// dismissal only once `viewWillAppear` confirms this controller is genuinely
    /// presented modally — see `viewWillAppear`.
    ///
    /// This mirrors `HubHostingController`'s dismissal wiring rather than sharing it via
    /// a common base class. Subclassing `HubHostingController` would change this
    /// controller's public `UIHostingController<CommunicationHubView>` specialization
    /// (customers may name that exact type), so — as a soon-to-be-deprecated
    /// compatibility shim — it deliberately re-implements the behavior here. Keep the two
    /// in sync until this shim is retired.
    private let presentation = HubPresentationState()

    public init(
        navigator: CommunicationHubNavigator? = nil,
        title: String? = nil,
        accentColor: Color = .accentColor,
        navigationBarBackgroundColor: Color? = nil,
        navigationBarColorScheme: ColorScheme? = nil
    ) {
        // Seed with a placeholder so `super.init` has a root view, then immediately
        // re-root with a `CommunicationHubView` sharing this controller's `presentation`
        // state. Both happen at init, BEFORE the view first renders, so — unlike
        // re-rooting later in the lifecycle — no re-render or App Screens web-view reload
        // results. The dismissal handler itself is threaded LATER, at `viewWillAppear`,
        // once the hosting relationship (presented vs. embedded) is known.
        super.init(rootView: CommunicationHubView())
        rootView = CommunicationHubView(presentation: presentation)
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // The hosting relationship is only established once this controller is appearing
        // (never at init/`viewDidLoad`), so decide HERE whether the Hub is a genuine
        // modal presentation, then publish the dismissal handler accordingly: a real
        // closure when presented, `nil` when embedded. That single handler is the whole
        // gate — the App Screens home installs the xmark close item AND honors an
        // `openURL { dismiss: true }` teardown iff it is non-`nil`, so an embedded
        // (tabbed/pushed) Hub gets neither a dead xmark nor a stray dismiss.
        //
        // Publishing rides `presentation` → the existing non-disruptive live update path,
        // so the flip never re-roots the SwiftUI tree or reloads the App Screens web
        // view. Only publish on an actual change (a fresh closure would otherwise re-fire
        // on every re-appearance).
        let shouldBeDismissable = isPresentedModally
        guard shouldBeDismissable != (presentation.onDismissButtonPressed != nil) else {
            return
        }
        presentation.onDismissButtonPressed =
            shouldBeDismissable ? { [weak self] in self?.dismissIfPresentedModally() } : nil

        // The completion-capable dismiss-then-open handler, mirrored from
        // `HubHostingController`: flips alongside `onDismissButtonPressed` above (same
        // `shouldBeDismissable` gate, so both are always in sync). It serves the App
        // Screens `openURL { dismiss }` bridge and, via `\.hubDismissThenOpen`, a
        // host-app deep link tapped in a Post or Conversation reply (SDK-425). `[weak
        // self]` is MANDATORY: this closure lives in the process-wide
        // `AppScreensDriver`'s `openHandlersByToken` registry, cleared only when the
        // owning flow box's `deinit` calls `release`; a strong `self` would keep this
        // controller alive past that point and deadlock teardown.
        presentation.onOpenExternalURL =
            shouldBeDismissable
            ? { [weak self] url, dismiss in
                guard let self else { return }
                guard dismiss else {
                    UIApplication.shared.openLoggingHubFailure(url)
                    return
                }
                // Dismiss the whole Hub (and its entire presented sheet chain) via the
                // presenter, then open. `self.dismiss` alone would, with stacked sheets,
                // dismiss only the innermost sheet and leave the Hub up.
                guard let presenter = self.presentingViewController else {
                    // Hub already gone / hosting relationship changed — never lose the URL.
                    os_log("openURL dismiss: no presentingViewController; opening in place", log: .hub, type: .info)
                    UIApplication.shared.openLoggingHubFailure(url)
                    return
                }
                presenter.dismiss(animated: true) { UIApplication.shared.openLoggingHubFailure(url) }
            } : nil
    }

    /// `true` only when this controller is actually presented modally in its own right —
    /// not when it is embedded (in a tab, or pushed). The rule itself lives in
    /// `HubDetailPresentationState.isPresentedModally(_:)`, shared with `HubHostingController`
    /// and the standalone detail controllers.
    private var isPresentedModally: Bool {
        HubDetailPresentationState.isPresentedModally(self)
    }

    /// Dismisses this controller. Wired as the App Screens home's dismissal handler only
    /// while this controller is presented modally (see `viewWillAppear`), so the
    /// `isPresentedModally` guard is cheap belt-and-suspenders insurance against a stale
    /// invocation after the hosting relationship changed.
    private func dismissIfPresentedModally() {
        guard isPresentedModally else {
            os_log("openURL dismiss ignored: Hub is embedded, not presented modally", log: .hub, type: .info)
            return
        }
        dismiss(animated: true)
    }
}
