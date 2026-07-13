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
import CoreData
import SwiftUI
import UIKit
import os.log

// MARK: - UIViewControllerRepresentable

/// Publishes scroll state for the SwiftUI overlay and forwards scroll commands to UIKit.
/// Held as `@StateObject` in `ConversationDetailView` and passed into the representable
/// so that `makeCoordinator()` returns the same instance rather than creating a new one.
@MainActor
final class ConversationScrollCoordinator: ObservableObject {
    @Published var pendingNewMessageCount: Int = 0
    @Published var isAtBottom: Bool = false
    /// Height of the hosted ComposerView, published from viewDidLayoutSubviews.
    /// Used by ConversationDetailView to pad NewMessagesPillView above the composer.
    @Published var composerHeight: CGFloat = 0

    /// Forwarded from the UIKit ScrollCoordinator.reachedBottom publisher via the bridge
    /// in makeUIViewController. Observed by ConversationDetailView via .onReceive.
    let reachedBottom = PassthroughSubject<Void, Never>()

    /// Holds the bridge sink token. Optional (not Set) to prevent duplicate sinks if
    /// makeUIViewController is ever called again on the same coordinator instance.
    var reachedBottomCancellable: AnyCancellable?

    weak var viewController: ConversationCollectionViewController?

    func scrollToBottom(animated: Bool) {
        viewController?.scrollCoordinator.scrollToBottom(animated: animated)
        // pendingNewMessageCount resets automatically via scrollViewDidScroll → isAtBottom = true
    }
}

/// Bridges the UIKit conversation collection view into SwiftUI.
struct ConversationCollectionViewRepresentable: UIViewControllerRepresentable {
    let conversationID: UUID
    let container: InboxPersistentContainer
    /// Passed in from the parent's @StateObject so makeCoordinator returns the same instance.
    let scrollCoordinator: ConversationScrollCoordinator
    /// Called by the UIKit layer when backward pagination should begin.
    /// The SwiftUI parent provides this closure from its `@Environment(\.replySync)`.
    let onLoadOlderMessages: @Sendable () async -> Void
    let onSend: (String) -> Void

    func makeCoordinator() -> ConversationScrollCoordinator {
        scrollCoordinator
    }

    func makeUIViewController(context: Context) -> ConversationCollectionViewController {
        let vc = ConversationCollectionViewController(
            conversationID: conversationID,
            container: container,
            conversationScrollCoordinator: scrollCoordinator,
            onLoadOlderMessages: onLoadOlderMessages,
            onSend: onSend
        )
        context.coordinator.viewController = vc

        // Pipe scroll state from the UIKit ScrollCoordinator into the SwiftUI coordinator.
        vc.scrollCoordinator.$isAtBottom
            .receive(on: DispatchQueue.main)
            .assign(to: &context.coordinator.$isAtBottom)
        vc.scrollCoordinator.$pendingNewMessageCount
            .receive(on: DispatchQueue.main)
            .assign(to: &context.coordinator.$pendingNewMessageCount)

        context.coordinator.reachedBottomCancellable =
            vc.scrollCoordinator.reachedBottom
            .receive(on: DispatchQueue.main)
            .sink { [weak coordinator = context.coordinator] in
                coordinator?.reachedBottom.send()
            }

        return vc
    }

    func updateUIViewController(_ uiViewController: ConversationCollectionViewController, context: Context) {
        // No dynamic updates needed — the FRC drives all content changes.
    }
}

// MARK: - UIViewController

/// Hosts the `UICollectionView` for conversation replies.
/// Owns the `NSFetchedResultsController`, `ReplyCollectionViewManager`, and `ScrollCoordinator`.
@MainActor
final class ConversationCollectionViewController: UIViewController {

    // MARK: - Dependencies

    private let conversationID: UUID
    private let container: InboxPersistentContainer
    /// Weak reference to the SwiftUI coordinator — publishes composerHeight
    /// so ConversationDetailView can pad NewMessagesPillView above the composer.
    private weak var conversationScrollCoordinator: ConversationScrollCoordinator?
    /// Called when backward pagination should begin. Provided by the SwiftUI parent.
    private let onLoadOlderMessages: @Sendable () async -> Void
    /// Called when the user submits a message. Provided by the SwiftUI parent.
    private let onSend: (String) -> Void

    // Hosted ComposerView — pinned to keyboardLayoutGuide.topAnchor.
    private var composerHostingController: UIHostingController<ComposerView>?

    // MARK: - Child Objects

    /// Height of the backfill spinner overlay.
    private static let spinnerHeight: CGFloat = 44

    /// Typed as the protocol so tests can inject a spy without constructing a real UICollectionView.
    let collectionViewManager: ReplyCollectionViewManaging
    let scrollCoordinator: ScrollCoordinator

    private lazy var frc: NSFetchedResultsController<Reply> = makeFRC()
    private var participantFRC: NSFetchedResultsController<Participant>?

    // Spinner — pinned above the collection view; height constraint toggled to 0/44.
    private let spinnerView = BackfillSpinnerView()
    private var spinnerHeightConstraint: NSLayoutConstraint?

    /// Captures collection-view state at the moment a backfill is triggered.
    /// Non-nil while a backward-pagination request is in flight; nil when idle.
    /// Separate from `scrollCoordinator.isLoadingOlderMessages` (which throttles re-triggering)
    /// so that forward-sync FRC changes arriving during a backfill are not mistaken for prepends.
    struct BackfillSnapshot {
        let replyIDs: Set<UUID>
        let oldestTimestamp: Date?
    }

    /// Non-nil while a backward-pagination request is in flight; nil when idle.
    /// Internal (not private) so controller-flow tests can set/read it directly.
    var pendingBackfill: BackfillSnapshot? = nil

    /// `true` while `applyPrependSnapshot` is executing so that layout passes
    /// triggered by `didApplyPrependSnapshot` do not fire `scrollToBottom`.
    private var isApplyingPrepend = false

    /// Provides `(backwardsCursor, historyComplete)` for a given conversation ID.
    ///
    /// Defaults to reading from the real `InboxPersistentContainer` once `viewDidLoad` runs.
    /// Override in unit tests to inject mock sync status without a real Core Data stack.
    var replySyncStatusProvider: (UUID) -> (backwardsCursor: String?, historyComplete: Bool)? = { _ in nil }

    /// Retained for the lifetime of the presented full-screen image controller.
    private var heroTransitionDelegate: ImageHeroTransitionDelegate?

    // MARK: - Init

    init(
        conversationID: UUID,
        container: InboxPersistentContainer,
        conversationScrollCoordinator: ConversationScrollCoordinator,
        onLoadOlderMessages: @escaping @Sendable () async -> Void,
        onSend: @escaping (String) -> Void,
        collectionViewManager: ReplyCollectionViewManaging? = nil
    ) {
        self.conversationID = conversationID
        self.container = container
        self.conversationScrollCoordinator = conversationScrollCoordinator
        self.onLoadOlderMessages = onLoadOlderMessages
        self.onSend = onSend
        let manager = collectionViewManager ?? ReplyCollectionViewManager()
        self.collectionViewManager = manager
        self.scrollCoordinator = ScrollCoordinator(
            collectionView: manager.collectionView
        )
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add the collection view filling the entire view.
        let cv = collectionViewManager.collectionView
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.delegate = scrollCoordinator
        view.addSubview(cv)
        NSLayoutConstraint.activate([
            cv.topAnchor.constraint(equalTo: view.topAnchor),
            cv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cv.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Add the backfill spinner as a floating overlay at the top of the view.
        // Height starts at 0 — no reserved space until loading begins.
        spinnerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinnerView)
        let heightConstraint = spinnerView.heightAnchor.constraint(equalToConstant: 0)
        spinnerHeightConstraint = heightConstraint
        NSLayoutConstraint.activate([
            spinnerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            spinnerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            spinnerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            heightConstraint
        ])

        // Connect scroll coordinator back-pagination handler.
        scrollCoordinator.onLoadOlderMessages = { [weak self] in
            self?.loadOlderMessages()
        }

        // Wire the sync-status provider to the real container.
        // Overridable in unit tests via the `replySyncStatusProvider` property.
        replySyncStatusProvider = { [weak self] id in
            guard let status = self?.container.getReplySyncStatus(for: id) else { return nil }
            return (backwardsCursor: status.backwardsCursor, historyComplete: status.historyComplete)
        }

        collectionViewManager.scrollCoordinator = scrollCoordinator

        // Wire tap gesture to forward keyboard dismissal to SwiftUI.
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        tap.cancelsTouchesInView = false
        cv.addGestureRecognizer(tap)

        collectionViewManager.onImageTap = { [weak self] url, sourceView in
            self?.presentFullScreenImage(url: url, sourceView: sourceView)
        }

        // Perform the initial FRC fetch synchronously so data is ready before viewDidLayoutSubviews.
        frc.delegate = self
        do {
            try frc.performFetch()
        } catch {
            assertionFailure("FRC fetch failed: \(error)")
        }

        setupParticipantFRC()

        let groups = regroup()
        collectionViewManager.applyInitialSnapshot(groups)
        collectionViewManager.updateEmptyState(isEmpty: groups.isEmpty)

        // Host ComposerView as a child VC pinned above the keyboard layout guide.
        // composerVC.view.bottomAnchor = keyboardLayoutGuide.topAnchor: composer sits directly
        // above the keyboard. When keyboard is hidden, keyboardLayoutGuide.topAnchor ==
        // safeAreaLayoutGuide.bottomAnchor so the composer rests above the home indicator.
        // UIKit drives all keyboard animation.
        let composerVC = UIHostingController(rootView: ComposerView(placeholderText: "Reply…", onSend: onSend))
        // sizingOptions = .intrinsicContentSize lets Auto Layout resolve the height from
        // the SwiftUI content. Without this, frame.height is 0 until explicitly sized.
        composerVC.sizingOptions = .intrinsicContentSize
        composerVC.view.backgroundColor = .clear
        addChild(composerVC)
        composerVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(composerVC.view)
        NSLayoutConstraint.activate([
            composerVC.view.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            composerVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composerVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        composerVC.didMove(toParent: self)
        composerHostingController = composerVC
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updateComposerInsets()

        guard !scrollCoordinator.hasPerformedInitialScroll else { return }

        scrollCoordinator.scrollToBottom(animated: false)
        scrollCoordinator.markInitialScrollDone()
        scrollCoordinator.syncScrollState()
    }

    // MARK: - Composer Insets

    private func updateComposerInsets() {
        guard let composerView = composerHostingController?.view,
            composerView.bounds.height > 0
        else { return }

        // Set contentInset.bottom directly instead of additionalSafeAreaInsets.bottom.
        // Using additionalSafeAreaInsets creates a feedback loop: it shifts
        // safeAreaLayoutGuide.bottomAnchor upward, which shifts keyboardLayoutGuide.topAnchor
        // upward, which shifts the composer upward by composerHeight — leaving a gap of
        // composerHeight between the composer and the keyboard/safe-area bottom.
        //
        // The collection view extends underneath the bottom safe area, while UIKit's
        // automatic adjusted inset still accounts for the home-indicator region.
        // Reserve only the composer footprint above the safe area here to avoid
        // double-counting the bottom inset and leaving an oversized resting gap.
        let composerTop = composerView.frame.minY
        let newInset = max(0, view.bounds.height - composerTop - view.safeAreaInsets.bottom)
        let cv = collectionViewManager.collectionView
        let insetChanged = cv.contentInset.bottom != newInset
        let indicatorInsetChanged = cv.verticalScrollIndicatorInsets.bottom != newInset
        if cv.contentInset.bottom != newInset {
            cv.contentInset.bottom = newInset
        }
        if indicatorInsetChanged {
            cv.verticalScrollIndicatorInsets.bottom = newInset
        }

        // Keep the newest reply fully visible when the keyboard appears or the
        // composer grows while the user is already anchored at the bottom.
        // Guard against prepend snapshots: didApplyPrependSnapshot forces a layout pass
        // which would otherwise fire scrollToBottom and scroll away from the newly
        // prepended origin card.
        if insetChanged, !isApplyingPrepend, scrollCoordinator.isAtBottom {
            scrollCoordinator.scrollToBottom(animated: false)
        }

        // Publish composer height for NewMessagesPillView bottom padding.
        // Guard against same-value writes to avoid spurious SwiftUI re-renders.
        // composerHeight is @Published on ConversationScrollCoordinator (ObservableObject),
        // so ConversationDetailView re-renders automatically when it changes.
        let newHeight = composerView.frame.height
        if conversationScrollCoordinator?.composerHeight != newHeight {
            conversationScrollCoordinator?.composerHeight = newHeight
        }
    }

    // MARK: - Tap to Dismiss Keyboard

    @objc private func handleBackgroundTap() {
        view.endEditing(true)
    }

    // MARK: - Full-Screen Image

    private func presentFullScreenImage(url: URL, sourceView: UIView) {
        let imageVC = FullScreenImageHostingController(
            rootView: FullScreenImageView(url: url) { [weak self] in
                self?.dismiss(animated: true)
            }
        )
        imageVC.view.backgroundColor = .clear
        imageVC.modalPresentationStyle = .overFullScreen
        let delegate = ImageHeroTransitionDelegate(sourceView: sourceView, url: url)
        heroTransitionDelegate = delegate
        imageVC.transitioningDelegate = delegate
        present(imageVC, animated: true)
    }

    // MARK: - FRC

    private func makeFRC() -> NSFetchedResultsController<Reply> {
        let request = Reply.fetchRequest()
        request.predicate = NSPredicate(
            format: "conversation.id == %@",
            conversationID as CVarArg
        )
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: true),
            // Secondary key for stable ordering when timestamps tie (common at second granularity).
            // `id` is a stored UUID string — lexicographic UUID ordering is not chronological,
            // but it IS deterministic, which is all we need to prevent FRC from emitting
            // spurious move events (and the resulting diffable churn) across fetches.
            NSSortDescriptor(key: "id", ascending: true)
        ]
        request.fetchBatchSize = 50
        return NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: container.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }

    /// Builds and starts the participant FRC if it hasn't been set up yet.
    /// Called from viewDidLoad and retried on the first reply FRC change in case the
    /// Conversation object wasn't in the store at viewDidLoad time.
    private func setupParticipantFRC() {
        guard participantFRC == nil else { return }
        let conversation: Conversation?
        do {
            conversation = try fetchConversation()
        } catch {
            os_log(.error, log: .hub, "Failed to fetch conversation for participant FRC: %@", error as CVarArg)
            return
        }
        guard let conversation else { return }
        let pFRC = makeParticipantFRC(for: conversation)
        pFRC.delegate = self
        do {
            try pFRC.performFetch()
        } catch {
            assertionFailure("Participant FRC fetch failed: \(error)")
        }
        participantFRC = pFRC
    }

    private func makeParticipantFRC(for conversation: Conversation) -> NSFetchedResultsController<Participant> {
        let request = Participant.fetchRequest()
        // Use the Conversation managed object directly rather than ANY conversations.id == %@.
        // NSFetchedResultsController change-tracking is unreliable for ANY quantifier predicates
        // on to-many relationships in the SQLite store; object-reference predicates are reliable.
        request.predicate = NSPredicate(format: "%@ IN conversations", conversation)
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        return NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: container.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
    }

    private func fetchConversation() throws -> Conversation? {
        let request = Conversation.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", conversationID as CVarArg)
        request.fetchLimit = 1
        return try container.viewContext.fetch(request).first
    }

    // MARK: - Grouping

    private func regroup() -> [MessageGroup] {
        let replies = frc.fetchedObjects ?? []
        let snapshots = replies.compactMap { reply -> ReplySnapshot? in
            guard reply.id != nil else { return nil }
            return ReplySnapshot(reply: reply)
        }
        return MessageGrouper.group(snapshots, participants: makeParticipantLookup())
    }

    private func makeParticipantLookup() -> [String: ParticipantInfo] {
        // Prefer the live set already tracked by participantFRC — avoids a redundant SQLite
        // round-trip on every regroup() call. Fall back to a direct fetch only during the
        // brief window before participantFRC is set up (i.e. before viewDidLoad completes or
        // before the first reply FRC change retries setup).
        let participants: [Participant]
        if let frc = participantFRC {
            participants = frc.fetchedObjects ?? []
        } else {
            let request = Participant.fetchRequest()
            request.predicate = NSPredicate(
                format: "ANY conversations.id == %@",
                conversationID as CVarArg
            )
            request.fetchBatchSize = 20
            do {
                participants = try container.viewContext.fetch(request)
            } catch {
                os_log(.error, log: .hub, "Failed to fetch participants for conversation: %@", error as CVarArg)
                return [:]
            }
        }
        return Dictionary(
            uniqueKeysWithValues: participants.compactMap { p -> (String, ParticipantInfo)? in
                guard let id = p.id else { return nil }
                let url = p.avatarURL.flatMap { URL(string: $0) }
                return (id, ParticipantInfo(name: p.name, avatarURL: url))
            }
        )
    }

    // MARK: - Spinner

    private func showSpinner() {
        spinnerHeightConstraint?.constant = Self.spinnerHeight
        // Add the spinner height on top of the automatic nav-bar adjustment.
        collectionViewManager.collectionView.contentInset.top = Self.spinnerHeight
        spinnerView.startAnimating()
    }

    private func hideSpinner() {
        spinnerHeightConstraint?.constant = 0
        collectionViewManager.collectionView.contentInset.top = 0
        spinnerView.stopAnimating()
    }

    // MARK: - Backward Pagination

    /// Evaluates sync status and starts (or early-returns from) a backward pagination request.
    ///
    /// Internal (not private) so controller-flow tests can call it directly without needing
    /// a real `UIScrollView` gesture to trigger `scrollCoordinator.onLoadOlderMessages`.
    func loadOlderMessages() {
        // Exit early when the server has told us there is no more history for this conversation.
        // `ReplySync.syncBackwards` performs the same guard (backwardsCursor != nil &&
        // historyComplete == false), but checking here prevents the spinner flash and the
        // spurious `isPendingBackfill = true` / FRC-delegate skip cycle that would otherwise
        // occur on every subsequent scroll-to-top once history is exhausted.
        let syncStatus = replySyncStatusProvider(conversationID)

        // Guard against the three distinct "cannot backfill" cases, handled differently:
        //
        // PERMANENT (historyComplete == true):
        //   The server confirmed there is no more history. Leaving isLoadingOlderMessages = true
        //   acts as a persistent gate for this session, preventing repeated Core Data fetches on
        //   every subsequent top-scroll. The spinner is never shown in this path, so there is
        //   no user-visible side-effect of the flag staying set.
        //
        //   IMPORTANT: This guard must come BEFORE the backwardsCursor check below. Some code
        //   paths (e.g. stageReplySyncStatus for conversations whose full history fits on one
        //   page) write (backwardsCursor: nil, historyComplete: true). If we checked cursor
        //   first, that combination would fall through to the transient path and incorrectly
        //   reset the loading flag, allowing the user to repeatedly trigger no-op backfills.
        //
        // TRANSIENT (syncStatus nil, or backwardsCursor nil):
        //   SyncStatus is created by the first PostSync run. If the user scrolls to the top
        //   before that sync completes, neither record exists yet. This is a temporary state —
        //   reset isLoadingOlderMessages so the next top-scroll can try again once sync lands.
        guard syncStatus?.historyComplete != true else {
            // Permanent: server confirmed end of history — keep loading flag set.
            return
        }
        guard syncStatus?.backwardsCursor != nil else {
            // Transient: no SyncStatus record or cursor not yet written — let the user retry.
            scrollCoordinator.finishedLoadingOlderMessages()
            return
        }

        // Snapshot current state before the request fires so controllerDidChangeContent can
        // identify which new reply IDs were actually prepended vs. arrived via forward sync.
        pendingBackfill = BackfillSnapshot(
            replyIDs: collectionViewManager.allReplyIDs,
            oldestTimestamp: collectionViewManager.oldestGroupTimestamp
        )
        showSpinner()
        Task { [weak self] in
            await self?.onLoadOlderMessages()
            // Safety net: if FRC never fired (e.g., empty server response, no new data),
            // reset all loading state now. Idempotent with the FRC-triggered path.
            guard let self, pendingBackfill != nil else { return }
            pendingBackfill = nil
            scrollCoordinator.finishedLoadingOlderMessages()
            hideSpinner()
        }
    }

    private func applyPrependSnapshot(_ groups: [MessageGroup]) {
        isApplyingPrepend = true
        collectionViewManager.applyPrependSnapshot(groups)
        isApplyingPrepend = false
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension ConversationCollectionViewController: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>
    ) {
        if let pFRC = participantFRC, ObjectIdentifier(controller) == ObjectIdentifier(pFRC) {
            applyParticipantSnapshot()
        } else {
            // Retry participant FRC setup on the first reply change in case the Conversation
            // object wasn't in the store when viewDidLoad ran.
            setupParticipantFRC()
            handleFRCChange(regroup())
        }
    }
}

// MARK: - FRC Change Processing (extracted for testability)

extension ConversationCollectionViewController {
    /// Handles a participant-only FRC change: re-renders visible groups without touching backfill state.
    ///
    /// Exposed `internal` so tests can drive this path directly without a real FRC.
    func applyParticipantSnapshot() {
        let groups = regroup()
        collectionViewManager.updateEmptyState(isEmpty: groups.isEmpty)
        guard scrollCoordinator.hasPerformedInitialScroll else {
            applyInitialSnapshotBeforeFirstScroll(groups)
            return
        }
        collectionViewManager.applyForwardSnapshot(groups)
    }

    /// Processes a batch of regrouped message data from the FRC delegate.
    ///
    /// Exposed `internal` (not `private`) so controller-flow tests can drive the full
    /// backfill-discrimination and forward-count wiring with a spy manager, without needing
    /// a real `NSFetchedResultsController` or Core Data stack.
    func handleFRCChange(_ groups: [MessageGroup]) {
        collectionViewManager.updateEmptyState(isEmpty: groups.isEmpty)

        if let snapshot = pendingBackfill,
            Self.hasPrependedReplies(
                in: groups,
                preBackfillReplyIDs: snapshot.replyIDs,
                preBackfillOldestTimestamp: snapshot.oldestTimestamp
            )
        {
            pendingBackfill = nil
            scrollCoordinator.finishedLoadingOlderMessages()
            hideSpinner()

            let knownBeforeApply = collectionViewManager.allReplyIDs
            applyPrependSnapshot(groups)

            let forwardCount = Self.forwardAddedCount(
                in: groups,
                knownBeforeBackfillApply: knownBeforeApply,
                preBackfillOldestTimestamp: snapshot.oldestTimestamp
            )
            if forwardCount > 0 {
                scrollCoordinator.didReceiveNewReplies(count: forwardCount)
            }
        } else {
            if !scrollCoordinator.hasPerformedInitialScroll {
                // Initial scroll not done yet — first unread reply just arrived via forward sync.
                applyInitialSnapshotBeforeFirstScroll(groups)
            } else {
                // Capture known IDs before the snapshot so we can identify newly added replies.
                let knownIDs = collectionViewManager.allReplyIDs
                collectionViewManager.applyForwardSnapshot(groups)
                // Own sent replies should always auto-scroll, regardless of current scroll
                // position. applyForwardSnapshot may have incremented pendingNewMessageCount
                // via didReceiveNewReplies — reset it here. Both mutations are synchronous on
                // the main thread, so SwiftUI never renders the intermediate count.
                let hasNewOwnReply = groups.flatMap(\.replies).contains {
                    !knownIDs.contains($0.id) && $0.senderType == .fan
                }
                if hasNewOwnReply {
                    scrollCoordinator.scrollToBottom(animated: true)
                    scrollCoordinator.resetPendingCount()
                }
            }
        }
    }

    private func applyInitialSnapshotBeforeFirstScroll(_ groups: [MessageGroup]) {
        collectionViewManager.applyInitialSnapshot(groups)
        view.setNeedsLayout()
    }
}

// MARK: - Backfill Discrimination (extracted for testability)

extension ConversationCollectionViewController {
    /// Flattens `groups` into a reply-by-ID dictionary and subtracts `knownIDs` to produce
    /// the set of IDs that are new relative to the caller's snapshot.
    ///
    /// Shared by `hasPrependedReplies` and `forwardAddedCount`, which differ only in how
    /// they filter and reduce the added set.
    private static func addedReplies(
        in groups: [MessageGroup],
        knownIDs: Set<UUID>
    ) -> (replyByID: [UUID: ReplySnapshot], addedIDs: Set<UUID>) {
        let allReplies = groups.flatMap(\.replies)
        let replyByID = Dictionary(uniqueKeysWithValues: allReplies.map { ($0.id, $0) })
        return (replyByID, Set(replyByID.keys).subtracting(knownIDs))
    }

    /// Returns `true` if the new `groups` contain at least one reply ID that was not present
    /// in `preBackfillReplyIDs` AND whose `createdAt` is ≤ `preBackfillOldestTimestamp`.
    static func hasPrependedReplies(
        in groups: [MessageGroup],
        preBackfillReplyIDs: Set<UUID>,
        preBackfillOldestTimestamp: Date?
    ) -> Bool {
        let (replyByID, addedIDs) = addedReplies(in: groups, knownIDs: preBackfillReplyIDs)
        return addedIDs.contains { id in
            guard let fence = preBackfillOldestTimestamp,
                let reply = replyByID[id]
            else { return preBackfillOldestTimestamp == nil }  // empty → any data is "older"
            return reply.createdAt <= fence
        }
    }

    /// Returns the number of forward-synced replies in `groups` that were not yet known to
    /// the collection view manager immediately before the prepend snapshot was applied.
    static func forwardAddedCount(
        in groups: [MessageGroup],
        knownBeforeBackfillApply: Set<UUID>,
        preBackfillOldestTimestamp: Date?
    ) -> Int {
        let (replyByID, addedIDs) = addedReplies(in: groups, knownIDs: knownBeforeBackfillApply)
        return addedIDs.filter { id in
            guard let fence = preBackfillOldestTimestamp,
                let reply = replyByID[id]
            else { return false }
            return reply.createdAt > fence
        }.count
    }
}
