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

/// Class name contains "ViewHost" so `Introspect.findViewHost(from:)` treats it as
/// the SwiftUI platform-view wrapper, letting these tests model the hierarchy the
/// introspection probe sees without any SwiftUI hosting (which is flaky headless).
private final class TestViewHost: UIView {}

/// Pins the semantics of `TargetViewSelector.siblingContaining`, the selector
/// `introspectScrollView` uses (SDK-351). The load-bearing guarantees:
/// it finds a scroll view nested anywhere inside a PREVIOUS sibling's subtree,
/// and it can never reach an ancestor — which is exactly what stops an embedded
/// experience from capturing the host app's scroll view.
@MainActor
final class IntrospectSelectorTests: XCTestCase {

    /// The experience's scroll view lives nested inside a sibling that precedes
    /// the probe's view host — the arrangement observed on-device (iOS 26).
    func testFindsScrollViewNestedInPreviousSiblingSubtree() {
        let container = UIView()
        let sibling = UIView()
        let wrapper = UIView()
        let scrollView = UIScrollView()
        let viewHost = TestViewHost()
        let probe = UIView()

        wrapper.addSubview(scrollView)
        sibling.addSubview(wrapper)
        container.addSubview(sibling)
        container.addSubview(viewHost)
        viewHost.addSubview(probe)

        let found: UIScrollView? = TargetViewSelector.siblingContaining(from: probe)
        XCTAssertIdentical(found, scrollView)
    }

    /// A scroll view that is an ANCESTOR of the probe — the host app's scroll view
    /// in the embedded case — must never be selected.
    func testDoesNotFindAncestorScrollView() {
        let hostScrollView = UIScrollView()
        let container = UIView()
        let viewHost = TestViewHost()
        let probe = UIView()

        hostScrollView.addSubview(container)
        container.addSubview(viewHost)
        viewHost.addSubview(probe)

        let found: UIScrollView? = TargetViewSelector.siblingContaining(from: probe)
        XCTAssertNil(found)
    }

    /// Siblings that come AFTER the probe's view host are not previous siblings
    /// and must not be selected.
    func testDoesNotFindFollowingSiblingScrollView() {
        let container = UIView()
        let viewHost = TestViewHost()
        let probe = UIView()
        let followingSibling = UIView()
        let scrollView = UIScrollView()

        container.addSubview(viewHost)
        container.addSubview(followingSibling)
        viewHost.addSubview(probe)
        followingSibling.addSubview(scrollView)

        let found: UIScrollView? = TargetViewSelector.siblingContaining(from: probe)
        XCTAssertNil(found)
    }

    /// No scroll view anywhere: the selector returns nil and the caller does nothing.
    func testReturnsNilWhenNoScrollViewExists() {
        let container = UIView()
        let sibling = UIView()
        let viewHost = TestViewHost()
        let probe = UIView()

        container.addSubview(sibling)
        container.addSubview(viewHost)
        viewHost.addSubview(probe)

        let found: UIScrollView? = TargetViewSelector.siblingContaining(from: probe)
        XCTAssertNil(found)
    }

    /// Without a "ViewHost"-named wrapper above the probe the selector bails out.
    func testReturnsNilWhenNoViewHostAboveProbe() {
        let container = UIView()
        let probe = UIView()
        container.addSubview(probe)

        let found: UIScrollView? = TargetViewSelector.siblingContaining(from: probe)
        XCTAssertNil(found)
    }
}

/// SDK-351: the scroll delegate exists only to restyle an inline nav bar on
/// scroll, so introspection must not be installed for any other configuration.
@MainActor
final class ScrollDelegateInstallationTests: XCTestCase {
    func testInstallsOnlyForInlineNavBar() {
        XCTAssertTrue(ScreenViewController.shouldInstallScrollDelegate(titleDisplayMode: .inline))
        XCTAssertFalse(ScreenViewController.shouldInstallScrollDelegate(titleDisplayMode: .large))
        XCTAssertFalse(ScreenViewController.shouldInstallScrollDelegate(titleDisplayMode: nil))
    }
}
