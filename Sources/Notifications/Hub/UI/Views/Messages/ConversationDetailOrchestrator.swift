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
import os.log

protocol ConversationDetailSyncing {
    func flushQueuedReplies(conversationID: UUID?) async -> Bool
    func syncForward(conversationID: UUID) async
    func markConversationRead(
        conversationID: UUID,
        lastReadReplyID: UUID?
    ) async -> Result<MarkConversationReadResponse, Error>
}

struct ConversationDetailOrchestrator {
    let sync: ConversationDetailSyncing
    let container: InboxPersistentContainer

    func onOpen(conversationID: UUID) async {
        await syncConversation(conversationID: conversationID)
    }

    func onPoll(conversationID: UUID) async {
        await syncConversation(conversationID: conversationID)
    }

    private func syncConversation(conversationID: UUID) async {
        let generation = await MainActor.run { container.conversationStoreGeneration }
        _ = await sync.flushQueuedReplies(conversationID: conversationID)
        let currentGeneration = await MainActor.run { container.conversationStoreGeneration }
        guard currentGeneration == generation else { return }
        await sync.syncForward(conversationID: conversationID)
    }

    // MARK: - Mark Read

    func onReachedBottom(conversationID: UUID) async {
        guard !Task.isCancelled else { return }

        // Fetch the latest reply of any sync state for the local update (the user has seen
        // everything including their own queued messages), and separately fetch the latest
        // server-confirmed reply (externalID == nil) whose UUID the server will recognise.
        struct ReadMarkers {
            var localReplyID: UUID
            var localCreatedAt: Date?
            var serverReplyID: UUID?
        }
        let markers = await MainActor.run { () -> ReadMarkers? in
            guard
                let latestReply = container.fetchLatestReply(conversationID: conversationID),
                let replyID = latestReply.id
            else { return nil }

            let serverReplyID = container.fetchLatestConfirmedReply(conversationID: conversationID)?.id
            return ReadMarkers(
                localReplyID: replyID,
                localCreatedAt: latestReply.createdAt,
                serverReplyID: serverReplyID
            )
        }
        guard let markers else { return }
        guard !Task.isCancelled else { return }

        await MainActor.run {
            container.markConversationAsRead(
                conversationID: conversationID,
                lastReadReplyID: markers.localReplyID,
                lastReadAt: markers.localCreatedAt
            )
        }
        guard !Task.isCancelled else { return }

        // Skip the server call if we have no server-confirmed reply ID to send.
        guard let serverReplyID = markers.serverReplyID else { return }

        let result = await sync.markConversationRead(
            conversationID: conversationID,
            lastReadReplyID: serverReplyID
        )
        guard !Task.isCancelled else { return }

        switch result {
        case .success(let response):
            // Apply server-authoritative timestamps. The server may return a slightly
            // different lastReadAt than the optimistic local value. The anti-regressive
            // guard in markConversationAsRead no-ops this if the values are identical.
            await MainActor.run {
                container.markConversationAsRead(
                    conversationID: response.conversationID,
                    lastReadReplyID: response.lastReadReplyID,
                    lastReadAt: response.lastReadAt
                )
            }
        case .failure(let error):
            os_log(
                "Failed to mark conversation read on server for %{private}@: %{private}@",
                log: .hub,
                type: .error,
                conversationID.uuidString,
                error.localizedDescription
            )
        }
    }
}

extension ReplySync: ConversationDetailSyncing {}
