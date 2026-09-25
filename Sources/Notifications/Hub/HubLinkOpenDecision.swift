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

import Foundation
import RoverFoundation
import RoverUI

/// What a link tapped inside a Post or a Conversation should do.
///
/// A modally presented Hub (or a standalone Post/Conversation presented modally
/// because no Hub deep link is configured) sits on top of the host app. A deep link
/// into that same app then lands *behind* the modal, where the user cannot see it
/// (SDK-425). The fix is to dismiss the modal first and open the link from its
/// dismissal completion — but only for links that would actually land behind it.
enum HubLinkOpenDecision: Equatable {
    /// Open the URL where the user is: a Rover link the SDK routes itself, a
    /// mailto/tel/sms/other-app scheme that leaves the app anyway, or any link on a
    /// surface that has nothing to dismiss (embedded in a tab, or pushed).
    case openInPlace

    /// An http/https link. Callers that already show an in-app browser keep doing so.
    case presentInAppBrowser

    /// A deep link into this app from a modally presented surface: dismiss the
    /// presentation, then open the URL once the dismissal has completed.
    case dismissThenOpen
}

/// Classifies a tapped link. Both inputs that touch process state — the Rover router
/// and the host app's `Info.plist` — are injected so the rule itself is a pure
/// function the tests can drive.
struct HubLinkOpenClassifier {
    /// Whether the URL is Rover's (a `rv-…://posts/…` link, an experience link, and so
    /// on), answered from the router's configured schemes and domains rather than by
    /// building the action — `Router.action(for:)` would materialize an experience
    /// controller and a fetch just to say yes. Such links are opened as normal: the
    /// SDK's own routing already knows how to present their destination over the
    /// current surface, and dismissing the Hub first would undo the navigation it queues.
    ///
    /// A deliberate consequence: the whole Rover scheme counts as ours, routed or not.
    /// `action(for:)` asked "does a handler claim this?"; `isDeepLink` asks "is this
    /// scheme ours?", and the two part company only on an unrouted Rover URL such as
    /// `rv-myapp://newthing/1`, which now opens in place instead of dismissing first. If
    /// nothing handles it, that is the better outcome — the old path tore the Hub down
    /// and then nothing happened. An integrator that routes its own `rv-` links as a
    /// fallback would see that destination land behind the modal; none is known to.
    let isRoverLink: (URL) -> Bool

    /// The URL schemes the host app registers for itself (`CFBundleURLTypes`),
    /// lowercased. Only a link on one of these schemes can be delivered to this app,
    /// and so only such a link can end up behind a modal presentation. This also
    /// keeps `mailto:`, `tel:`, `sms:` and other apps' schemes on the open-in-place
    /// path without a hand-maintained list.
    let hostAppURLSchemes: Set<String>

    /// The production classifier: the Rover router as registered on `Rover.shared`,
    /// and the main bundle's URL schemes. The router is resolved per call so a
    /// classifier built before `Rover.initialize` still answers correctly later, and
    /// is asked through `RouterLinkClassifying`, which answers from its configured
    /// schemes and domains without materializing an action.
    static var live: HubLinkOpenClassifier {
        HubLinkOpenClassifier(
            isRoverLink: { url in
                guard let router = Rover.shared.resolve(Router.self) as? RouterLinkClassifying else {
                    return false
                }
                return router.isDeepLink(url: url) || router.isUniversalLink(url: url)
            },
            hostAppURLSchemes: hostAppURLSchemes(from: .main)
        )
    }

    /// Reads the URL schemes an app registers for itself from its `Info.plist`.
    static func hostAppURLSchemes(from bundle: Bundle) -> Set<String> {
        guard let urlTypes = bundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return []
        }
        let schemes = urlTypes.flatMap { urlType -> [String] in
            (urlType["CFBundleURLSchemes"] as? [String]) ?? []
        }
        return Set(schemes.map { $0.lowercased() })
    }

    /// - Parameter canDismiss: whether the surface showing the link has a
    ///   dismiss-then-open handler, i.e. is presented modally in its own right.
    func decide(_ url: URL, canDismiss: Bool) -> HubLinkOpenDecision {
        guard let scheme = url.scheme?.lowercased() else {
            return .openInPlace
        }

        // Web links first, and without consulting the router: a Rover universal link
        // is still a web page as far as the in-app browser is concerned.
        if scheme == "http" || scheme == "https" {
            return .presentInAppBrowser
        }

        // Nothing to dismiss, or not a link this app would be handed: open in place
        // whatever the router would say, so an embedded or pushed surface never asks it.
        guard canDismiss, hostAppURLSchemes.contains(scheme) else {
            return .openInPlace
        }

        // Only now is the router's answer decisive: a Rover deep link (whose scheme the
        // host app registers too) is routed by the SDK over the current surface.
        if isRoverLink(url) {
            return .openInPlace
        }

        return .dismissThenOpen
    }
}
