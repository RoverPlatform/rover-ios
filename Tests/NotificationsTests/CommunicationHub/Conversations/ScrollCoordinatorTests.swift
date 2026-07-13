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

// MARK: - MockScrollView

/// Lightweight `UIScrollView` subclass that overrides `isDragging` and `isDecelerating`
/// so tests can simulate user gestures without a real window hierarchy.
private final class MockScrollView: UIScrollView {
    var mockIsDragging: Bool = false
    var mockIsDecelerating: Bool = false

    override var isDragging: Bool { mockIsDragging }
    override var isDecelerating: Bool { mockIsDecelerating }
}

// MARK: - ScrollCoordinatorTests

final class ScrollCoordinatorTests: XCTestCase {

    // MARK: - syncScrollState

    @MainActor
    func testSyncScrollStateSetsIsAtBottomWhenContentFitsOnScreen() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        XCTAssertFalse(coordinator.isAtBottom, "isAtBottom starts false")

        coordinator.syncScrollState()

        // Empty collection view: visibleBottom = 844, contentSize.height - threshold = -40.
        // 844 >= -40 → at bottom.
        XCTAssertTrue(coordinator.isAtBottom, "syncScrollState must set isAtBottom when all content fits on screen")
    }

    @MainActor
    func testSyncScrollStateResetsPendingCountWhenAtBottom() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        // isAtBottom is false initially, so didReceiveNewReplies increments the count.
        coordinator.didReceiveNewReplies(count: 2)
        XCTAssertEqual(coordinator.pendingNewMessageCount, 2)

        coordinator.syncScrollState()

        XCTAssertEqual(coordinator.pendingNewMessageCount, 0, "Pill count must clear when syncing to bottom state")
    }

    // MARK: - isAtBottom pure helper

    func testIsAtBottomWhenScrolledToEnd() {
        let result = ScrollCoordinator.computeIsAtBottom(
            contentOffsetY: 960,
            frameHeight: 844,
            contentSizeHeight: 1800,
            adjustedInsetBottom: 0
        )
        // visibleBottom = 960 + 844 = 1804 >= 1800 - 40 = 1760 → true
        XCTAssertTrue(result)
    }

    func testIsAtBottomFalseWhenScrolledMidway() {
        let result = ScrollCoordinator.computeIsAtBottom(
            contentOffsetY: 0,
            frameHeight: 844,
            contentSizeHeight: 1800,
            adjustedInsetBottom: 0
        )
        // visibleBottom = 844 >= 1760? No → false
        XCTAssertFalse(result)
    }

    func testIsAtBottomWithNonZeroInset() {
        // adjustedInsetBottom=83 (keyboard + home indicator) shrinks visible area
        let result = ScrollCoordinator.computeIsAtBottom(
            contentOffsetY: 960,
            frameHeight: 844,
            contentSizeHeight: 1800,
            adjustedInsetBottom: 83
        )
        // visibleBottom = 960 + 844 - 83 = 1721 >= 1760? No → false
        XCTAssertFalse(result)
    }

    func testIsAtBottomWithCustomThreshold() {
        let result = ScrollCoordinator.computeIsAtBottom(
            contentOffsetY: 900,
            frameHeight: 844,
            contentSizeHeight: 1800,
            adjustedInsetBottom: 0,
            threshold: 100
        )
        // visibleBottom = 1744 >= 1800 - 100 = 1700 → true
        XCTAssertTrue(result)
    }

    // MARK: - pendingNewMessageCount

    @MainActor
    func testPendingCountResetsWhenScrolledToBottom() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)

        // Simulate arriving at bottom
        coordinator.didReceiveNewReplies(count: 3)
        // isAtBottom starts false, so count should increment
        XCTAssertEqual(coordinator.pendingNewMessageCount, 3)

        coordinator.resetPendingCount()
        XCTAssertEqual(coordinator.pendingNewMessageCount, 0)
    }

    @MainActor
    func testPendingCountAccumulatesWhileNotAtBottom() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        // isAtBottom is false initially

        coordinator.didReceiveNewReplies(count: 2)
        coordinator.didReceiveNewReplies(count: 3)
        XCTAssertEqual(coordinator.pendingNewMessageCount, 5)
    }

    // MARK: - Prepend anchor delta

    @MainActor
    func testPreparePrependSnapshotCapturesContentHeight() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)

        // contentSize starts at zero for an empty collection view
        let captured = coordinator.willApplyPrependSnapshot()
        XCTAssertEqual(captured, cv.contentSize.height)
    }

    @MainActor
    func testDidApplyPrependSnapshotWithZeroDeltaDoesNotChangeOffset() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        let offsetBefore = cv.contentOffset

        // Same content height → delta = 0 → no offset change.
        coordinator.didApplyPrependSnapshot(previousContentHeight: cv.contentSize.height)

        XCTAssertEqual(cv.contentOffset.y, offsetBefore.y)
    }

    // MARK: - Loading state

    @MainActor
    func testFinishedLoadingClearsFlag() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        coordinator.finishedLoadingOlderMessages()
        XCTAssertFalse(coordinator.isLoadingOlderMessages)
    }

    @MainActor
    func testFinishedLoadingOlderMessagesIsIdempotent() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        coordinator.finishedLoadingOlderMessages()
        coordinator.finishedLoadingOlderMessages()
        XCTAssertFalse(coordinator.isLoadingOlderMessages)
    }

    // MARK: - Initial scroll gate

    @MainActor
    func testMarkInitialScrollDoneSetsFlag() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        XCTAssertFalse(coordinator.hasPerformedInitialScroll)
        coordinator.markInitialScrollDone()
        XCTAssertTrue(coordinator.hasPerformedInitialScroll)
    }

    @MainActor
    func testBackfillNotTriggeredBeforeInitialScroll() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        var triggered = false
        coordinator.onLoadOlderMessages = { triggered = true }

        let mock = MockScrollView()
        mock.mockIsDragging = true
        mock.contentOffset = CGPoint(x: 0, y: 0)
        coordinator.scrollViewDidScroll(mock)

        XCTAssertFalse(triggered, "Backfill must not fire before initial scroll completes")
    }

    @MainActor
    func testBackfillNotTriggeredFromProgrammaticScroll() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        coordinator.markInitialScrollDone()

        var triggered = false
        coordinator.onLoadOlderMessages = { triggered = true }

        let mock = MockScrollView()  // isDragging and isDecelerating both false
        mock.contentOffset = CGPoint(x: 0, y: 0)
        coordinator.scrollViewDidScroll(mock)

        XCTAssertFalse(triggered, "Backfill must not fire from programmatic scroll")
    }

    @MainActor
    func testBackfillTriggeredOnUserDragNearTop() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        coordinator.markInitialScrollDone()

        var triggered = false
        coordinator.onLoadOlderMessages = { triggered = true }

        let mock = MockScrollView()
        mock.mockIsDragging = true
        mock.contentOffset = CGPoint(x: 0, y: 0)
        coordinator.scrollViewDidScroll(mock)

        XCTAssertTrue(triggered, "Backfill must fire when user drags to top after initial scroll")
    }

    @MainActor
    func testBackfillTriggeredOnStatusBarTap() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        coordinator.markInitialScrollDone()

        var triggered = false
        coordinator.onLoadOlderMessages = { triggered = true }

        let mock = MockScrollView()
        coordinator.scrollViewDidScrollToTop(mock)

        XCTAssertTrue(triggered, "Backfill must fire on status-bar scroll-to-top")
    }

    @MainActor
    func testStatusBarTapNotTriggeredBeforeInitialScroll() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        var triggered = false
        coordinator.onLoadOlderMessages = { triggered = true }

        coordinator.scrollViewDidScrollToTop(MockScrollView())
        XCTAssertFalse(triggered)
    }

    // MARK: - isLoadingOlderMessages gate

    @MainActor
    func testIsLoadingOlderMessagesStartsFalse() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        XCTAssertFalse(coordinator.isLoadingOlderMessages)
    }

    // MARK: - loadOlderMessages early-return contract

    @MainActor
    func testTransientEarlyReturnResetsLoadingFlagAllowingRetry() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        coordinator.markInitialScrollDone()

        var triggerCount = 0
        coordinator.onLoadOlderMessages = { [weak coordinator] in
            triggerCount += 1
            coordinator?.finishedLoadingOlderMessages()
        }

        let mock = MockScrollView()
        mock.mockIsDragging = true
        mock.contentOffset = CGPoint(x: 0, y: 0)

        // First approach
        coordinator.scrollViewDidScroll(mock)
        XCTAssertEqual(triggerCount, 1)
        XCTAssertFalse(coordinator.isLoadingOlderMessages, "Flag must reset so user can retry")

        // Per-approach gate: same drag, near top → NOT retriggered
        coordinator.scrollViewDidScroll(mock)
        XCTAssertEqual(triggerCount, 1, "Per-approach gate must block repeat trigger in same approach")

        // New drag gesture → gate resets → second trigger fires
        mock.mockIsDragging = false
        coordinator.scrollViewWillBeginDragging(mock)
        mock.mockIsDragging = true
        coordinator.scrollViewDidScroll(mock)
        XCTAssertEqual(triggerCount, 2, "Second trigger must fire after a new drag gesture begins")
    }

    @MainActor
    func testHistoryCompleteEarlyReturnKeepsLoadingFlagPermanentlySet() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        coordinator.markInitialScrollDone()

        var triggerCount = 0
        coordinator.onLoadOlderMessages = {
            triggerCount += 1
            // Permanent path: does NOT call finishedLoadingOlderMessages()
        }

        let mock = MockScrollView()
        mock.mockIsDragging = true
        mock.contentOffset = CGPoint(x: 0, y: 0)

        coordinator.scrollViewDidScroll(mock)
        XCTAssertEqual(triggerCount, 1)
        XCTAssertTrue(coordinator.isLoadingOlderMessages)

        coordinator.scrollViewDidScroll(mock)
        coordinator.scrollViewDidScroll(mock)
        XCTAssertEqual(triggerCount, 1, "No additional triggers must fire once history is complete")
    }

    // MARK: - Per-approach transient debounce

    @MainActor
    func testTransientNoCursorTriggersOnlyOncePerContinuousDrag() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        coordinator.markInitialScrollDone()

        var triggerCount = 0
        coordinator.onLoadOlderMessages = { [weak coordinator] in
            triggerCount += 1
            coordinator?.finishedLoadingOlderMessages()
        }

        let mock = MockScrollView()
        mock.mockIsDragging = true
        mock.contentOffset = CGPoint(x: 0, y: 0)

        // Simulate multiple scrollViewDidScroll events during a single continuous drag
        coordinator.scrollViewDidScroll(mock)
        coordinator.scrollViewDidScroll(mock)
        coordinator.scrollViewDidScroll(mock)

        XCTAssertEqual(triggerCount, 1, "Must trigger only once per continuous drag approach")
    }

    // MARK: - Backfill with non-zero top inset

    @MainActor
    func testBackfillTriggeredAtCorrectOffsetWithNonZeroTopInset() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        coordinator.markInitialScrollDone()

        var triggered = false
        coordinator.onLoadOlderMessages = { triggered = true }

        let mock = MockScrollView()
        mock.mockIsDragging = true
        // Match production: contentInsetAdjustmentBehavior = .never ensures
        // adjustedContentInset equals raw contentInset (no system adjustment).
        mock.contentInsetAdjustmentBehavior = .never
        // Simulate a 100pt top inset (e.g., nav bar + status bar safe area).
        mock.contentInset = UIEdgeInsets(top: 100, left: 0, bottom: 0, right: 0)

        // With contentInset.top = 100, UIKit's resting position is contentOffset.y = -100.
        // The threshold should be: -adjustedContentInset.top + topPaginationThreshold
        //                        = -100 + 200 = 100.
        // An offset of 50 is below the threshold (50 < 100) → should trigger.
        mock.contentOffset = CGPoint(x: 0, y: 50)
        coordinator.scrollViewDidScroll(mock)
        XCTAssertTrue(triggered, "Backfill must trigger when offset is within threshold relative to top inset")
    }

    @MainActor
    func testBackfillNotTriggeredAtExactThresholdWithNonZeroTopInset() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        coordinator.markInitialScrollDone()

        var triggered = false
        coordinator.onLoadOlderMessages = { triggered = true }

        let mock = MockScrollView()
        mock.mockIsDragging = true
        mock.contentInsetAdjustmentBehavior = .never
        mock.contentInset = UIEdgeInsets(top: 100, left: 0, bottom: 0, right: 0)

        // Threshold = -100 + 200 = 100. Offset exactly at threshold (100 < 100 is false) → should NOT trigger.
        mock.contentOffset = CGPoint(x: 0, y: 100)
        coordinator.scrollViewDidScroll(mock)
        XCTAssertFalse(triggered, "Backfill must not trigger at exact threshold boundary")
    }

    @MainActor
    func testBackfillNotTriggeredAboveThresholdWithNonZeroTopInset() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        coordinator.markInitialScrollDone()

        var triggered = false
        coordinator.onLoadOlderMessages = { triggered = true }

        let mock = MockScrollView()
        mock.mockIsDragging = true
        mock.contentInsetAdjustmentBehavior = .never
        mock.contentInset = UIEdgeInsets(top: 100, left: 0, bottom: 0, right: 0)

        // Threshold = -100 + 200 = 100. An offset of 150 is above (150 >= 100) → should NOT trigger.
        mock.contentOffset = CGPoint(x: 0, y: 150)
        coordinator.scrollViewDidScroll(mock)
        XCTAssertFalse(triggered, "Backfill must not trigger when offset is above threshold relative to top inset")
    }

    // MARK: - reachedBottom publisher

    @MainActor
    func testReachedBottomFiresWhenIsAtBottomTransitionsToTrue() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        var eventCount = 0
        let cancellable = coordinator.reachedBottom.sink { eventCount += 1 }

        // Zero-content CV: visibleBottom = 844 >= contentSize.height(0) - threshold(-40) → at bottom.
        // syncScrollState drives isAtBottom false → true, triggering reachedBottom.
        coordinator.syncScrollState()

        XCTAssertEqual(eventCount, 1, "reachedBottom must fire once on the false→true transition")
        cancellable.cancel()
    }

    @MainActor
    func testReachedBottomFiresWhenNewRepliesArriveWhileAlreadyAtBottom() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        // Drive isAtBottom to true before sinking, so the transition event is not counted.
        coordinator.syncScrollState()
        XCTAssertTrue(coordinator.isAtBottom)

        var eventCount = 0
        let cancellable = coordinator.reachedBottom.sink { eventCount += 1 }

        coordinator.didReceiveNewReplies(count: 1)

        XCTAssertEqual(eventCount, 1, "reachedBottom must fire when new replies arrive while already at bottom")
        cancellable.cancel()
    }

    @MainActor
    func testReachedBottomDoesNotFireWhenNewRepliesArriveWhileScrolledUp() async {
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let coordinator = ScrollCoordinator(collectionView: cv)
        // isAtBottom starts false — do not call syncScrollState.
        XCTAssertFalse(coordinator.isAtBottom)

        var eventCount = 0
        let cancellable = coordinator.reachedBottom.sink { eventCount += 1 }

        coordinator.didReceiveNewReplies(count: 3)

        XCTAssertEqual(eventCount, 0, "reachedBottom must not fire when new replies arrive while scrolled up")
        cancellable.cancel()
    }
}
