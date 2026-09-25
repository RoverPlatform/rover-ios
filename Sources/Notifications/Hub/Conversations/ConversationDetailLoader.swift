//
// Copyright (c) 2026, Rover Labs, Inc. All rights reserved.
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

/// Makes sure a conversation is in the local store before its detail screen relies on it.
///
/// A deep link or push tap can address a conversation the list has not synced yet (a fresh
/// install, or a link fired before the list's forward poll ran). Rather than dismiss the screen,
/// fetch it on demand the way the post detail screen does: forward sync first, then the history
/// backfill, checking the store after each. Mirrors the Android detail screen's forward sync plus
/// backfill.
@MainActor
struct ConversationDetailLoader {
    private let container: InboxPersistentContainer
    private let conversationSync: ConversationSync

    init(container: InboxPersistentContainer, conversationSync: ConversationSync) {
        self.container = container
        self.conversationSync = conversationSync
    }

    /// Returns true once the conversation exists locally, fetching it if needed. A local hit
    /// makes no request. Returns false only when the forward sync and the backfill have both run
    /// and the conversation is still absent, or when the caller was cancelled part way: the
    /// forward sync honours cancellation itself, but the backfill starts its own task, so it
    /// must not be started for a screen that has already gone.
    func ensureAvailable(conversationID: UUID) async -> Bool {
        if isAvailable(conversationID) {
            return true
        }

        await conversationSync.syncForward()
        if isAvailable(conversationID) {
            return true
        }
        guard !Task.isCancelled else {
            return false
        }

        await conversationSync.syncBackward()
        return isAvailable(conversationID)
    }

    private func isAvailable(_ conversationID: UUID) -> Bool {
        container.fetchConversation(id: conversationID) != nil
    }
}
