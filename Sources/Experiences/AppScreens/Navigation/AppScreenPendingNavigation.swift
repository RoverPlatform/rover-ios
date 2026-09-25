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

import Dispatch
import Foundation

/// Identifies one detail→detail navigation *flow* — the sequence of pushes kicked off by a
/// single tap (or a rapid burst of taps before the first destination materializes). Two
/// tokens are never equal, even when minted back-to-back, so pending records enqueued under
/// one flow can never be claimed by a render driven from a different flow that happens to
/// target the same ``AppScreenAddress``.
///
/// ``AppScreensContentView``'s render pipeline mints one per navigation gesture and
/// threads it through to ``AppScreenPendingNavigationStore/enqueue(_:for:in:)``
/// and ``AppScreenPendingNavigationStore/claim(for:in:)``.
package struct AppScreensToken: Hashable {
    /// Real identity for this token. Two instances are equal only when they share the same
    /// `UUID`, which never happens across separate `init()` calls — this is what guarantees
    /// flow isolation in the store.
    package let id = UUID()

    package init() {}
}

/// A single resolved navigation, queued for a `SwiftUI` destination that has not yet
/// materialized. `AppScreensDriver`'s `navigate`/`selectSession` pipeline resolves a tap
/// into a session and a URL well before `NavigationStack` renders the corresponding
/// destination view; this record carries everything that resolution produced across that
/// gap so the eventual `makeScreen` call can pick up exactly where the pipeline left off.
package struct PendingNavigation {
    /// The (possibly warm, possibly newly created) session that will host this navigation.
    let session: AppScreenSession

    /// The absolute URL the navigation resolved to, after `href` resolution against the
    /// originating session's document URL.
    let resolvedURL: URL

    /// Optimistic data JSON to `show()` before the `.json` response lands, if the runtime
    /// supplied any.
    let optimisticDataJSON: String?

    /// Whether this navigation is a cold load (no warm session/document to reuse).
    let isColdLoad: Bool

    /// The `DispatchTime` the originating tap was recognized, used to measure the
    /// resolve-to-render latency this seam introduces.
    let tapTime: DispatchTime

    package init(
        session: AppScreenSession,
        resolvedURL: URL,
        optimisticDataJSON: String?,
        isColdLoad: Bool,
        tapTime: DispatchTime
    ) {
        self.session = session
        self.resolvedURL = resolvedURL
        self.optimisticDataJSON = optimisticDataJSON
        self.isColdLoad = isColdLoad
        self.tapTime = tapTime
    }
}

/// A FIFO holding pen for ``PendingNavigation`` records, bridging the gap between
/// `AppScreensDriver` resolving a navigation and `SwiftUI` materializing the destination
/// view that will claim it.
///
/// Records are keyed by the combination of an ``AppScreensToken`` and an
/// ``AppScreenAddress``: the address alone is not enough, because a rapid detail→detail tap
/// sequence can enqueue more than one record for the *same* template before either
/// destination renders, and two independent flows can legitimately target the same address
/// at the same time (e.g. two taps racing from two different hosts). Scoping every queue by
/// flow identity as well as address means one flow's renders can never dequeue another
/// flow's record, even when both resolve to the identical address.
@MainActor
package final class AppScreenPendingNavigationStore {
    /// Combines a flow and an address into one queue key. Two keys are equal only when both
    /// the flow token and the address match, which is what keeps concurrent flows sharing an
    /// address from cross-claiming each other's records.
    private struct QueueKey: Hashable {
        let token: AppScreensToken
        let address: AppScreenAddress
    }

    private var queuesByKey: [QueueKey: [PendingNavigation]] = [:]

    package init() {}

    /// Appends `record` to the back of the queue for `(flow, address)`. Called the moment a
    /// navigation resolves, before the corresponding destination has any chance to render.
    package func enqueue(_ record: PendingNavigation, for address: AppScreenAddress, in token: AppScreensToken) {
        let key = QueueKey(token: token, address: address)
        queuesByKey[key, default: []].append(record)
    }

    /// Removes and returns the oldest still-queued record for `(flow, address)`, or `nil` if
    /// none remain. FIFO order matters because an incremental multi-append burst (detail→detail
    /// before the first screen renders) must resolve in the same order the taps happened, not
    /// reversed.
    package func claim(for address: AppScreenAddress, in token: AppScreensToken) -> PendingNavigation? {
        let key = QueueKey(token: token, address: address)
        guard var queue = queuesByKey[key], !queue.isEmpty else {
            return nil
        }
        let record = queue.removeFirst()
        if queue.isEmpty {
            queuesByKey.removeValue(forKey: key)
        } else {
            queuesByKey[key] = queue
        }
        return record
    }

    /// Removes and returns every still-queued record for `flow`, across all
    /// addresses — the records a rendered destination never claimed before the flow
    /// ended. FIFO order is preserved within each address's queue; order across
    /// distinct addresses is unspecified. Called by
    /// ``AppScreensDriver/release(_:)`` to tear down those sessions before
    /// purging the flow's registry entry, so no session enqueued-but-never-rendered
    /// is left retaining a web view forever.
    package func drain(in token: AppScreensToken) -> [PendingNavigation] {
        let keysToDrain = queuesByKey.keys.filter { $0.token == token }
        var drained: [PendingNavigation] = []
        for key in keysToDrain {
            guard let queue = queuesByKey.removeValue(forKey: key) else {
                continue
            }
            drained.append(contentsOf: queue)
        }
        return drained
    }
}
