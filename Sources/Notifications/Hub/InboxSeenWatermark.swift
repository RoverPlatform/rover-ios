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
import Foundation
import RoverFoundation
import os.log

/// Persists how far through the inbox the user has seen — the "seen watermark".
///
/// The watermark holds the newest item activity timestamp the user has been shown — post
/// `receivedAt` or conversation reply activity — or, before they have ever opened the inbox, the
/// device instant the watermark was seeded or reset at.
///
/// The Hub badge counts an item only when it is *both* unread and has activity after this instant.
/// Read state alone is a per-item flag that is only ever cleared by opening each individual item,
/// so a user who scrolls their inbox without tapping anything keeps a large badge forever; worse,
/// an app updating into a build that badges unread items would surface the user's entire synced
/// history at once. The watermark makes "seen" a property of the inbox visit, so opening the inbox
/// zeroes the badge regardless of how many items were tapped. Read state remains as the other half
/// of the rule so that an item opened from a push tap or deep link — which never shows the inbox,
/// and so never moves the watermark — still stops badging on its own.
///
/// `markSeen(upTo:)` never reads `Date()`: the watermark only ever advances to a timestamp
/// observed on a stored item. The badge compares against those same stored timestamps, so writing
/// the value the comparison uses keeps the two sides consistent by construction — and a monotonic
/// observed-value watermark can never mark an item the user has not had in front of them as seen.
/// Seeding and `reset()` write device time instead, because at those moments there are no stored
/// items to reference.
///
/// ## Fresh install
///
/// The first read of a never-persisted watermark seeds it with the current moment (and writes it
/// back), so every item already in — or about to be back-filled into — the store predates the
/// watermark and the badge starts at zero. This is the same nil-coalesce-and-persist idiom
/// `VersionTrackerService` uses to detect its first run.
///
/// ## Observability
///
/// Writes land in `UserDefaults`, which produces no `NSManagedObjectContextDidSave`, so
/// `RoverBadge` cannot learn about them from its Core Data observer. `publisher` therefore exists
/// purely so `RoverBadge` has a second recompute trigger; it replays the current value on
/// subscription, which doubles as the initial badge computation.
///
/// ## Isolation
///
/// Deliberately not `@MainActor`: `Rover.resetHub()` is a nonisolated public API that must be able
/// to reset the watermark, and adding isolation there would change a public signature. `UserDefaults`
/// and `CurrentValueSubject` are each individually thread-safe, but that is not enough on its own:
/// `markSeen(upTo:)` therefore takes a lock so that comparing against the current watermark,
/// persisting, and publishing happen as one atomic step. That is what makes writes monotone: without
/// it, two concurrent marks could both pass the comparison and the one carrying the older instant
/// could land last, clobbering a newer persisted watermark and silently re-badging items the user has
/// already seen. `@unchecked` is required only because `PersistedValue` is not `Sendable`.
final class InboxSeenWatermark: @unchecked Sendable {
    /// `UserDefaults` key, following the `io.rover.<module>.<thing>` convention.
    static let defaultStorageKey = "io.rover.notifications.inboxLastSeenAt"

    private let persisted: PersistedValue<Date>
    private let subject: CurrentValueSubject<Date, Never>

    /// Serializes watermark writes. `subject.send` runs inside the lock, which is safe because the only
    /// subscriber (`RoverBadge`) merely recomputes the badge count and never calls back in here.
    private let lock = NSLock()

    init(userDefaults: UserDefaults = .standard, storageKey: String = InboxSeenWatermark.defaultStorageKey) {
        let persisted = PersistedValue<Date>(storageKey: storageKey, userDefaults: userDefaults)
        self.persisted = persisted

        guard let existing = persisted.value else {
            let seeded = Date()
            persisted.value = seeded
            self.subject = CurrentValueSubject(seeded)
            os_log("No inbox seen watermark found — seeding it with the current time", log: .hub, type: .info)
            return
        }

        self.subject = CurrentValueSubject(existing)
    }

    /// The newest item activity the user has been shown — or the seed/reset instant, before any
    /// inbox visit. Unread items with activity strictly after it count toward the badge.
    var lastSeenAt: Date {
        subject.value
    }

    /// Emits the current watermark on subscription, then every subsequent change.
    var publisher: AnyPublisher<Date, Never> {
        subject.eraseToAnyPublisher()
    }

    /// Advances the watermark to the newest item the user has been shown, persists it, and notifies
    /// observers.
    ///
    /// Called when the inbox appears, when it disappears, when items land in the store while it is on
    /// screen, and when the app is backgrounded from the inbox — the later calls absorb items that
    /// arrived after the list was first revealed. Use `reset()` for store or identity resets, where
    /// the watermark must be allowed to move backwards.
    ///
    /// - Parameter newestActivityAt: The newest activity timestamp among the posts and conversations
    ///   currently in the store — this *is* the new watermark, not a floor under some device-clock
    ///   value (see the note on the type). Whenever the inbox has been seen, every item currently in
    ///   the store has been seen too, so marking up to the newest one can never over-mark: it only
    ///   marks items that are already on screen. `nil` — an empty inbox — is a no-op: there is
    ///   nothing to absorb, and the watermark stays where the seed, the last reset, or the previous
    ///   visit left it.
    func markSeen(upTo newestActivityAt: Date?) {
        lock.withLock {
            // Clamp, never regress: the caller passes whatever happens to be newest in the store
            // right now, which an eviction, a reset, or a stale snapshot can make *older* than what
            // the user has already seen. Moving the watermark backwards would re-badge those items.
            guard let newestActivityAt, newestActivityAt > subject.value else { return }
            persisted.value = newestActivityAt
            subject.send(newestActivityAt)
        }
    }

    /// Resets the watermark to the current device time, even when the existing watermark is ahead.
    ///
    /// This is reserved for store and identity resets. Unlike ordinary seen marks, a reset must
    /// clear a future watermark so newly synced content for the new identity can badge normally.
    /// It is also one of the two places (with seeding) that writes device time rather than an
    /// observed item timestamp, because the store it is wiping is the only thing that could have
    /// supplied one.
    func reset() {
        lock.withLock {
            let resetAt = Date()
            persisted.value = resetAt
            subject.send(resetAt)
        }
    }
}
