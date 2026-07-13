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

/// A single native bar button item that the host (e.g. the Hub) can ask the App
/// Screens flow to install on the ROOT screen of a V3 experience only. Pushed
/// screens never carry it — `navigationItem.rightBarButtonItem` lives on the root
/// host view controller, so pushing hides it and popping restores it for free.
///
/// It is rendered as a standard image `UIBarButtonItem` (which the iOS 26
/// navigation bar draws as liquid glass) with an optional native badge. It is not
/// part of the web/document contract: it is a purely native affordance supplied by
/// the embedding host.
///
/// Why this hand-rolled pass-through exists at all: in a SwiftUI world the host
/// would simply contribute a `ToolbarItem` and let the embedded content's
/// navigation merge it (that is exactly how the Hub's V2 document home view gets
/// its inbox button). App Screens can't use that system because its chrome is the
/// child `UINavigationController` inside `ExperienceViewController` — a deliberate
/// trade: the V3 session model needs web views that outlive screens (warm reuse,
/// prewarm attach, pop-without-teardown) and frame-precise reveal/transition
/// control, which SwiftUI's representable lifecycle and `NavigationStack` don't
/// offer. The SwiftUI toolbar therefore stays hidden around a V3 experience (its
/// visible bar would also stack a second safe-area inset on top of the page's own
/// `env()` padding), and hosts inject root-screen actions through this type
/// instead. This is the embedding-seam tax of the UIKit-core decision; if SwiftUI
/// ever gains first-class re-parenting/transition control for represented views,
/// revisit.
///
/// `package` (not public): cross-module surface for `RoverNotifications` (the Hub)
/// only, following the `ExperienceURLClassifier` precedent — no public API change.
package struct AppScreensRootBarItem {
    /// SF Symbol name for the button image (e.g. `"envelope"`).
    package let systemImageName: String

    /// Text for the native badge (e.g. an unread count `"23"`). `nil`/empty hides
    /// the badge. A purely numeric string renders as a count badge; any other
    /// string renders as a text badge.
    package let badgeText: String?

    /// Accessibility label for VoiceOver / UI tests. Defaults to `nil`.
    package let accessibilityLabel: String?

    /// Accessibility identifier for deterministic UI-test matching. Defaults to `nil`.
    package let accessibilityIdentifier: String?

    /// Run when the item is tapped.
    package let action: () -> Void

    package init(
        systemImageName: String,
        badgeText: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImageName = systemImageName
        self.badgeText = badgeText
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }
}
