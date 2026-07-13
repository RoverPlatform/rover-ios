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

import CoreData
import Foundation
import os.log

extension InboxPersistentContainer {
    /// The kind of Hub content a push payload carries, or `nil` if it is not a Hub push.
    ///
    /// Single source of truth for "is this a Hub push?" — used both by `receiveFromPush` to decide
    /// what to insert and by `HubSyncCoordinator`'s 410 reset to decide which delivered
    /// notifications to clear. Keeping one predicate prevents the insert side and the clear side
    /// from drifting apart (a drift that would let a stale, tappable notification survive a reset
    /// and re-insert previous-identity content on tap).
    enum HubPushKind {
        case post
        case conversation
    }

    nonisolated static func hubPushKind(from userInfo: [AnyHashable: Any]) -> HubPushKind? {
        guard let rover = userInfo["rover"] as? [AnyHashable: Any] else {
            return nil
        }
        if rover["post"] is [AnyHashable: Any] {
            return .post
        }
        if rover["conversation"] is [AnyHashable: Any] {
            return .conversation
        }
        return nil
    }

    /// Returns true if the processed APNs notification user info was handled by Rover.
    func receiveFromPush(userInfo: [AnyHashable: Any]) -> Bool {
        // Push delegate callbacks are not guaranteed to arrive on the main thread,
        // but this path persists via viewContext and must return synchronously.
        if Thread.isMainThread {
            return receiveFromPushOnMainQueue(userInfo: userInfo)
        } else {
            return DispatchQueue.main.sync {
                receiveFromPushOnMainQueue(userInfo: userInfo)
            }
        }
    }

    private func receiveFromPushOnMainQueue(userInfo: [AnyHashable: Any]) -> Bool {
        assert(Thread.isMainThread, "receiveFromPushOnMainQueue should be called on main thread")

        guard let roverObject = userInfo["rover"] as? [AnyHashable: Any] else {
            return false
        }

        switch Self.hubPushKind(from: userInfo) {
        case .post:
            guard let postObject = roverObject["post"] as? [AnyHashable: Any] else {
                return false
            }
            return receivePostFromPush(postObject: postObject)
        case .conversation:
            guard let conversationObject = roverObject["conversation"] as? [AnyHashable: Any],
                let replyObject = roverObject["reply"] as? [AnyHashable: Any],
                let participantObject = roverObject["participant"] as? [AnyHashable: Any]
            else {
                return false
            }
            return receiveConversationFromPush(
                conversationObject: conversationObject,
                replyObject: replyObject,
                participantObject: participantObject
            )
        case .none:
            return false
        }
    }

    private func receivePostFromPush(postObject: [AnyHashable: Any]) -> Bool {
        assert(Thread.isMainThread, "receivePostFromPush should be called on main thread")

        guard let postItem = decodePushItem(postObject, as: PostItem.self, label: "PostItem") else {
            return false
        }

        os_log(
            "InboxPersistentContainer.receiveFromPush: received post item, storing it",
            log: .notifications,
            type: .debug
        )

        MainActor.assumeIsolated {
            _ = self.createOrUpdatePost(from: postItem)
        }

        do {
            try self.viewContext.save()
            os_log(
                "InboxPersistentContainer.receivePostFromPush: successfully saved post received from push",
                log: .hub,
                type: .debug
            )
        } catch {
            os_log(
                "InboxPersistentContainer.receivePostFromPush: failed to save Core Data context: %@",
                log: .hub,
                type: .error,
                error.localizedDescription
            )
            return false
        }

        return true
    }

    private func receiveConversationFromPush(
        conversationObject: [AnyHashable: Any],
        replyObject: [AnyHashable: Any],
        participantObject: [AnyHashable: Any]
    ) -> Bool {
        assert(Thread.isMainThread, "receiveConversationFromPush should be called on main thread")

        guard
            let conversationItem = decodePushItem(
                conversationObject,
                as: ConversationItem.self,
                label: "ConversationItem"
            ),
            let replyItem = decodePushItem(replyObject, as: ReplyItem.self, label: "ReplyItem"),
            let participantItem = decodePushItem(
                participantObject,
                as: ParticipantItem.self,
                label: "ParticipantItem"
            )
        else {
            return false
        }

        os_log(
            "InboxPersistentContainer.receiveFromPush: received conversation push for %{private}@, storing it",
            log: .hub,
            type: .debug,
            conversationItem.id.uuidString
        )

        guard replyItem.conversationID == conversationItem.id else {
            os_log(
                "InboxPersistentContainer.receiveFromPush: reply %{private}@ has mismatched conversationID %{private}@ for conversation %{private}@",
                log: .hub,
                type: .error,
                replyItem.id.uuidString,
                replyItem.conversationID.uuidString,
                conversationItem.id.uuidString
            )
            return false
        }

        let upsertResult = MainActor.assumeIsolated { () -> Result<Void, Error> in
            do {
                let conversation = try stageConversation(conversationItem, participants: [participantItem])
                try stageReply(replyItem, into: conversation)
                return .success(())
            } catch {
                viewContext.rollback()
                return .failure(error)
            }
        }

        guard case .success = upsertResult else {
            os_log(
                "InboxPersistentContainer.receiveFromPush: failed to upsert conversation or reply for %{private}@",
                log: .hub,
                type: .error,
                conversationItem.id.uuidString
            )
            return false
        }

        do {
            try viewContext.save()
            os_log(
                "InboxPersistentContainer.receiveFromPush: successfully saved conversation push for %{private}@",
                log: .hub,
                type: .debug,
                conversationItem.id.uuidString
            )
        } catch {
            os_log(
                "InboxPersistentContainer.receiveFromPush: failed to save Core Data context: %@",
                log: .hub,
                type: .error,
                error.localizedDescription
            )
            return false
        }

        return true
    }

    private func decodePushItem<T: Decodable>(
        _ object: [AnyHashable: Any],
        as type: T.Type,
        label: String
    ) -> T? {
        do {
            let data = try JSONSerialization.data(withJSONObject: object)
            return try JSONDecoder.default.decode(type, from: data)
        } catch {
            os_log(
                "InboxPersistentContainer.receiveFromPush: failed to decode %{public}@: %@",
                log: .hub,
                type: .error,
                label,
                error.localizedDescription
            )
            return nil
        }
    }
}
