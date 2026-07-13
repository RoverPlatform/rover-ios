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

import SwiftUI
import UIKit

/// Abstraction over `ReplyCollectionViewManager` for testing.
///
/// Allows `ConversationCollectionViewController` tests to inject a lightweight spy
/// without constructing a real `UICollectionView` or diffable data source.
@MainActor
protocol ReplyCollectionViewManaging: AnyObject {
    var collectionView: UICollectionView { get }
    var allReplyIDs: Set<UUID> { get }
    var oldestGroupTimestamp: Date? { get }
    /// Reference to the scroll coordinator for anchoring and new-reply notifications.
    var scrollCoordinator: ScrollCoordinatorProtocol? { get set }
    var onImageTap: ((URL, UIView) -> Void)? { get set }
    func applyInitialSnapshot(_ groups: [MessageGroup])
    func applyForwardSnapshot(_ groups: [MessageGroup])
    func applyPrependSnapshot(_ groups: [MessageGroup])
    func updateEmptyState(isEmpty: Bool)
    func indexPath(forReplyID replyID: UUID) -> IndexPath?
}

/// Owns the `UICollectionView` setup: compositional layout, cell registration,
/// and the diffable data source.
///
/// Call `applyInitialSnapshot(_:)` for the first load (no animation).
/// Call `applyForwardSnapshot(_:)` for new messages (no animation, notifies scroll coordinator).
/// Call `applyPrependSnapshot(_:)` for backward pagination (no animation, anchors scroll position).
@MainActor
final class ReplyCollectionViewManager: ReplyCollectionViewManaging {

    // MARK: - Types

    enum ReplySection: Hashable {
        case messages
    }

    /// Item type for the conversation detail diffable data source.
    ///
    /// `CollectionItem` is internal to `ReplyCollectionViewManager`.
    /// `separator(Date)` identity is safe because exactly one manager instance exists per conversation,
    /// so start-of-day `Date` values cannot collide across conversations in the same snapshot.
    enum CollectionItem: Hashable {
        case group(UUID)
        /// Calendar start-of-day for the separator's calendar day.
        case separator(Date)
    }

    // MARK: - Properties

    let collectionView: UICollectionView
    private var dataSource: UICollectionViewDiffableDataSource<ReplySection, CollectionItem>!

    /// Keyed by `MessageGroup.id` (first reply's UUID).
    private var groupsByID: [UUID: MessageGroup] = [:]

    /// Reverse index: reply ID → group ID. Enables O(1) lookup in `indexPath(forReplyID:)`.
    private var replyIDToGroupID: [UUID: UUID] = [:]

    /// Cached derived values — updated atomically with `groupsByID` in `updateGroupCache`.
    private var cachedAllReplyIDs: Set<UUID> = []
    private var cachedOldestGroupTimestamp: Date? = nil
    private var cachedNewestGroupID: UUID? = nil
    /// Set to the group IDs passed to `reconfigureItems` by the most recent snapshot application.
    /// Internal — used only by unit tests to verify reconfigure activity without UIKit inspection.
    var lastReconfiguredGroupIDs: [UUID] = []
    var onImageTap: ((URL, UIView) -> Void)?

    /// Cached empty state label, reused across updateEmptyState calls.
    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "Start the conversation"
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .body)
        return label
    }()

    /// Reference to the scroll coordinator for anchoring and new-reply notifications.
    /// Typed as the protocol so tests can inject a spy without subclassing ScrollCoordinator.
    weak var scrollCoordinator: ScrollCoordinatorProtocol?

    // MARK: - Init

    init() {
        collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: ReplyCollectionViewManager.makeLayout()
        )
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        // Let UIKit automatically adjust the top inset for the navigation bar.
        // The SwiftUI representable uses .ignoresSafeArea(.container, edges: .top) so
        // the frame extends under the nav bar; .automatic ensures content starts below
        // it without any manual contentInset.top management for the safe area.
        collectionView.contentInsetAdjustmentBehavior = .automatic
        collectionView.isAccessibilityElement = false

        configureDataSource()
    }

    // MARK: - Layout

    private static func makeLayout() -> UICollectionViewLayout {
        // Use an explicit fractionalWidth(1.0) item so UIHostingConfiguration cells
        // are always given the full container width during SwiftUI measurement.
        // NSCollectionLayoutSection.list() uses self-sizing which asks SwiftUI for its
        // ideal width — this causes UIHostingConfiguration cells with maxWidth:.infinity
        // to size to their content rather than the container, producing narrow cells.
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(60)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(60)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 0
        // Prevent the layout from insetting content from the safe area. Without this,
        // ignoresSafeArea(.top) on the SwiftUI representable causes a layout conflict:
        // the frame extends under the nav bar but the layout insets from it, producing
        // a fly-in animation as cells resolve the discrepancy during scrolling.
        section.contentInsetsReference = .none
        return UICollectionViewCompositionalLayout(section: section)
    }

    // MARK: - Registration

    // No supplementary views — BackfillSpinnerView is managed by the view controller.

    // MARK: - Data Source

    private func configureDataSource() {
        let groupRegistration = UICollectionView.CellRegistration<
            UICollectionViewCell, UUID
        > { [weak self] cell, _, groupID in
            guard let group = self?.groupsByID[groupID] else { return }
            cell.contentConfiguration = UIHostingConfiguration {
                MessageGroupBubbleView(
                    group: group,
                    isMostRecent: group.id == self?.cachedNewestGroupID,
                    onImageTap: self?.onImageTap
                )
            }
            .margins(.all, 0)
        }

        let separatorRegistration = UICollectionView.CellRegistration<
            UICollectionViewCell, Date
        > { cell, _, date in
            cell.contentConfiguration = UIHostingConfiguration {
                DateSeparatorView(date: date)
            }
            .margins(.all, 0)
        }

        dataSource = UICollectionViewDiffableDataSource<ReplySection, CollectionItem>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            switch item {
            case .group(let id):
                return collectionView.dequeueConfiguredReusableCell(
                    using: groupRegistration,
                    for: indexPath,
                    item: id
                )
            case .separator(let date):
                return collectionView.dequeueConfiguredReusableCell(
                    using: separatorRegistration,
                    for: indexPath,
                    item: date
                )
            }
        }
    }

    // MARK: - Snapshot Application

    /// Apply the initial snapshot — no animation, no scroll adjustment.
    func applyInitialSnapshot(_ groups: [MessageGroup]) {
        updateGroupCache(groups)
        var snapshot = NSDiffableDataSourceSnapshot<ReplySection, CollectionItem>()
        snapshot.appendSections([.messages])
        snapshot.appendItems(Self.injectSeparators(groups), toSection: .messages)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    /// Apply a snapshot for new incoming/outgoing messages without animation (`applyForwardSnapshot(_:)`).
    /// Notifies `scrollCoordinator` of the number of new **replies** added.
    ///
    /// NOTE: We count new reply IDs, not new group IDs. With stable group IDs (first reply),
    /// a new reply appending to an existing group keeps the group ID the same — so counting
    /// group IDs would miss the new message entirely and prevent auto-scroll/pill increment.
    func applyForwardSnapshot(_ groups: [MessageGroup]) {
        let oldReplyIDs = allReplyIDs
        let newReplyIDs = Set(groups.flatMap { $0.replies.map(\.id) })
        let addedCount = newReplyIDs.subtracting(oldReplyIDs).count

        // Find groups whose content changed (same ID, different replies).
        let changedIDs = groups.compactMap { group -> UUID? in
            guard let existing = groupsByID[group.id], existing != group else { return nil }
            return group.id
        }

        updateGroupCache(groups)
        var snapshot = NSDiffableDataSourceSnapshot<ReplySection, CollectionItem>()
        snapshot.appendSections([.messages])
        snapshot.appendItems(Self.injectSeparators(groups), toSection: .messages)

        reconfigureIfNeeded(&snapshot, changedIDs: changedIDs)

        // Apply with animatingDifferences: false — UIHostingConfiguration measures cell heights
        // asynchronously, so animating the change causes bubbles to spread apart mid-transition.
        // scrollToBottom (called via didReceiveNewReplies) provides the motion cue instead.
        // Item count updates synchronously before apply() returns, so scrollToBottom computes
        // the correct last-item index path and unit tests stay deterministic.
        dataSource.apply(snapshot, animatingDifferences: false)
        scrollCoordinator?.didReceiveNewReplies(count: addedCount)
    }

    /// Apply a backward-pagination snapshot — no animation, adjusts scroll position via coordinator.
    func applyPrependSnapshot(_ groups: [MessageGroup]) {
        let previousHeight = scrollCoordinator?.willApplyPrependSnapshot() ?? 0

        // Find groups whose content changed.
        let changedIDs = groups.compactMap { group -> UUID? in
            guard let existing = groupsByID[group.id], existing != group else { return nil }
            return group.id
        }

        updateGroupCache(groups)
        var snapshot = NSDiffableDataSourceSnapshot<ReplySection, CollectionItem>()
        snapshot.appendSections([.messages])
        snapshot.appendItems(Self.injectSeparators(groups), toSection: .messages)

        reconfigureIfNeeded(&snapshot, changedIDs: changedIDs)

        // animatingDifferences: false is documented to apply the snapshot synchronously on the
        // main thread before returning. Calling didApplyPrependSnapshot directly after apply()
        // is therefore equivalent to calling it in the completion block, keeps the pattern
        // consistent with applyForwardSnapshot, and removes any test-timing ambiguity.
        //
        // didApplyPrependSnapshot itself calls cv.layoutIfNeeded() before reading contentSize,
        // so it is safe even if the collection view's layout cycle has not yet run — the forced
        // layout pass ensures the updated contentSize is available for the delta computation.
        dataSource.apply(snapshot, animatingDifferences: false)
        scrollCoordinator?.didApplyPrependSnapshot(previousContentHeight: previousHeight)
    }

    // MARK: - Index Path Lookup

    /// Returns the index path for the `MessageGroup` containing the reply with `replyID`.
    func indexPath(forReplyID replyID: UUID) -> IndexPath? {
        guard let groupID = replyIDToGroupID[replyID] else { return nil }
        return dataSource.indexPath(for: .group(groupID))
    }

    // MARK: - Empty State

    /// Sets the backgroundView on the collectionView when the state is empty
    func updateEmptyState(isEmpty: Bool) {
        collectionView.backgroundView = isEmpty ? emptyStateLabel : nil
    }

    // MARK: - Query

    /// The earliest group timestamp currently in the collection.
    var oldestGroupTimestamp: Date? {
        cachedOldestGroupTimestamp
    }

    /// All reply IDs currently in the collection.
    /// Used by `ConversationCollectionViewController` to snapshot known IDs before a backfill
    /// request so it can identify which new IDs were actually prepended vs. forward-synced.
    var allReplyIDs: Set<UUID> {
        cachedAllReplyIDs
    }

    // MARK: - Private

    private func reconfigureIfNeeded(
        _ snapshot: inout NSDiffableDataSourceSnapshot<ReplySection, CollectionItem>,
        changedIDs: [UUID]
    ) {
        lastReconfiguredGroupIDs = changedIDs
        guard !changedIDs.isEmpty else { return }
        snapshot.reconfigureItems(changedIDs.map { .group($0) })
    }

    private func updateGroupCache(_ groups: [MessageGroup]) {
        groupsByID = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
        replyIDToGroupID = Dictionary(
            uniqueKeysWithValues: groups.flatMap { group in
                group.replies.map { ($0.id, group.id) }
            }
        )
        cachedAllReplyIDs = Set(replyIDToGroupID.keys)
        cachedOldestGroupTimestamp = groups.first?.timestamp
        cachedNewestGroupID = groups.last?.id
    }
}

// MARK: - Item Building

extension ReplyCollectionViewManager {
    /// Converts an ordered `[MessageGroup]` array into `[CollectionItem]` by inserting a
    /// `.separator(firstGroupReplyTimestamp)` item before the first group of each new calendar day.
    ///
    /// - Empty input → empty output.
    /// - The first group always gets a separator.
    /// - Consecutive groups on the same calendar day share one separator.
    /// - Groups with identical timestamps produce no additional separator.
    /// - **Invariant:** the last item in the output is always `.group(_)`,
    ///   which protects `ScrollCoordinator.scrollToBottom` (which scrolls to the last item).
    static func injectSeparators(_ groups: [MessageGroup]) -> [CollectionItem] {
        guard !groups.isEmpty else { return [] }
        var items: [CollectionItem] = []
        var lastDay: Date? = nil
        let calendar = Calendar.current
        for group in groups {
            let day = calendar.startOfDay(for: group.timestamp)
            if day != lastDay {
                items.append(.separator(group.replies.first?.createdAt ?? group.timestamp))
                lastDay = day
            }
            items.append(.group(group.id))
        }
        return items
    }
}
