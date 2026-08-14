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
import Foundation
import RoverData
import SwiftUI
import UserNotifications
import os.log

/// This object is responsible for updating the main app badge, and also offers API for obtaining (and observing) the badge count for a Hub tab.
@MainActor
public class RoverBadge: ObservableObject {
    private let persistentContainer: InboxPersistentContainer
    private let seenWatermark: InboxSeenWatermark
    private let configManager: ConfigManager
    private let updateAppBadge: Bool

    /// Counts above this are displayed as `"9+"` instead of the number itself, and the numeric
    /// app-icon badge is clamped to it.
    static let maximumDisplayedCount = 9

    /// Whether the Hub tab has new items and should display a badge, as display-ready text.
    ///
    /// Counts the unread posts and unread conversations with activity since the user last viewed
    /// the inbox. Counts of 1 through 9 are the number itself; anything higher is `"9+"`.
    ///
    /// If nil, then the count is 0 and the badge is not displayed.
    @Published public private(set) var newBadge: String? = nil

    init(
        persistentContainer: InboxPersistentContainer,
        seenWatermark: InboxSeenWatermark,
        configManager: ConfigManager,
        updateAppBadge: Bool
    ) {
        self.persistentContainer = persistentContainer
        self.seenWatermark = seenWatermark
        self.configManager = configManager
        self.updateAppBadge = updateAppBadge

        // Observe changes to badgeable hub items in Core Data
        observeHubItemChanges()

        // ...and to the inbox seen watermark, which lives in UserDefaults and so produces no
        // Core Data save of its own.
        observeSeenWatermarkChanges()

        // Config changes likewise produce no Core Data save. Recompute immediately so disabling
        // the inbox clears every badge surface and re-enabling it restores any unseen backlog.
        observeConfigChanges()
    }

    private var observerToken: NSObjectProtocol?
    private var watermarkCancellable: AnyCancellable?
    private var configCancellable: AnyCancellable?

    deinit {
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    /// Display text for a badge count: nil when there is nothing to show, the number itself up to
    /// ``maximumDisplayedCount``, and `"9+"` beyond it.
    nonisolated static func badgeText(for count: Int) -> String? {
        guard count > 0 else {
            return nil
        }
        guard count <= maximumDisplayedCount else {
            return "\(maximumDisplayedCount)+"
        }
        return String(count)
    }

    /// The numeric app-icon badge value for a badge count. The app icon badge cannot render "9+",
    /// so it is clamped to ``maximumDisplayedCount`` to stay consistent with the in-app badges.
    nonisolated static func appBadgeCount(for count: Int) -> Int {
        min(max(count, 0), maximumDisplayedCount)
    }

    private func observeHubItemChanges() {
        // Set up a NotificationCenter observer for Core Data changes
        observerToken = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: persistentContainer.viewContext,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateBadgeCount()
            }
        }

        // Initial badge count
        updateBadgeCount()
    }

    private func observeSeenWatermarkChanges() {
        watermarkCancellable = seenWatermark.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateBadgeCount()
                }
            }
    }

    private func observeConfigChanges() {
        configCancellable = configManager.$config
            .map(\.hub.isInboxEnabled)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateBadgeCount()
                }
            }
    }

    private func updateBadgeCount() {
        Task { @MainActor in
            let count = currentBadgeCount()

            self.newBadge = Self.badgeText(for: count)

            if self.updateAppBadge {
                let appBadgeCount = Self.appBadgeCount(for: count)
                os_log("Updating app badge number to %d", log: .hub, type: .info, appBadgeCount)
                try? await UNUserNotificationCenter.current().setBadgeCount(appBadgeCount)
            }
        }
    }

    private func currentBadgeCount() -> Int {
        guard configManager.config.hub.isInboxEnabled else {
            return 0
        }
        return persistentContainer.getBadgeCount(seenAfter: seenWatermark.lastSeenAt)
    }
}
