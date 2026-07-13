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

/// Tests for the controller-level wiring in `ConversationCollectionViewController`:
///   - `handleFRCChange` backfill discrimination and forward-count integration
///   - `loadOlderMessages` permanent/transient gates with injected sync status
///   - safety-net teardown when no prepend FRC change arrives
///
/// Uses `ReplyCollectionViewManagerSpy` to avoid UICollectionView setup.
/// Uses the real `ScrollCoordinator` so coordinator state can be observed directly.
@MainActor
final class ConversationCollectionViewControllerFlowTests: XCTestCase {

    // MARK: - Helpers

    private let base = Date(timeIntervalSince1970: 1_000_000)

    private func snap(id: UUID = UUID(), offset: TimeInterval = 0) -> ReplySnapshot {
        ReplySnapshot(
            id: id,
            createdAt: base.addingTimeInterval(offset),
            senderType: .participant,
            participantID: "p1"
        )
    }

    private func group(replies: [ReplySnapshot]) -> MessageGroup {
        precondition(!replies.isEmpty, "group() requires at least one reply")
        return MessageGroup(
            id: replies[0].id,
            senderType: replies[0].senderType,
            participantID: replies[0].participantID,
            replies: replies,
            timestamp: replies.last!.createdAt  // mirrors MessageGrouper.makeGroup(); safe: precondition above
        )
    }

    /// Builds a controller wired with a spy manager and configurable load closure.
    private func makeController(
        managerSpy: ReplyCollectionViewManagerSpy? = nil,
        onLoadOlderMessages: @escaping @Sendable () async -> Void = {},
        onSend: @escaping (String) -> Void = { _ in }
    ) -> ConversationCollectionViewController {
        let managerSpy = managerSpy ?? ReplyCollectionViewManagerSpy()
        let vc = ConversationCollectionViewController(
            conversationID: UUID(),
            container: InboxPersistentContainer(storage: .inMemory),
            conversationScrollCoordinator: ConversationScrollCoordinator(),
            onLoadOlderMessages: onLoadOlderMessages,
            onSend: onSend,
            collectionViewManager: managerSpy
        )
        // Wire the coordinator into the spy so applyForwardSnapshot can call didReceiveNewReplies.
        managerSpy.scrollCoordinator = vc.scrollCoordinator
        // Load the view so spinnerHeightConstraint and other viewDidLoad state is available.
        // Tests that overwrite replySyncStatusProvider or onLoadOlderMessages do so after this
        // call, which is safe because the overwrites replace viewDidLoad's default wiring.
        vc.loadViewIfNeeded()
        return vc
    }

    // MARK: - Split-event double-count prevention

    func testSplitEventForwardThenPrependDoesNotDoubleCountPill() {
        let spy = ReplyCollectionViewManagerSpy()
        let vc = makeController(managerSpy: spy)
        vc.scrollCoordinator.markInitialScrollDone()

        let existing = snap(offset: 0)
        let forwardC = snap(offset: 60)
        let olderX = snap(offset: -60)

        // Prime backfill state: pretend we triggered a backfill when only `existing` was known.
        spy.stubbedAllReplyIDs = [existing.id]
        spy.stubbedOldestGroupTimestamp = base
        vc.pendingBackfill = .init(replyIDs: [existing.id], oldestTimestamp: base)

        // Event 1: forward-only update (C arrives, no prepend).
        // stubbedAllReplyIDs stays as [existing.id] — C is new in this event.
        // applyForwardSnapshot will compute addedCount = 1 and update stubbedAllReplyIDs.
        vc.handleFRCChange([group(replies: [existing, forwardC])])
        let countAfterEvent1 = vc.scrollCoordinator.pendingNewMessageCount
        XCTAssertEqual(countAfterEvent1, 1, "Forward reply C must be counted once after Event 1")
        XCTAssertNotNil(vc.pendingBackfill, "Backfill still pending after forward-only event")

        // Event 2: prepend (X) + already-cached C arrives together.
        spy.stubbedAllReplyIDs = [existing.id, forwardC.id]  // cache before prepend apply
        vc.handleFRCChange([group(replies: [olderX]), group(replies: [existing, forwardC])])
        let countAfterEvent2 = vc.scrollCoordinator.pendingNewMessageCount
        XCTAssertEqual(countAfterEvent2, 1, "Total pill count must remain 1 — no double-count of C")
        XCTAssertNil(vc.pendingBackfill, "Backfill flag cleared after prepend event")
    }

    // MARK: - Mixed single-event

    func testMixedSingleEventPrependAndForwardCountsForwardExactlyOnce() {
        let spy = ReplyCollectionViewManagerSpy()
        let vc = makeController(managerSpy: spy)
        vc.scrollCoordinator.markInitialScrollDone()

        let existing = snap(offset: 0)
        let forwardC = snap(offset: 60)
        let olderX = snap(offset: -60)

        spy.stubbedAllReplyIDs = [existing.id]
        spy.stubbedOldestGroupTimestamp = base
        vc.pendingBackfill = .init(replyIDs: [existing.id], oldestTimestamp: base)

        vc.handleFRCChange([group(replies: [olderX]), group(replies: [existing, forwardC])])

        XCTAssertNil(vc.pendingBackfill)
        XCTAssertTrue(spy.applyPrependSnapshotCalled, "Prepend snapshot must be applied")
        XCTAssertFalse(spy.applyForwardSnapshotCalled, "Forward snapshot must NOT run in the backfill path")
        XCTAssertEqual(
            vc.scrollCoordinator.pendingNewMessageCount,
            1,
            "Forward reply C must be counted exactly once"
        )
    }

    // MARK: - Backfill branch call order

    func testBackfillBranchCallOrder() {
        let spy = ReplyCollectionViewManagerSpy()
        let vc = makeController(managerSpy: spy)
        vc.scrollCoordinator.markInitialScrollDone()

        let existing = snap(offset: 0)
        let olderX = snap(offset: -60)

        spy.stubbedAllReplyIDs = [existing.id]
        spy.stubbedOldestGroupTimestamp = base
        vc.pendingBackfill = .init(replyIDs: [existing.id], oldestTimestamp: base)

        vc.scrollCoordinator.onLoadOlderMessages = {}
        vc.scrollCoordinator.scrollViewDidScrollToTop(UIScrollView())
        XCTAssertTrue(vc.scrollCoordinator.isLoadingOlderMessages, "Precondition: flag is set")

        var isLoadingAtPrependTime: Bool? = nil
        spy.onApplyPrependSnapshot = { [weak vc] in
            isLoadingAtPrependTime = vc?.scrollCoordinator.isLoadingOlderMessages
        }

        vc.handleFRCChange([group(replies: [olderX]), group(replies: [existing])])

        XCTAssertFalse(
            isLoadingAtPrependTime ?? true,
            "isLoadingOlderMessages must be false by the time applyPrependSnapshot runs"
        )
        XCTAssertTrue(spy.applyPrependSnapshotCalled)
        XCTAssertFalse(spy.applyForwardSnapshotCalled)
        XCTAssertNil(vc.pendingBackfill)
    }

    // MARK: - Permanent gate with nil cursor (P2 regression)

    func testHistoryCompleteWithNilCursorUsesPermanentGate() {
        let vc = makeController()
        vc.scrollCoordinator.markInitialScrollDone()

        vc.replySyncStatusProvider = { _ in (backwardsCursor: nil, historyComplete: true) }

        vc.scrollCoordinator.onLoadOlderMessages = { [weak vc] in vc?.loadOlderMessages() }
        vc.scrollCoordinator.scrollViewDidScrollToTop(UIScrollView())

        XCTAssertNil(vc.pendingBackfill, "No backfill should start when history is complete")
        XCTAssertTrue(
            vc.scrollCoordinator.isLoadingOlderMessages,
            "isLoadingOlderMessages must stay true (permanent gate) so subsequent scrolls cannot re-trigger"
        )
    }

    // MARK: - Transient gates (P1 regression)

    func testTransientGate_NoSyncStatus_ClearsLoadingAndAllowsRetry() {
        let spy = ReplyCollectionViewManagerSpy()
        let vc = makeController(managerSpy: spy)
        vc.scrollCoordinator.markInitialScrollDone()

        var syncStatusProviderCallCount = 0
        vc.replySyncStatusProvider = { _ in
            syncStatusProviderCallCount += 1
            return nil
        }
        vc.scrollCoordinator.onLoadOlderMessages = { [weak vc] in vc?.loadOlderMessages() }

        vc.scrollCoordinator.scrollViewDidScrollToTop(UIScrollView())
        XCTAssertEqual(syncStatusProviderCallCount, 1, "First top-scroll must invoke transient gate once")
        XCTAssertNil(vc.pendingBackfill, "No backfill should start when sync status is missing")
        XCTAssertFalse(
            vc.scrollCoordinator.isLoadingOlderMessages,
            "Transient nil-status path must clear loading so the user can retry"
        )
        XCTAssertEqual(spy.collectionView.contentInset.top, 0, "Spinner inset should remain untouched")

        vc.scrollCoordinator.scrollViewDidScrollToTop(UIScrollView())
        XCTAssertEqual(syncStatusProviderCallCount, 2, "Second top-scroll must invoke transient gate again")
        XCTAssertNil(vc.pendingBackfill)
        XCTAssertFalse(vc.scrollCoordinator.isLoadingOlderMessages)
        XCTAssertEqual(spy.collectionView.contentInset.top, 0)
    }

    func testTransientGate_NilCursorHistoryNotComplete_ClearsLoadingAndAllowsRetry() {
        let spy = ReplyCollectionViewManagerSpy()
        let vc = makeController(managerSpy: spy)
        vc.scrollCoordinator.markInitialScrollDone()

        var syncStatusProviderCallCount = 0
        vc.replySyncStatusProvider = { _ in
            syncStatusProviderCallCount += 1
            return (backwardsCursor: nil, historyComplete: false)
        }
        vc.scrollCoordinator.onLoadOlderMessages = { [weak vc] in vc?.loadOlderMessages() }

        vc.scrollCoordinator.scrollViewDidScrollToTop(UIScrollView())
        XCTAssertEqual(syncStatusProviderCallCount, 1, "First top-scroll must invoke transient gate once")
        XCTAssertNil(
            vc.pendingBackfill,
            "No backfill should start when cursor is nil but history is not complete"
        )
        XCTAssertFalse(
            vc.scrollCoordinator.isLoadingOlderMessages,
            "Transient nil-cursor path must clear loading so the user can retry"
        )
        XCTAssertEqual(spy.collectionView.contentInset.top, 0, "Spinner inset should remain untouched")

        vc.scrollCoordinator.scrollViewDidScrollToTop(UIScrollView())
        XCTAssertEqual(syncStatusProviderCallCount, 2, "Second top-scroll must invoke transient gate again")
        XCTAssertNil(vc.pendingBackfill)
        XCTAssertFalse(vc.scrollCoordinator.isLoadingOlderMessages)
        XCTAssertEqual(spy.collectionView.contentInset.top, 0)
    }

    // MARK: - Safety-net teardown (P2 regression)

    func testSafetyNet_NoFRCChange_ResetsBackfillAndLoadingState() async {
        let spy = ReplyCollectionViewManagerSpy()
        let vc = makeController(
            managerSpy: spy,
            onLoadOlderMessages: {
                await Task.yield()
            }
        )
        vc.scrollCoordinator.markInitialScrollDone()

        vc.replySyncStatusProvider = { _ in (backwardsCursor: "cursor-1", historyComplete: false) }
        vc.scrollCoordinator.onLoadOlderMessages = { [weak vc] in vc?.loadOlderMessages() }

        vc.scrollCoordinator.scrollViewDidScrollToTop(UIScrollView())

        XCTAssertNotNil(vc.pendingBackfill, "Backfill should be pending immediately after trigger")
        XCTAssertTrue(vc.scrollCoordinator.isLoadingOlderMessages, "Loading gate should be active")
        XCTAssertEqual(spy.collectionView.contentInset.top, 44, "Spinner inset should be applied")
        XCTAssertFalse(spy.applyForwardSnapshotCalled)
        XCTAssertFalse(spy.applyPrependSnapshotCalled)

        await waitUntil {
            vc.pendingBackfill == nil && !vc.scrollCoordinator.isLoadingOlderMessages
        }

        XCTAssertNil(vc.pendingBackfill)
        XCTAssertFalse(vc.scrollCoordinator.isLoadingOlderMessages)
        XCTAssertEqual(spy.collectionView.contentInset.top, 0, "Spinner inset should be cleared")
        XCTAssertFalse(spy.applyForwardSnapshotCalled, "No FRC path should not apply forward snapshot")
        XCTAssertFalse(spy.applyPrependSnapshotCalled, "No FRC path should not apply prepend snapshot")
    }

    func testSafetyNet_NoOpAfterPrependFRCAlreadyClearedBackfill() async {
        let spy = ReplyCollectionViewManagerSpy()
        let loadStarted = expectation(description: "onLoadOlderMessages started")
        let loadFinished = expectation(description: "onLoadOlderMessages finished")
        var continuation: CheckedContinuation<Void, Never>? = nil

        let vc = makeController(
            managerSpy: spy,
            onLoadOlderMessages: {
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    continuation = cont
                    loadStarted.fulfill()
                }
                loadFinished.fulfill()
            }
        )
        vc.scrollCoordinator.markInitialScrollDone()

        let existing = snap(offset: 0)
        let olderX = snap(offset: -60)
        spy.stubbedAllReplyIDs = [existing.id]
        spy.stubbedOldestGroupTimestamp = base

        vc.replySyncStatusProvider = { _ in (backwardsCursor: "cursor-1", historyComplete: false) }
        vc.scrollCoordinator.onLoadOlderMessages = { [weak vc] in vc?.loadOlderMessages() }

        vc.scrollCoordinator.scrollViewDidScrollToTop(UIScrollView())
        await fulfillment(of: [loadStarted], timeout: 1.0)
        XCTAssertNotNil(vc.pendingBackfill)
        XCTAssertTrue(vc.scrollCoordinator.isLoadingOlderMessages, "loading should be true while backfill is in flight")
        XCTAssertEqual(spy.collectionView.contentInset.top, 44)

        vc.handleFRCChange([group(replies: [olderX]), group(replies: [existing])])
        XCTAssertNil(vc.pendingBackfill)
        XCTAssertFalse(vc.scrollCoordinator.isLoadingOlderMessages, "FRC prepend should have cleared loading flag")
        XCTAssertEqual(spy.collectionView.contentInset.top, 0)

        continuation?.resume()
        await fulfillment(of: [loadFinished], timeout: 1.0)
        await Task.yield()

        // Safety-net path: FRC already cleared the flag before the task resumed.
        // Verify state is still stable — no spurious re-flip from the safety net.
        XCTAssertNil(vc.pendingBackfill)
        XCTAssertFalse(
            vc.scrollCoordinator.isLoadingOlderMessages,
            "safety-net must not re-set loading flag after FRC already cleared it"
        )
    }

    func testSafetyNet_NoOpAfterPrependFRC_KeepsSpinnerStateStableAfterResume() async {
        let spy = ReplyCollectionViewManagerSpy()
        let loadStarted = expectation(description: "onLoadOlderMessages started")
        let loadFinished = expectation(description: "onLoadOlderMessages finished")
        var continuation: CheckedContinuation<Void, Never>? = nil

        let vc = makeController(
            managerSpy: spy,
            onLoadOlderMessages: {
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    continuation = cont
                    loadStarted.fulfill()
                }
                loadFinished.fulfill()
            }
        )
        vc.scrollCoordinator.markInitialScrollDone()

        let existing = snap(offset: 0)
        let olderX = snap(offset: -60)
        spy.stubbedAllReplyIDs = [existing.id]
        spy.stubbedOldestGroupTimestamp = base

        vc.replySyncStatusProvider = { _ in (backwardsCursor: "cursor-1", historyComplete: false) }
        vc.scrollCoordinator.onLoadOlderMessages = { [weak vc] in vc?.loadOlderMessages() }

        vc.scrollCoordinator.scrollViewDidScrollToTop(UIScrollView())
        await fulfillment(of: [loadStarted], timeout: 1.0)
        XCTAssertEqual(spy.collectionView.contentInset.top, 44)

        vc.handleFRCChange([group(replies: [olderX]), group(replies: [existing])])
        let insetAfterFRC = spy.collectionView.contentInset.top
        let pendingAfterFRC = vc.pendingBackfill != nil
        let loadingAfterFRC = vc.scrollCoordinator.isLoadingOlderMessages
        XCTAssertEqual(insetAfterFRC, 0)
        XCTAssertFalse(pendingAfterFRC)
        XCTAssertFalse(loadingAfterFRC)

        continuation?.resume()
        await fulfillment(of: [loadFinished], timeout: 1.0)
        await Task.yield()

        XCTAssertEqual(
            spy.collectionView.contentInset.top,
            insetAfterFRC,
            "Spinner inset should remain stable after safety-net no-op"
        )
        XCTAssertEqual(vc.pendingBackfill != nil, pendingAfterFRC)
        XCTAssertEqual(vc.scrollCoordinator.isLoadingOlderMessages, loadingAfterFRC)
    }

    // MARK: - Participant-only update

    func testParticipantOnlyUpdateAppliesForwardSnapshotWithZeroNewReplies() {
        let spy = ReplyCollectionViewManagerSpy()
        let vc = makeController(managerSpy: spy)
        vc.scrollCoordinator.markInitialScrollDone()

        let reply = snap(offset: 0)

        // Prime spy: the reply is already known so addedCount computes to 0.
        spy.stubbedAllReplyIDs = [reply.id]

        // Groups with the same reply IDs but different participant info — simulates
        // a Participant attribute update with no concurrent Reply change (the path
        // the participant FRC triggers).
        let updatedGroup = MessageGroup(
            id: reply.id,
            senderType: .participant,
            participantID: "p1",
            participantName: "Alice Updated",
            participantAvatarURL: URL(string: "https://example.com/alice-new.jpg"),
            replies: [reply],
            timestamp: reply.createdAt
        )

        vc.handleFRCChange([updatedGroup])

        XCTAssertTrue(
            spy.applyForwardSnapshotCalled,
            "Forward snapshot must be applied for a participant-only update"
        )
        XCTAssertFalse(
            spy.applyPrependSnapshotCalled,
            "Prepend path must not be taken on participant-only update"
        )
        XCTAssertEqual(
            vc.scrollCoordinator.pendingNewMessageCount,
            0,
            "No scroll/pending-count notification should fire because addedCount computes to 0"
        )
        XCTAssertEqual(
            spy.lastAppliedGroups.first?.participantName,
            "Alice Updated",
            "Updated participant name must be passed through to the manager"
        )
    }

    func testParticipantSnapshotDuringBackfillDoesNotClearPendingBackfill() {
        let spy = ReplyCollectionViewManagerSpy()
        let vc = makeController(managerSpy: spy)
        vc.scrollCoordinator.markInitialScrollDone()

        let reply = snap(offset: 0)
        spy.stubbedAllReplyIDs = [reply.id]

        vc.pendingBackfill = ConversationCollectionViewController.BackfillSnapshot(
            replyIDs: [reply.id],
            oldestTimestamp: reply.createdAt
        )

        vc.applyParticipantSnapshot()

        XCTAssertNotNil(
            vc.pendingBackfill,
            "Backfill snapshot must not be cleared by a participant-only FRC change"
        )
        XCTAssertTrue(
            spy.applyForwardSnapshotCalled,
            "Forward snapshot must still be applied for a participant update during backfill"
        )
    }

}

// MARK: - Test Spy

/// Spy implementation of `ReplyCollectionViewManaging` for controller-flow tests.
@MainActor
private final class ReplyCollectionViewManagerSpy: ReplyCollectionViewManaging {
    let collectionView = UICollectionView(
        frame: CGRect(x: 0, y: 0, width: 390, height: 844),
        collectionViewLayout: UICollectionViewFlowLayout()
    )

    weak var scrollCoordinator: ScrollCoordinatorProtocol?

    var stubbedAllReplyIDs: Set<UUID> = []
    var stubbedOldestGroupTimestamp: Date? = nil
    var operationLog: [String] = []
    var onImageTap: ((URL, UIView) -> Void)?

    var applyInitialSnapshotCalled = false
    var applyForwardSnapshotCalled = false
    var applyPrependSnapshotCalled = false
    var lastAppliedGroups: [MessageGroup] = []

    var onApplyPrependSnapshot: (() -> Void)? = nil

    var allReplyIDs: Set<UUID> { stubbedAllReplyIDs }
    var oldestGroupTimestamp: Date? { stubbedOldestGroupTimestamp }

    func applyInitialSnapshot(_ groups: [MessageGroup]) {
        applyInitialSnapshotCalled = true
        lastAppliedGroups = groups
        operationLog.append("applyInitialSnapshot")
    }

    func applyForwardSnapshot(_ groups: [MessageGroup]) {
        applyForwardSnapshotCalled = true
        lastAppliedGroups = groups
        operationLog.append("applyForwardSnapshot")
        let incoming = Set(groups.flatMap { $0.replies.map(\.id) })
        let addedCount = incoming.subtracting(stubbedAllReplyIDs).count
        scrollCoordinator?.didReceiveNewReplies(count: addedCount)
        stubbedAllReplyIDs = stubbedAllReplyIDs.union(incoming)
    }

    func applyPrependSnapshot(_ groups: [MessageGroup]) {
        onApplyPrependSnapshot?()
        applyPrependSnapshotCalled = true
        lastAppliedGroups = groups
        operationLog.append("applyPrependSnapshot")
    }

    func updateEmptyState(isEmpty: Bool) {
        operationLog.append("updateEmptyState(\(isEmpty))")
    }

    func indexPath(forReplyID replyID: UUID) -> IndexPath? {
        nil
    }
}
