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

import UIKit
import XCTest

@testable import RoverExperiences

/// When a host app themes `UINavigationBar.appearance()` globally, every
/// Hub screen must still render with the SDK's own (transparent) styling. Bar-instance
/// resets alone don't survive re-presentation or reach pushed destinations, so
/// `NavBarAppearanceReset.Controller` must also pin appearances on the enclosing
/// screen's `UINavigationItem`, which UIKit resolves ahead of both the global
/// appearance proxy and bar-instance state.
@MainActor
final class NavBarAppearanceResetTests: XCTestCase {

    private struct Stack {
        let navigationController: UINavigationController
        let screen: UIViewController
        let reset: NavBarAppearanceReset.Controller
    }

    /// Builds nav stack: UINavigationController → screen VC → (child) reset controller,
    /// mirroring how the `.resetNavBarAppearance()` background representable is parented
    /// beneath a SwiftUI destination's hosting controller.
    private func makeStack(
        style: NavBarAppearanceReset.Style = .transparent
    ) -> Stack {
        let screen = UIViewController()
        let reset = NavBarAppearanceReset.Controller(style: style)
        screen.addChild(reset)
        screen.view.addSubview(reset.view)
        reset.didMove(toParent: screen)
        let navigationController = UINavigationController(rootViewController: screen)
        return Stack(navigationController: navigationController, screen: screen, reset: reset)
    }

    private func triggerAppearance(of controller: UIViewController) {
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
    }

    func testPinsTransparentAppearanceOnEnclosingNavigationItem() {
        let stack = makeStack()
        let screen = stack.screen

        XCTAssertNil(screen.navigationItem.standardAppearance)

        triggerAppearance(of: stack.reset)

        for (name, appearance) in [
            ("standardAppearance", screen.navigationItem.standardAppearance),
            ("scrollEdgeAppearance", screen.navigationItem.scrollEdgeAppearance),
            ("compactAppearance", screen.navigationItem.compactAppearance),
            ("compactScrollEdgeAppearance", screen.navigationItem.compactScrollEdgeAppearance)
        ] {
            guard let appearance else {
                XCTFail("\(name) was not pinned on the enclosing navigation item")
                continue
            }
            XCTAssertNil(appearance.backgroundColor, "\(name) should be transparent")
            XCTAssertNil(
                appearance.backgroundEffect,
                "\(name) should have no background effect (transparent configuration)"
            )
        }
    }

    func testPinsAppearanceOnIntermediateAncestorNotItself() {
        // The reset controller is a grandchild of the screen: its own navigationItem
        // is irrelevant; the item that drives the bar belongs to the ancestor that is
        // the navigation controller's direct child.
        let stack = makeStack()

        triggerAppearance(of: stack.reset)

        XCTAssertNotNil(stack.screen.navigationItem.standardAppearance)
        XCTAssertNil(stack.reset.navigationItem.standardAppearance)
    }

    func testResetsBarInstanceStateSetByHostProxyValues() {
        let stack = makeStack()
        let bar = stack.navigationController.navigationBar

        // Simulate a host app's global-proxy styling landing on the bar instance.
        let hostile = UINavigationBarAppearance()
        hostile.configureWithDefaultBackground()
        hostile.backgroundColor = .cyan
        bar.standardAppearance = hostile
        bar.scrollEdgeAppearance = hostile
        bar.backgroundColor = .red
        bar.isTranslucent = false
        bar.prefersLargeTitles = true
        bar.titleTextAttributes = [.foregroundColor: UIColor.red]

        triggerAppearance(of: stack.reset)

        XCTAssertNil(bar.standardAppearance.backgroundColor)
        XCTAssertNil(bar.scrollEdgeAppearance?.backgroundColor)
        XCTAssertNil(bar.backgroundColor)
        XCTAssertTrue(bar.isTranslucent)
        XCTAssertFalse(bar.prefersLargeTitles)
        XCTAssertNil(bar.titleTextAttributes)
    }

    func testDoesNothingOutsideANavigationController() {
        // Hub surfaces without a navigation controller (defensive path) must not crash
        // and must not touch anything.
        let reset = NavBarAppearanceReset.Controller(style: .transparent)

        triggerAppearance(of: reset)

        XCTAssertNil(reset.navigationItem.standardAppearance)
    }

    func testSystemScrolledBackgroundStylePinsAllFourSlots() {
        // Content screens (Messages, post and conversation detail) keep the bar
        // invisible while the content is at rest at the top, but show the system
        // background once content scrolls underneath, so bar text stays legible.
        let stack = makeStack(style: .systemScrolledBackground)
        let screen = stack.screen

        triggerAppearance(of: stack.reset)

        XCTAssertNotNil(screen.navigationItem.standardAppearance)
        XCTAssertNotNil(screen.navigationItem.scrollEdgeAppearance)
        XCTAssertNotNil(screen.navigationItem.compactAppearance)
        XCTAssertNotNil(screen.navigationItem.compactScrollEdgeAppearance)
        XCTAssertNil(
            screen.navigationItem.scrollEdgeAppearance?.backgroundColor,
            "at-rest state should stay transparent"
        )
        XCTAssertNil(
            screen.navigationItem.scrollEdgeAppearance?.backgroundEffect,
            "at-rest state should stay transparent"
        )
    }

    // On the iOS 26 runtime, `configureWithDefaultBackground()` and
    // `configureWithTransparentBackground()` produce appearances that are
    // indistinguishable through public API (probed properties all nil, and `isEqual`
    // returns true) — the difference lives in private rendering state. And
    // `UINavigationItem` copies appearances on assignment, so object identity can't
    // be observed after pinning either. The two tests below therefore assert the
    // factory's structure before assignment; the rendering difference itself is
    // verified visually on the simulator.

    func testSystemScrolledBackgroundStyleBuildsDistinctScrolledAndAtRestConfigurations() {
        let (scrolled, atRest) = NavBarAppearanceReset.Style.systemScrolledBackground.makeAppearances()

        XCTAssertNotIdentical(scrolled, atRest, "scrolled state should hold its own configuration")
        XCTAssertNil(atRest.backgroundColor)
        XCTAssertNil(atRest.backgroundEffect)
    }

    func testTransparentStyleBuildsTheSameConfigurationForBothStates() {
        let (scrolled, atRest) = NavBarAppearanceReset.Style.transparent.makeAppearances()

        XCTAssertIdentical(scrolled, atRest, "both states should share the transparent configuration")
        XCTAssertNil(atRest.backgroundColor)
        XCTAssertNil(atRest.backgroundEffect)
    }
}
