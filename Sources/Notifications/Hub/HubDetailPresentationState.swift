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
import os.log

/// Live presentation state a standalone detail hosting controller
/// (`ShowPostHostingController`, `ShowConversationHostingController`) shares with its
/// root SwiftUI view, mirroring `HubPresentationState` for the Hub.
///
/// These controllers are normally presented modally by `PresentViewAction` when no
/// Hub deep link is configured, but an integrator may also push one. Whether there
/// is anything to dismiss is only knowable once the hosting relationship exists, so
/// `viewWillAppear` calls `update(for:)` and the root view reads the published
/// handler into the `\.hubDismissThenOpen` environment. The SwiftUI `\.isPresented`
/// environment is not used for this: it is `true` for pushed views too.
@MainActor
final class HubDetailPresentationState: ObservableObject {
    /// Dismisses the presentation THEN opens the URL from the dismissal completion.
    /// A real closure only while the owning controller is presented modally in its
    /// own right; `nil` otherwise, so links open in place.
    @Published var dismissThenOpen: ((URL) -> Void)?

    /// Re-evaluates the hosting relationship of `controller` and publishes the
    /// handler accordingly. Publishes only on an actual change, so re-appearances do
    /// not re-fire a fresh closure through SwiftUI.
    func update(for controller: UIViewController) {
        let shouldDismiss = Self.isPresentedModally(controller)
        guard shouldDismiss != (dismissThenOpen != nil) else {
            return
        }
        dismissThenOpen =
            shouldDismiss
            ? { [weak controller] url in
                // Dismiss via the presenter so a sheet stacked on top of the detail
                // (an image viewer, a browser) goes with it, then open — opening
                // while the dismissal is still animating is exactly what leaves the
                // deep link's destination behind the modal.
                guard let presenter = controller?.presentingViewController else {
                    // Hosting relationship changed since `viewWillAppear`: never lose the URL.
                    os_log("dismiss-then-open: no presentingViewController; opening in place", log: .hub, type: .info)
                    UIApplication.shared.openLoggingHubFailure(url)
                    return
                }
                presenter.dismiss(animated: true) { UIApplication.shared.openLoggingHubFailure(url) }
            } : nil
    }

    /// `true` only when `controller` is itself the modally presented controller — not
    /// embedded in a tab (even inside a presented tab bar), and not pushed. The one
    /// definition of the rule: `HubHostingController` and
    /// `CommunicationHubHostingController` call it for their own dismissal gating. The
    /// `tabBarController == nil` guard rejects an embedded-in-a-tab controller (even one
    /// inside a presented tab bar), and `presentedViewController === controller` confirms
    /// it is itself the presented one rather than, say, the root of a presented
    /// navigation controller.
    static func isPresentedModally(_ controller: UIViewController) -> Bool {
        controller.tabBarController == nil && controller.presentingViewController?.presentedViewController === controller
    }
}
