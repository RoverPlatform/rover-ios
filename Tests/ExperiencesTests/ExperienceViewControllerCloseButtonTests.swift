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

/// Exercises the App Screens root bar buttons: `ExperienceViewController` installs
/// the modal xmark close item only when a presenter supplied `onDismissButtonPressed`,
/// and places it opposite the host inbox item when both are present — close on the
/// leading edge, inbox on the trailing edge — so neither is lost. A close item alone
/// stays on the trailing edge; a `nil` handler with no inbox item (the embedded case)
/// leaves the bar untouched. A dynamic inbox toggle must slide the close item between
/// edges without stranding a stale button.
///
/// These drive `installAppScreensRootBarButtons(on:)` directly with a headless host,
/// mirroring `AppScreensNavigatorPopToRootTests`' approach of building real UIKit
/// objects without a live presentation context. The full `loadExperience` path
/// resolves `Router`/`AppScreensNavigator` from `Rover.shared`, so exercising it
/// end-to-end is manual-verification territory; the wiring under test is the
/// install seam.
@MainActor
final class ExperienceViewControllerCloseButtonTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // `ExperienceViewController()` resolves `ExperienceStore` from `Rover.shared`
        // at construction, so boot a minimal container that registers a stub. Reset
        // first in case an earlier test left a shared instance behind.
        Rover.deinitialize()
        Rover.initialize(assemblers: [CloseButtonTestAssembler()])
    }

    override func tearDown() {
        Rover.deinitialize()
        super.tearDown()
    }

    /// Handler set → an xmark close item is installed on the given root host, and
    /// firing its action invokes the handler (the closure body performs dismissal).
    func testCloseButtonInstalledAndInvokesHandlerWhenSet() {
        let viewController = ExperienceViewController()
        var dismissed = false
        viewController.onDismissButtonPressed = { dismissed = true }

        let rootHost = UIViewController()
        viewController.installAppScreensRootBarButtons(on: rootHost)

        let item = rootHost.navigationItem.rightBarButtonItem
        XCTAssertNotNil(item, "A close item should be installed when a handler is set.")
        XCTAssertNotNil(item?.image, "The close item should carry the xmark image.")

        // Fire the item's action; the handler should run.
        XCTAssertFalse(dismissed)
        if let target = item?.target, let action = item?.action {
            _ = target.perform(action)
        } else {
            XCTFail("The close item should be wired to a target/action.")
        }
        XCTAssertTrue(dismissed, "Tapping the close item should invoke onDismissButtonPressed.")
    }

    /// Handler nil (the embed case) → no close item is installed; the host's bar is
    /// left untouched. Regression guard for an `ExperienceView` embedded in a
    /// developer's own sheet, which must not gain an unwanted xmark.
    func testNoCloseButtonWhenHandlerNil() {
        let viewController = ExperienceViewController()
        XCTAssertNil(viewController.onDismissButtonPressed)

        let rootHost = UIViewController()
        viewController.installAppScreensRootBarButtons(on: rootHost)

        XCTAssertNil(
            rootHost.navigationItem.rightBarButtonItem,
            "No close item should be installed when no dismissal handler was supplied."
        )
    }

    /// Root-only: the install mutates only the host it is handed. A separate host
    /// (standing in for a pushed detail, which the real flow never passes here) keeps
    /// a clean bar.
    func testCloseButtonInstalledOnlyOnGivenHost() {
        let viewController = ExperienceViewController()
        viewController.onDismissButtonPressed = {}

        let rootHost = UIViewController()
        let pushedHost = UIViewController()
        viewController.installAppScreensRootBarButtons(on: rootHost)

        XCTAssertNotNil(rootHost.navigationItem.rightBarButtonItem)
        XCTAssertNil(
            pushedHost.navigationItem.rightBarButtonItem,
            "Only the host passed to the install should receive the close item."
        )
    }

    /// Both set (a presented Hub whose home view enables the inbox) → the two coexist
    /// on opposite edges: the inbox takes the trailing slot and the close item moves
    /// to the leading slot, so neither is lost.
    func testInboxAndCloseCoexistOnOppositeEdgesWhenBothSet() {
        let viewController = ExperienceViewController()
        viewController.onDismissButtonPressed = {}
        viewController.setAppScreensRootBarItem(
            AppScreensRootBarItem(
                systemImageName: "envelope",
                accessibilityIdentifier: "rover.hub.inbox",
                action: {}
            )
        )

        let rootHost = UIViewController()
        viewController.installAppScreensRootBarButtons(on: rootHost)

        XCTAssertEqual(
            rootHost.navigationItem.rightBarButtonItem?.accessibilityIdentifier,
            "rover.hub.inbox",
            "The inbox item should take the trailing slot."
        )
        let leading = rootHost.navigationItem.leftBarButtonItem
        XCTAssertNotNil(leading, "The close item should take the leading slot when the inbox is present.")
        XCTAssertNil(
            leading?.accessibilityIdentifier,
            "The leading item should be the close item, not the inbox."
        )
        XCTAssertNotNil(leading?.image, "The leading close item should carry the xmark image.")
    }

    /// An inbox item arriving *after* the close item was installed (e.g. a config sync
    /// enabling the inbox once the presented Hub is already up) must move the close
    /// item to the leading edge — not drop it or stack on it. Regression guard for the
    /// two occupants clobbering each other across a dynamic change.
    func testInboxTogglingOnAfterCloseInstalledMovesCloseToLeadingEdge() {
        let viewController = ExperienceViewController()
        viewController.onDismissButtonPressed = {}

        let rootHost = UIViewController()
        viewController.installAppScreensRootBarButtons(on: rootHost)
        XCTAssertNotNil(
            rootHost.navigationItem.rightBarButtonItem,
            "Before the inbox toggles on, the close item holds the trailing slot alone."
        )
        XCTAssertNil(
            rootHost.navigationItem.leftBarButtonItem,
            "With no inbox, the leading slot stays clear."
        )

        viewController.setAppScreensRootBarItem(
            AppScreensRootBarItem(
                systemImageName: "envelope",
                accessibilityIdentifier: "rover.hub.inbox",
                action: {}
            )
        )
        viewController.installAppScreensRootBarButtons(on: rootHost)

        XCTAssertEqual(
            rootHost.navigationItem.rightBarButtonItem?.accessibilityIdentifier,
            "rover.hub.inbox",
            "A late inbox item should take the trailing slot."
        )
        XCTAssertNotNil(
            rootHost.navigationItem.leftBarButtonItem,
            "The close item should move to the leading slot, not be dropped."
        )
    }

    /// The inverse of the toggle-on case: an inbox item disappearing (config sync
    /// disabling it) must move the close item back from the leading edge to the
    /// trailing slot and clear the leading slot — no stale leading button.
    func testInboxTogglingOffMovesCloseBackToTrailingEdge() {
        let viewController = ExperienceViewController()
        viewController.onDismissButtonPressed = {}
        viewController.setAppScreensRootBarItem(
            AppScreensRootBarItem(
                systemImageName: "envelope",
                accessibilityIdentifier: "rover.hub.inbox",
                action: {}
            )
        )

        let rootHost = UIViewController()
        viewController.installAppScreensRootBarButtons(on: rootHost)
        XCTAssertNotNil(rootHost.navigationItem.leftBarButtonItem, "Both present: close is on the leading edge.")

        viewController.setAppScreensRootBarItem(nil)
        viewController.installAppScreensRootBarButtons(on: rootHost)

        XCTAssertNil(
            rootHost.navigationItem.leftBarButtonItem,
            "With the inbox gone, the leading slot must be cleared."
        )
        XCTAssertNotNil(
            rootHost.navigationItem.rightBarButtonItem,
            "The close item should return to the trailing slot."
        )
    }

    /// The exact regression this fix guards: an EMBEDDED Hub (no dismissal handler —
    /// `HubHostingController` withholds it when the Hub is not presented modally) whose
    /// home view enables the inbox must show ONLY the inbox on the trailing edge and NO
    /// close item on the leading edge. Before the fix, `HubHostingController` wired a
    /// non-`nil` handler unconditionally, so the embedded case stranded a dead xmark on
    /// the leading edge once the inbox took the trailing slot.
    func testEmbeddedHubWithInboxShowsInboxOnlyAndNoLeadingCloseItem() {
        let viewController = ExperienceViewController()
        // Embedded: no dismissal handler is supplied.
        XCTAssertNil(viewController.onDismissButtonPressed)
        viewController.setAppScreensRootBarItem(
            AppScreensRootBarItem(
                systemImageName: "envelope",
                accessibilityIdentifier: "rover.hub.inbox",
                action: {}
            )
        )

        let rootHost = UIViewController()
        viewController.installAppScreensRootBarButtons(on: rootHost)

        XCTAssertEqual(
            rootHost.navigationItem.rightBarButtonItem?.accessibilityIdentifier,
            "rover.hub.inbox",
            "The inbox item should hold the trailing slot."
        )
        XCTAssertNil(
            rootHost.navigationItem.leftBarButtonItem,
            "No dead close item may be stranded on the leading edge for an embedded Hub."
        )
    }

    /// The dismissal handler is the single gate for the close item. Flipping it via
    /// `setOnDismissButtonPressed` — the live path a modally-presented Hub takes once
    /// `HubHostingController.viewWillAppear` resolves the presentation and publishes
    /// the real closure — installs the xmark when a handler is present and withdraws it
    /// when cleared. (Here the root host is `nil`, so the setter just stores the
    /// handler and the install is driven directly, mirroring the headless seam.)
    func testDismissHandlerGatesCloseItemThroughLiveSetter() {
        let viewController = ExperienceViewController()

        // Embedded default: no handler → no close item.
        let rootHost = UIViewController()
        viewController.installAppScreensRootBarButtons(on: rootHost)
        XCTAssertNil(
            rootHost.navigationItem.rightBarButtonItem,
            "With no dismissal handler the embedded Hub shows no close item."
        )

        // Presentation resolved: a real handler arrives → the close item installs.
        viewController.setOnDismissButtonPressed({})
        viewController.installAppScreensRootBarButtons(on: rootHost)
        XCTAssertNotNil(
            rootHost.navigationItem.rightBarButtonItem?.image,
            "A supplied dismissal handler installs the xmark close item."
        )

        // Handler cleared again → the close item is withdrawn.
        viewController.setOnDismissButtonPressed(nil)
        viewController.installAppScreensRootBarButtons(on: rootHost)
        XCTAssertNil(
            rootHost.navigationItem.rightBarButtonItem,
            "Clearing the dismissal handler withdraws the close item."
        )
    }
}

/// Minimal assembler registering just the `ExperienceStore` that
/// `ExperienceViewController` resolves at construction time.
private struct CloseButtonTestAssembler: Assembler {
    func assemble(container: Container) {
        container.register(ExperienceStore.self) { _ in StubExperienceStore() }
    }
}

/// No-op `ExperienceStore`; the close-button seam never fetches, so the callbacks
/// are unused.
private final class StubExperienceStore: ExperienceStore {
    func fetchExperience(
        for url: URL,
        completionHandler: @escaping (Result<LoadedExperience, Failure>) -> Void
    ) {}

    func revalidateExperience(
        for url: URL,
        completionHandler: @escaping (RevalidationResult) -> Void
    ) {}
}
