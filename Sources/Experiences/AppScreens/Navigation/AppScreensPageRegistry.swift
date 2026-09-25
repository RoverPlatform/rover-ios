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

import Foundation

/// Reproduces `AppScreensDriver.handlePop`'s keep-warm-vs-teardown decision as a
/// standalone, testable unit that the SwiftUI teardown hook drives.
///
/// A template pushed while an instance of the same template is already on the stack is
/// an *ephemeral* (detail→detail) push: it is torn down when popped, while the warm
/// template beneath it stays reusable. A template popped as the last instance is kept
/// *warm* off-stack so the next navigation to it reuses the (in production) live web view.
@MainActor
package final class AppScreensPageRegistry {
    package enum PopOutcome: Equatable {
        case keptWarm
        case tornDown
    }

    private var onStackCounts: [AppScreenAddress: Int] = [:]
    private var warmAddresses: Set<AppScreenAddress> = []

    package init() {}

    /// Records a screen being created/pushed. Returns whether it is ephemeral (the same
    /// template was already on the stack).
    @discardableResult
    package func didPush(_ address: AppScreenAddress) -> Bool {
        let alreadyOnStack = (onStackCounts[address] ?? 0) > 0
        onStackCounts[address, default: 0] += 1
        guard alreadyOnStack else {
            // A fresh or warm-reused push consumes any warm mark (the session is now live).
            warmAddresses.remove(address)
            return false
        }
        return true
    }

    /// Records a screen leaving the stack. Ephemerals (a second instance of a template
    /// still on the stack) tear down; the last instance of a template is kept warm.
    @discardableResult
    package func didPop(_ address: AppScreenAddress) -> PopOutcome {
        let count = onStackCounts[address] ?? 0
        guard count > 0 else {
            return .tornDown
        }
        let remaining = count - 1
        if remaining == 0 {
            onStackCounts.removeValue(forKey: address)
        } else {
            onStackCounts[address] = remaining
        }
        guard remaining == 0 else {
            // Another instance of this template is still on the stack — the popped one
            // was the ephemeral detail→detail duplicate.
            return .tornDown
        }
        warmAddresses.insert(address)
        return .keptWarm
    }

    package func isOnStack(_ address: AppScreenAddress) -> Bool {
        (onStackCounts[address] ?? 0) > 0
    }

    package func isWarm(_ address: AppScreenAddress) -> Bool {
        warmAddresses.contains(address)
    }
}
