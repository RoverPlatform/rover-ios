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

import XCTest

@testable import RoverExperiences

@MainActor
final class AppScreensSheetCollapseCoordinatorTests: XCTestCase {

    private var opened: [URL] = []
    private var backstops: [() -> Void] = []
    private let url = URL(string: "testbench-deep-link://tab/data")!

    private func makeCoordinator() -> AppScreensSheetCollapseCoordinator {
        AppScreensSheetCollapseCoordinator(
            open: { self.opened.append($0) },
            scheduleBackstop: { self.backstops.append($0) }  // captured, fired manually
        )
    }

    func testDismissFalseOpensInPlaceWithoutCollapse() {
        let coordinator = makeCoordinator()
        var cleared = false
        _ = coordinator.registerBottomSheet(clear: { cleared = true })

        coordinator.handleOpenExternal(url, dismiss: false)

        XCTAssertEqual(opened, [url])
        XCTAssertFalse(cleared)
    }

    func testNoSheetOpensImmediately() {
        let coordinator = makeCoordinator()
        coordinator.handleOpenExternal(url, dismiss: true)
        XCTAssertEqual(opened, [url])
    }

    func testDismissTrueClearsBottomThenOpensOnFirstDismiss() {
        let coordinator = makeCoordinator()
        var clearCount = 0
        _ = coordinator.registerBottomSheet(clear: { clearCount += 1 })

        coordinator.handleOpenExternal(url, dismiss: true)
        XCTAssertEqual(clearCount, 1)  // collapse triggered
        XCTAssertEqual(opened, [])  // not opened yet

        coordinator.sheetDidDismiss()  // first dismissal callback
        XCTAssertEqual(opened, [url])
    }

    func testOpenIsExactlyOnceAcrossMultipleDismissCallbacks() {
        let coordinator = makeCoordinator()
        _ = coordinator.registerBottomSheet(clear: {})

        coordinator.handleOpenExternal(url, dismiss: true)
        coordinator.sheetDidDismiss()
        coordinator.sheetDidDismiss()  // inner + outer both fire
        coordinator.sheetDidDismiss()

        XCTAssertEqual(opened, [url])  // opened once only
    }

    func testBackstopOpensWhenNoDismissCallbackArrives() {
        let coordinator = makeCoordinator()
        _ = coordinator.registerBottomSheet(clear: {})

        coordinator.handleOpenExternal(url, dismiss: true)
        XCTAssertEqual(opened, [])
        XCTAssertEqual(backstops.count, 1)

        backstops[0]()  // simulate next-tick with no onDismiss
        XCTAssertEqual(opened, [url])
    }

    func testDeregisterOnlyClearsMatchingId() {
        let coordinator = makeCoordinator()
        var firstCleared = false
        let firstID = coordinator.registerBottomSheet(clear: { firstCleared = true })
        // A deeper presenter's register is ignored (first wins) but returns its own id.
        let secondID = coordinator.registerBottomSheet(clear: {})
        XCTAssertNotEqual(firstID, secondID)

        coordinator.deregisterBottomSheet(id: secondID)  // stale/non-matching → no-op
        coordinator.handleOpenExternal(url, dismiss: true)
        XCTAssertTrue(firstCleared)  // first registration still active
    }

    func testDeregisterMatchingIdRemovesBottomSheet() {
        let coordinator = makeCoordinator()
        var cleared = false
        let id = coordinator.registerBottomSheet(clear: { cleared = true })
        coordinator.deregisterBottomSheet(id: id)

        coordinator.handleOpenExternal(url, dismiss: true)
        XCTAssertFalse(cleared)  // no bottom sheet → opened immediately instead
        XCTAssertEqual(opened, [url])
    }
}
