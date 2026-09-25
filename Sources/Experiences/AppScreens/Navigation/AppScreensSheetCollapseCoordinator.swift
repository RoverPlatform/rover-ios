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
import UIKit
import os.log

/// Collapses an embedded (tab-hosted) App Screens sheet stack for an
/// `openURL {dismiss:true}` deep link, then opens the URL exactly once.
///
/// One instance per top-level flow (created by `AppScreensHostView`, threaded
/// down the view tree). Nested sheets are separate flows/boxes, so this is passed
/// explicitly rather than read from the environment. It only ever nulls its own
/// bottom sheet's binding — never the Hub's shared `NavigationPath` or another flow.
///
/// Conforms to `ObservableObject` (no `@Published` members) purely so
/// `AppScreensHostView` can own it as a `@StateObject` for a stable identity across
/// SwiftUI value-view recreation — the same lifetime guarantee `AppScreensTokenBox` relies
/// on. It never triggers view updates.
@MainActor
package final class AppScreensSheetCollapseCoordinator: ObservableObject {
    private struct BottomSheet {
        let id: UUID
        let clear: () -> Void
    }

    private var bottomSheet: BottomSheet?
    private var pendingOpenURL: URL?
    private var didOpenForPending = false

    private let open: @MainActor (URL) -> Void
    private let scheduleBackstop: (@escaping () -> Void) -> Void

    init(
        // `open` is `@MainActor`-isolated: the whole coordinator runs on the main actor and
        // every invocation site does too, so the default can reference the main-actor
        // `UIApplication.shared` without a nonisolated-context warning.
        open: @escaping @MainActor (URL) -> Void = { url in
            UIApplication.shared.open(url) { success in
                if !success {
                    os_log(
                        "openURL failed to open %{private}@",
                        log: .appScreens,
                        type: .error,
                        url.absoluteString
                    )
                }
            }
        },
        scheduleBackstop: @escaping (@escaping () -> Void) -> Void = { work in
            Task { @MainActor in work() }
        }
    ) {
        self.open = open
        self.scheduleBackstop = scheduleBackstop
    }

    /// Records the bottom (first-presented) sheet's clear closure. Deeper presenters
    /// call this too but do not overwrite the recorded one; each gets a distinct id.
    @discardableResult
    func registerBottomSheet(clear: @escaping () -> Void) -> UUID {
        let id = UUID()
        guard bottomSheet == nil else {
            return id
        }
        bottomSheet = BottomSheet(id: id, clear: clear)
        return id
    }

    /// Clears the recorded bottom sheet only if `id` matches — so a stale/older sheet's
    /// dismissal can never drop a newer registration.
    func deregisterBottomSheet(id: UUID) {
        guard bottomSheet?.id == id else {
            return
        }
        bottomSheet = nil
    }

    /// `dismiss:false` → open in place. `dismiss:true` with a sheet up → stash the URL,
    /// trigger the collapse, and schedule a next-tick backstop. No sheet → open now.
    func handleOpenExternal(_ url: URL, dismiss: Bool) {
        guard dismiss, let bottom = bottomSheet else {
            open(url)
            return
        }
        pendingOpenURL = url
        didOpenForPending = false
        bottom.clear()
        scheduleBackstop { [weak self] in
            self?.flushPendingIfNeeded()
        }
    }

    /// Called from the bottom sheet's `.sheet(onDismiss:)`. Opens the pending URL the
    /// first time it (or the backstop) sees one; later calls are no-ops.
    func sheetDidDismiss() {
        flushPendingIfNeeded()
    }

    private func flushPendingIfNeeded() {
        guard let url = pendingOpenURL, !didOpenForPending else {
            return
        }
        didOpenForPending = true
        pendingOpenURL = nil
        bottomSheet = nil
        open(url)
    }
}
