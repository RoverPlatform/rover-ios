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

/// Exercises the explicit App Screens close affordance: `ExperienceViewController`
/// installs an xmark close item on the App Screens ROOT host only when a presenter
/// supplied `onDismissButtonPressed`, and the item's action invokes that handler.
/// A `nil` handler (the embedded case) must leave the host's bar untouched.
///
/// These drive `installAppScreensCloseButton(on:)` directly with a headless host,
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
        viewController.installAppScreensCloseButton(on: rootHost)

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
        viewController.installAppScreensCloseButton(on: rootHost)

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
        viewController.installAppScreensCloseButton(on: rootHost)

        XCTAssertNotNil(rootHost.navigationItem.rightBarButtonItem)
        XCTAssertNil(
            pushedHost.navigationItem.rightBarButtonItem,
            "Only the host passed to the install should receive the close item."
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
