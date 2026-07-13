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

import Combine
import UIKit

/// The surface of `ScrollCoordinator` consumed by `ReplyCollectionViewManager`.
/// Keeping this as a separate protocol lets tests inject a lightweight spy without
/// subclassing the `final` `ScrollCoordinator` or constructing a real UICollectionView.
@MainActor
protocol ScrollCoordinatorProtocol: AnyObject {
    func willApplyPrependSnapshot() -> CGFloat
    func didApplyPrependSnapshot(previousContentHeight: CGFloat)
    func didReceiveNewReplies(count: Int)
}

/// Manages all scroll state and behavior for the conversation detail collection view.
///
/// All methods and properties must be accessed on the main actor.
/// Receives `UIScrollViewDelegate` callbacks directly from the `UICollectionView`.
@MainActor
final class ScrollCoordinator: NSObject, ScrollCoordinatorProtocol {

    // MARK: - Configuration

    /// Distance from the bottom edge at which the user is considered "at bottom".
    nonisolated static let bottomThreshold: CGFloat = 40

    /// Distance from the top edge that triggers backward pagination.
    nonisolated static let topPaginationThreshold: CGFloat = 200

    // MARK: - Published State (observed by SwiftUI via the representable Coordinator)

    @Published private(set) var isAtBottom: Bool = false
    @Published private(set) var pendingNewMessageCount: Int = 0

    /// Fires when the user reaches the bottom — either by scrolling down (false→true transition
    /// in updateIsAtBottom) or when a new reply arrives while already at the bottom
    /// (didReceiveNewReplies with isAtBottom == true). Not added to ScrollCoordinatorProtocol —
    /// consumed only by the ConversationCollectionViewRepresentable bridge.
    let reachedBottom = PassthroughSubject<Void, Never>()

    // MARK: - Internal State

    private(set) var isLoadingOlderMessages: Bool = false

    /// `true` after the initial scroll-to-unread/bottom has been performed.
    private(set) var hasPerformedInitialScroll: Bool = false

    /// Guards against repeated triggers within a single continuous approach to the top.
    ///
    /// Once a load is triggered, this flag prevents re-triggering as long as the user's
    /// `contentOffset.y` stays below `topPaginationThreshold`. It is reset when:
    ///   - The user leaves the top zone (offset rises above `topPaginationThreshold`).
    ///   - A new drag gesture begins (`scrollViewWillBeginDragging`).
    ///   - A status-bar tap fires (`scrollViewDidScrollToTop`).
    ///
    /// This is essential for the TRANSIENT early-return path: `loadOlderMessages` calls
    /// `finishedLoadingOlderMessages()` immediately, resetting `isLoadingOlderMessages = false`.
    /// Without this per-approach gate, every subsequent `scrollViewDidScroll` event fired
    /// during the same drag near the top would re-invoke `onLoadOlderMessages`, spamming the
    /// server with repeated no-op backfill requests.
    private var hasTriggeredThisApproach: Bool = false

    // MARK: - Dependencies

    private weak var collectionView: UICollectionView?

    /// Called when the user scrolls near the top and backward pagination should begin.
    /// The caller is responsible for fetching and then calling `finishedLoadingOlderMessages()`.
    var onLoadOlderMessages: (() -> Void)?

    /// Retained token for the keyboard-frame notification observer.
    private var keyboardObserver: NSObjectProtocol?

    // MARK: - Init

    init(collectionView: UICollectionView) {
        self.collectionView = collectionView
        super.init()

        keyboardObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.handleKeyboardWillChangeFrame()
            }
        }
    }

    deinit {
        if let keyboardObserver {
            NotificationCenter.default.removeObserver(keyboardObserver)
        }
    }

    // MARK: - Commands

    /// Scrolls to the last item in the collection view.
    func scrollToBottom(animated: Bool) {
        guard let cv = collectionView else { return }
        let sections = cv.numberOfSections
        guard sections > 0 else { return }
        let lastSection = sections - 1
        let lastItem = cv.numberOfItems(inSection: lastSection) - 1
        guard lastItem >= 0 else { return }
        cv.scrollToItem(
            at: IndexPath(item: lastItem, section: lastSection),
            at: .bottom,
            animated: animated
        )
    }

    /// Scrolls to the item at `indexPath`.
    func scrollToItem(at indexPath: IndexPath, animated: Bool) {
        collectionView?.scrollToItem(at: indexPath, at: .top, animated: animated)
    }

    /// Clears the pending new-message count (call when user taps the pill or scrolls to bottom).
    func resetPendingCount() {
        pendingNewMessageCount = 0
    }

    /// Marks the initial scroll as done. Call this in `viewDidLayoutSubviews` after
    /// the first scroll-to-unread/bottom has been issued.
    func markInitialScrollDone() {
        hasPerformedInitialScroll = true
    }

    /// Force-evaluates `isAtBottom` from the current collection-view state.
    ///
    /// Call after programmatic scrolls that may not change `contentOffset` — e.g. when
    /// all content already fits on screen and `scrollToItem` is a no-op. In that case
    /// `scrollViewDidScroll` never fires, so `isAtBottom` would stay `false` and the
    /// "new message" pill would appear even though the user can see every message.
    func syncScrollState() {
        guard let cv = collectionView else { return }
        updateIsAtBottom(cv)
    }

    // MARK: - Snapshot Lifecycle (stable prepend anchoring)

    /// Call **before** applying a backward-pagination snapshot.
    /// Returns the current content height to be passed to `didApplyPrependSnapshot`.
    func willApplyPrependSnapshot() -> CGFloat {
        collectionView?.contentSize.height ?? 0
    }

    /// Call **after** applying a backward-pagination snapshot with `animatingDifferences: false`.
    /// Adjusts `contentOffset` so the viewport stays on the same message.
    ///
    /// - Parameter previousContentHeight: The value returned by `willApplyPrependSnapshot()`.
    func didApplyPrependSnapshot(previousContentHeight: CGFloat) {
        guard let cv = collectionView else { return }
        cv.layoutIfNeeded()
        let delta = cv.contentSize.height - previousContentHeight
        guard delta > 0 else { return }
        var offset = cv.contentOffset
        offset.y += delta
        cv.setContentOffset(offset, animated: false)
    }

    /// Signals that backward pagination has finished (success or failure).
    func finishedLoadingOlderMessages() {
        isLoadingOlderMessages = false
    }

    // MARK: - New Reply Notification

    /// Call after a new-messages snapshot is applied. If the user is at the bottom,
    /// scroll to bottom; otherwise increment the pending count.
    ///
    /// - Parameter count: Number of new replies added by this snapshot apply.
    func didReceiveNewReplies(count: Int) {
        guard count > 0 else { return }
        if isAtBottom {
            scrollToBottom(animated: true)
            reachedBottom.send()
        } else {
            pendingNewMessageCount += count
        }
    }

    // MARK: - Keyboard

    private func handleKeyboardWillChangeFrame() {
        guard isAtBottom else { return }
        // After the keyboard layout guide updates, scroll to bottom
        // so the last message stays visible above the composer.
        DispatchQueue.main.async { [weak self] in
            self?.scrollToBottom(animated: false)
        }
    }
}

// MARK: - UICollectionViewDelegate / UIScrollViewDelegate

extension ScrollCoordinator: UICollectionViewDelegate {
    nonisolated func scrollViewDidScroll(_ scrollView: UIScrollView) {
        MainActor.assumeIsolated {
            updateIsAtBottom(scrollView)
            checkBackfillTrigger(scrollView)
        }
    }

    private func updateIsAtBottom(_ scrollView: UIScrollView) {
        // `adjustedContentInset.bottom` accounts for the keyboard / home indicator.
        // We subtract it from the visible-bottom sum (equivalent to the spec formula
        // `offset.y + frame.height >= contentSize.height - inset.bottom - threshold`).
        // The top adjusted inset is intentionally excluded — it affects `contentOffset`
        // when at the very top, not whether we're near the bottom.
        let visibleBottom =
            scrollView.contentOffset.y + scrollView.frame.height
            - scrollView.adjustedContentInset.bottom
        let atBottom =
            visibleBottom >= scrollView.contentSize.height - Self.bottomThreshold
        guard atBottom != isAtBottom else { return }
        isAtBottom = atBottom
        if atBottom {
            pendingNewMessageCount = 0
            reachedBottom.send()
        }
    }

    private func checkBackfillTrigger(_ scrollView: UIScrollView) {
        // Only fire on genuine user gestures. Programmatic setContentOffset calls — from
        // didApplyPrependSnapshot's anchor adjustment, hideSpinner's contentInset mutation, or
        // any other internal layout change — fire scrollViewDidScroll synchronously and must
        // never re-trigger a load. isDragging is true during a finger pan; isDecelerating is
        // true during momentum after the user lifts. Both represent user intent to scroll up.
        guard scrollView.isDragging || scrollView.isDecelerating else { return }
        // Do not backfill until the initial scroll-to-unread has completed. The programmatic
        // scroll to the first unread reply may transiently push contentOffset.y near 0.
        guard hasPerformedInitialScroll else { return }
        guard !isLoadingOlderMessages else { return }
        // When the user scrolls away from the top zone, reset the per-approach guard so a
        // subsequent return to the top zone can fire a new load.
        // With a non-zero contentInset.top (safe area + spinner), UIKit's resting
        // position at the top is contentOffset.y = -adjustedContentInset.top rather
        // than 0. Subtract the inset so the threshold is relative to the resting
        // position. With contentInsetAdjustmentBehavior = .never, adjustedContentInset
        // equals the raw contentInset (system adjustment is zero).
        guard scrollView.contentOffset.y < -scrollView.adjustedContentInset.top + Self.topPaginationThreshold else {
            hasTriggeredThisApproach = false
            return
        }
        // Within a single continuous approach (offset stays below threshold), fire at most once.
        // See `hasTriggeredThisApproach` doc-comment for the full explanation.
        guard !hasTriggeredThisApproach else { return }
        hasTriggeredThisApproach = true
        isLoadingOlderMessages = true
        onLoadOlderMessages?()
    }

    nonisolated func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        MainActor.assumeIsolated {
            // A new drag gesture starts — allow a fresh trigger even if a prior approach in
            // the same deceleration window had already consumed the per-approach gate.
            hasTriggeredThisApproach = false
        }
    }

    nonisolated func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        MainActor.assumeIsolated {
            // Status-bar tap jumps to contentOffset.y = 0 — a clear user intent to see the
            // oldest loaded content. This path bypasses isDragging/isDecelerating (both false
            // during the UIKit-driven animation), so we handle backfill explicitly here rather
            // than relying on checkBackfillTrigger.
            guard hasPerformedInitialScroll else { return }
            guard !isLoadingOlderMessages else { return }
            // Set the per-approach flag to prevent any incidental follow-up scrollViewDidScroll
            // events (e.g. during UIKit's deceleration after the jump) from re-triggering.
            hasTriggeredThisApproach = true
            isLoadingOlderMessages = true
            onLoadOlderMessages?()
        }
    }
}

// MARK: - isAtBottom Pure Helper (exposed for unit tests)

extension ScrollCoordinator {
    /// Pure helper — compute `isAtBottom` from raw metrics.
    /// Useful for unit testing without a real UIScrollView.
    nonisolated static func computeIsAtBottom(
        contentOffsetY: CGFloat,
        frameHeight: CGFloat,
        contentSizeHeight: CGFloat,
        adjustedInsetBottom: CGFloat,
        threshold: CGFloat = ScrollCoordinator.bottomThreshold
    ) -> Bool {
        let visibleBottom = contentOffsetY + frameHeight - adjustedInsetBottom
        return visibleBottom >= contentSizeHeight - threshold
    }
}
