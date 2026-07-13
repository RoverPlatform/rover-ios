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

/// Minimal interface required by ``NotificationHandlerService`` for sending a reply.
///
/// Conformed to by ``ReplySync``. Exists so the handler can be unit-tested
/// without a full Core Data + HTTP stack.
protocol ReplySending: Sendable {
    @discardableResult
    func sendReply(conversationID: UUID, text: String) async -> Task<Bool, Never>?
    /// Marks a conversation as read. `lastReadReplyID` is omitted — the server marks
    /// as read up to the current time. Result is discarded by callers; failure re-syncs on next foreground.
    func markConversationRead(conversationID: UUID) async -> Result<MarkConversationReadResponse, Error>
    /// Marks the conversation as read locally in Core Data using the given reply ID.
    ///
    /// Called during inline-reply handling so the badge is updated before the optimistic
    /// reply is inserted — preventing the badge from flickering up after the send.
    ///
    /// **Required ordering:** Call this before `sendReply` so the conversation is already
    /// marked read when `sendReply` saves the optimistic reply and RoverBadge recomputes
    /// the badge count.
    func markConversationReadLocally(conversationID: UUID, lastReadReplyID: UUID) async
}
