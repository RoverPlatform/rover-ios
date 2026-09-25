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

@testable import RoverNotifications

/// The Hub's close-affordance contract: the close button appears exactly when a dismissal
/// handler is supplied — by `HubHostingController`'s modal detection on the UIKit path, or
/// by the integrator through `HubView(onDismissButtonPressed:)` on the SwiftUI path. The
/// SDK never guesses from the SwiftUI environment (`\.isPresented` is true for pushed
/// views too, so an environment fallback showed a close button that popped — SDK-364).
@MainActor
final class HubDismissHandlerTests: XCTestCase {

    func testBareHubViewCarriesNoDismissHandler() {
        let hubView = HubView()
        XCTAssertNil(hubView.presentation.onDismissButtonPressed)
    }

    func testIntegratorSuppliedHandlerIsThreadedIntoThePresentationState() {
        var dismissed = false
        let hubView = HubView(onDismissButtonPressed: { dismissed = true })

        let handler = hubView.presentation.onDismissButtonPressed
        XCTAssertNotNil(handler)
        handler?()
        XCTAssertTrue(dismissed)
    }

    func testExplicitNilMatchesTheBareInitializer() {
        let hubView = HubView(onDismissButtonPressed: nil)
        XCTAssertNil(hubView.presentation.onDismissButtonPressed)
    }

    func testCommunicationHubShimMirrorsTheIntegratorHandler() {
        var dismissed = false
        let shim = CommunicationHubView(onDismissButtonPressed: { dismissed = true })

        let handler = shim.presentation.onDismissButtonPressed
        XCTAssertNotNil(handler)
        handler?()
        XCTAssertTrue(dismissed)
    }

    // MARK: - Standalone Post / Conversation presentation (SDK-425)

    /// The standalone detail controllers apply the same modal rule as the Hub: a
    /// dismiss-then-open handler exists only while the controller is itself the
    /// presented one. A controller that is merely instantiated, pushed, or embedded
    /// in a tab publishes `nil`, so links open in place.

    func testDetailPresentationStartsWithNoHandler() {
        XCTAssertNil(HubDetailPresentationState().dismissThenOpen)
    }

    func testUnpresentedControllerPublishesNoHandler() {
        let state = HubDetailPresentationState()
        state.update(for: UIViewController())
        XCTAssertNil(state.dismissThenOpen)
    }

    func testPushedControllerPublishesNoHandler() {
        let pushed = UIViewController()
        _ = UINavigationController(rootViewController: pushed)
        let state = HubDetailPresentationState()
        state.update(for: pushed)
        XCTAssertNil(state.dismissThenOpen)
    }

    func testTabbedControllerPublishesNoHandler() {
        let tabbed = UIViewController()
        let tabBar = UITabBarController()
        tabBar.viewControllers = [tabbed]
        let state = HubDetailPresentationState()
        state.update(for: tabbed)
        XCTAssertNil(state.dismissThenOpen)
    }

    func testPresentedControllerPublishesAHandler() {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.makeKeyAndVisible()
        let presented = UIViewController()
        presenter.present(presented, animated: false)
        defer { presenter.dismiss(animated: false) }

        XCTAssertTrue(HubDetailPresentationState.isPresentedModally(presented))
        let state = HubDetailPresentationState()
        state.update(for: presented)
        XCTAssertNotNil(state.dismissThenOpen)
    }

    func testPresentedControllerWrappedInANavigationControllerIsNotDetected() {
        // Known limit, shared with `HubHostingController`: only the controller the
        // presenter directly presents counts. Wrapped this way, links open in place.
        let window = UIWindow(frame: UIScreen.main.bounds)
        let presenter = UIViewController()
        window.rootViewController = presenter
        window.makeKeyAndVisible()
        let detail = UIViewController()
        presenter.present(UINavigationController(rootViewController: detail), animated: false)
        defer { presenter.dismiss(animated: false) }

        XCTAssertFalse(HubDetailPresentationState.isPresentedModally(detail))
    }
}
