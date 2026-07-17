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
import UIKit
import XCTest

@testable import RoverExperiences

/// Exercises the pre-iOS-26 inbox bar button's custom view directly via the
/// `ExperienceViewController.makeLegacyInboxView(_:)` seam. The seam has no runtime
/// `#available` gate, so the legacy (fallback) rendering is testable even when the
/// suite runs on an iOS 26 simulator — the iOS 26 path uses the native
/// `UIBarButtonItem.badge` instead and is not what these cover.
///
/// The fix under test: on iOS 18 the plain image `UIBarButtonItem` has no
/// `.badge` API, so the unread badge never rendered. The legacy view overlays a
/// hand-drawn badge label on the button glyph to restore parity.
@MainActor
final class ExperienceViewControllerInboxBadgeTests: XCTestCase {

    /// A numeric badge renders a label carrying that text, the button carries the
    /// item's accessibility identifier/label, and its accessibilityValue mirrors the
    /// badge (VoiceOver parity with the native iOS 26 badge).
    func testLegacyInboxViewShowsBadgeAndAccessibilityForNumericCount() {
        let item = AppScreensRootBarItem(
            systemImageName: "envelope",
            badgeText: "3",
            accessibilityLabel: "Inbox",
            accessibilityIdentifier: "rover.hub.inbox",
            action: {}
        )

        let view = ExperienceViewController.makeLegacyInboxView(item)

        let button = Self.firstButton(in: view)
        XCTAssertNotNil(button, "The legacy inbox view must contain a UIButton.")
        XCTAssertEqual(button?.accessibilityIdentifier, "rover.hub.inbox")
        XCTAssertEqual(button?.accessibilityLabel, "Inbox")
        XCTAssertEqual(button?.accessibilityValue, "3", "The badge count should be exposed to VoiceOver.")

        let badge = Self.firstBadgeLabel(in: view)
        XCTAssertNotNil(badge, "A numeric badge should render a badge label.")
        XCTAssertEqual(badge?.text, "3")
    }

    /// A non-numeric badge string (e.g. an overflow count) renders as text verbatim.
    func testLegacyInboxViewRendersNonNumericBadgeAsText() {
        let item = AppScreensRootBarItem(
            systemImageName: "envelope",
            badgeText: "99+",
            accessibilityIdentifier: "rover.hub.inbox",
            action: {}
        )

        let view = ExperienceViewController.makeLegacyInboxView(item)

        let badge = Self.firstBadgeLabel(in: view)
        XCTAssertEqual(badge?.text, "99+", "A non-numeric badge string should render verbatim.")
        XCTAssertEqual(
            Self.firstButton(in: view)?.accessibilityValue,
            "99+",
            "The text badge should be exposed to VoiceOver."
        )
    }

    /// A `nil` badge text renders no badge label and sets no accessibilityValue.
    func testLegacyInboxViewShowsNoBadgeWhenBadgeTextNil() {
        let item = AppScreensRootBarItem(
            systemImageName: "envelope",
            badgeText: nil,
            accessibilityIdentifier: "rover.hub.inbox",
            action: {}
        )

        let view = ExperienceViewController.makeLegacyInboxView(item)

        XCTAssertNil(Self.firstBadgeLabel(in: view), "No badge label should exist for a nil badge.")
        XCTAssertNil(
            Self.firstButton(in: view)?.accessibilityValue,
            "No accessibilityValue should be set when there is no badge."
        )
    }

    /// An empty badge string is treated the same as `nil`: no badge label at all.
    func testLegacyInboxViewShowsNoBadgeWhenBadgeTextEmpty() {
        let item = AppScreensRootBarItem(
            systemImageName: "envelope",
            badgeText: "",
            accessibilityIdentifier: "rover.hub.inbox",
            action: {}
        )

        let view = ExperienceViewController.makeLegacyInboxView(item)

        XCTAssertNil(Self.firstBadgeLabel(in: view), "No badge label should exist for an empty badge.")
    }

    /// Sending the button's action fires the item's closure.
    func testLegacyInboxViewButtonFiresItemAction() {
        var tapped = false
        let item = AppScreensRootBarItem(
            systemImageName: "envelope",
            badgeText: "3",
            accessibilityIdentifier: "rover.hub.inbox",
            action: { tapped = true }
        )

        let view = ExperienceViewController.makeLegacyInboxView(item)
        let button = Self.firstButton(in: view)
        XCTAssertNotNil(button)

        XCTAssertFalse(tapped)
        button?.sendActions(for: .touchUpInside)
        XCTAssertTrue(tapped, "Tapping the inbox button should invoke the item's action.")
    }

    // MARK: - Compatibility circle chrome

    /// The compatibility chrome is unconditional in the legacy view: a 40×40
    /// `.thinMaterial` circle (cornerRadius 20) sits behind the glyph, and the button
    /// glyph is tinted `.label` — the UIKit mirror of `CompatibleInboxToolbarButton`.
    func testLegacyInboxViewHasFortyByFortyThinMaterialCircleBehindGlyph() {
        let item = AppScreensRootBarItem(
            systemImageName: "envelope",
            badgeText: "3",
            accessibilityIdentifier: "rover.hub.inbox",
            action: {}
        )

        let view = ExperienceViewController.makeLegacyInboxView(item)
        view.setNeedsLayout()
        view.layoutIfNeeded()

        let effectView = Self.firstEffectView(in: view)
        XCTAssertNotNil(effectView, "The legacy inbox view must contain a UIVisualEffectView circle.")
        XCTAssertEqual(effectView?.bounds.size, CGSize(width: 40, height: 40), "The circle must be 40×40.")
        XCTAssertEqual(effectView?.layer.cornerRadius, 20, "The circle's cornerRadius must be 20 (a 40pt circle).")
        XCTAssertEqual(effectView?.clipsToBounds, true, "The material circle must clip to its rounded bounds.")

        XCTAssertEqual(
            Self.firstButton(in: view)?.tintColor,
            .label,
            "The glyph must be tinted .label (the equivalent of .tint(.primary))."
        )
    }

    /// The badge label must render above the circle in z-order (it is the last
    /// subview added to the container), so it is never occluded by the material.
    func testLegacyInboxViewBadgeIsAboveCircleInZOrder() {
        let item = AppScreensRootBarItem(
            systemImageName: "envelope",
            badgeText: "3",
            accessibilityIdentifier: "rover.hub.inbox",
            action: {}
        )

        let container = ExperienceViewController.makeLegacyInboxView(item)

        guard let badge = Self.firstBadgeLabel(in: container) else {
            return XCTFail("A numeric badge should render a badge label.")
        }
        guard let effectView = Self.firstEffectView(in: container) else {
            return XCTFail("The legacy inbox view should contain the circle effect view.")
        }
        XCTAssertEqual(badge.text, "3")

        // Both live directly under the container; the badge must come after the
        // effect view's ancestor (the shadow wrapper) so it draws on top.
        let subviews = container.subviews
        guard let badgeIndex = subviews.firstIndex(of: badge) else {
            return XCTFail("The badge should be a direct subview of the container.")
        }
        let effectAncestorIndex = subviews.firstIndex { $0 == effectView || $0.subviews.contains(effectView) }
        guard let circleIndex = effectAncestorIndex else {
            return XCTFail("The circle should live under a direct subview of the container.")
        }
        XCTAssertGreaterThan(badgeIndex, circleIndex, "The badge must be above the circle in z-order.")
    }

    // MARK: - Helpers

    /// Depth-first search for the first `UIVisualEffectView` — the compatibility
    /// material circle.
    private static func firstEffectView(in view: UIView) -> UIVisualEffectView? {
        if let effectView = view as? UIVisualEffectView {
            return effectView
        }
        for subview in view.subviews {
            if let effectView = firstEffectView(in: subview) {
                return effectView
            }
        }
        return nil
    }

    /// Depth-first search for the first `UIButton` in a view hierarchy.
    private static func firstButton(in view: UIView) -> UIButton? {
        if let button = view as? UIButton {
            return button
        }
        for subview in view.subviews {
            if let button = firstButton(in: subview) {
                return button
            }
        }
        return nil
    }

    /// Depth-first search for the first `UILabel` carrying non-empty text — the
    /// badge. The button glyph is an image (no label), so any text label found is the
    /// badge.
    private static func firstBadgeLabel(in view: UIView) -> UILabel? {
        if let label = view as? UILabel, let text = label.text, !text.isEmpty {
            return label
        }
        for subview in view.subviews {
            if let label = firstBadgeLabel(in: subview) {
                return label
            }
        }
        return nil
    }
}
