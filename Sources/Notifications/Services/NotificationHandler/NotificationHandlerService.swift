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

import RoverFoundation
import UserNotifications
import os.log

class NotificationHandlerService: NotificationHandler {
    let dispatcher: Dispatcher
    let influenceTracker: InfluenceTracker
    typealias NotificationActionProvider = (Notification) -> Action?
    typealias URLActionProvider = (URL) -> Action?

    let notificationActionProvider: NotificationActionProvider
    let openURLActionProvider: URLActionProvider
    let replySync: any ReplySending
    let inboxPersistentContainer: InboxPersistentContainer?
    let notificationCenter: DeliveredNotificationCenter

    init(
        dispatcher: Dispatcher,
        influenceTracker: InfluenceTracker,
        notificationActionProvider: @escaping NotificationActionProvider,
        openURLActionProvider: @escaping URLActionProvider,
        replySync: any ReplySending,
        inboxPersistentContainer: InboxPersistentContainer?,
        notificationCenter: DeliveredNotificationCenter = .live
    ) {
        self.dispatcher = dispatcher
        self.influenceTracker = influenceTracker
        self.notificationActionProvider = notificationActionProvider
        self.openURLActionProvider = openURLActionProvider
        self.replySync = replySync
        self.inboxPersistentContainer = inboxPersistentContainer
        self.notificationCenter = notificationCenter
    }

    func handle(_ response: UNNotificationResponse, completionHandler: (() -> Void)?) -> Bool {
        // Always persist any bundled Hub payload from the notification, regardless of action type.
        if let persistentContainer = inboxPersistentContainer {
            _ = persistentContainer.receiveFromPush(
                userInfo: response.notification.request.content.userInfo
            )
        }

        // Detect inline reply BEFORE clearing the influence tracker — an inline reply
        // is not an app open and must not reset the influence attribution window.
        if response.actionIdentifier == NotificationCategories.inlineReplyAction {
            let userText = (response as? UNTextInputNotificationResponse)?.userText ?? ""
            let userInfo = response.notification.request.content.userInfo
            // Handle the inline reply asynchronously and call the completion handler
            // once the reply flow finishes.
            Task(priority: .userInitiated) {
                await self.handleInlineReply(
                    actionIdentifier: response.actionIdentifier,
                    userText: userText,
                    userInfo: userInfo,
                    completionHandler: completionHandler
                )
            }
            return true
        }

        // Normal tap: clear influence window and dispatch the open-app action.
        influenceTracker.clearLastReceivedNotification()
        guard let action = action(for: response) else {
            return false
        }
        dispatcher.dispatch(action) {
            DispatchQueue.main.async { completionHandler?() }
        }
        return true
    }

    func action(for response: UNNotificationResponse) -> Action? {
        if let notification = response.notification.roverNotification {
            return notificationActionProvider(notification)
        }

        if let url = response.notification.roverActionURL {
            return openURLActionProvider(url)
        }

        return nil
    }

    // MARK: - Inline reply (internal for testability)

    /// Handles an inline text reply without opening the app.
    ///
    /// Declared `internal` (not `private`) so unit tests can drive it directly,
    /// because `UNTextInputNotificationResponse` has no public initialiser.
    ///
    /// `completionHandler` is called after inline-reply processing finishes.
    /// This keeps the handler behavior deterministic for lock-screen replies and avoids
    /// acknowledging completion before the reply path has run.
    func handleInlineReply(
        actionIdentifier: String,
        userText: String,
        userInfo: [AnyHashable: Any],
        completionHandler: (() -> Void)?
    ) async {
        guard actionIdentifier == NotificationCategories.inlineReplyAction else {
            return
        }

        // Notification payload should contain the Conversation ID otherwise it is malformed
        guard let conversationID = conversationID(from: userInfo) else {
            os_log(
                "Inline reply: failed to extract conversation ID from payload; dropping reply.",
                log: .notifications,
                type: .error
            )
            await MainActor.run { completionHandler?() }
            return
        }

        // Notification payload should contain the Reply ID otherwise it is malformed
        guard let replyID = replyID(from: userInfo) else {
            os_log(
                "Inline reply: failed to extract reply ID from payload; dropping reply.",
                log: .notifications,
                type: .error
            )
            await MainActor.run { completionHandler?() }
            return
        }

        let trimmedText = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            await MainActor.run { completionHandler?() }
            return
        }

        // Mark the conversation as read in Core Data BEFORE inserting the optimistic reply.
        // This prevents the badge from flickering up when sendReply saves the optimistic reply,
        // because the conversation will already be read when RoverBadge recomputes the count.
        await replySync.markConversationReadLocally(
            conversationID: conversationID,
            lastReadReplyID: replyID
        )

        await replySync.sendReply(conversationID: conversationID, text: trimmedText)?.value
        // Sync the read state to the server. Failure is logged; the server will re-sync on next foreground.
        let markReadResult = await replySync.markConversationRead(conversationID: conversationID)
        if case .failure(let error) = markReadResult {
            os_log(
                "Inline reply: mark-read sync failed: %{private}@",
                log: .notifications,
                type: .error,
                String(describing: error)
            )
        }
        await MainActor.run { completionHandler?() }
        await clearDeliveredNotifications(for: conversationID)
    }

    // MARK: - Foreground presentation

    func willPresent(
        userInfo: [AnyHashable: Any],
        displayedConversationID: UUID?
    ) -> UNNotificationPresentationOptions {
        if let id = conversationID(from: userInfo),
            id == displayedConversationID
        {
            return []
        }
        return defaultNotificationPresentationOptions
    }

    func clearDeliveredNotifications(for conversationID: UUID) async {
        let notifications = await notificationCenter.getDeliveredNotifications()
        let delivered = notifications.map {
            (
                identifier: $0.request.identifier,
                threadIdentifier: $0.request.content.threadIdentifier,
                userInfo: $0.request.content.userInfo
            )
        }
        let identifiers = identifiersToRemove(from: delivered, for: conversationID)
        notificationCenter.removeDeliveredNotifications(identifiers)
    }

    // MARK: - Helpers

    /// Declared `internal` for testability — `UNNotification` has no public initialiser.
    func identifiersToRemove(
        from delivered: [(identifier: String, threadIdentifier: String, userInfo: [AnyHashable: Any])],
        for conversationID: UUID
    ) -> [String] {
        let uuidString = conversationID.uuidString
        // ConversationNotificationEnricher sets threadIdentifier from a raw JSON string
        // (typed String, not UUID), so the value is lowercase. uppercased() is load-bearing.
        return delivered.compactMap { entry in
            guard
                entry.threadIdentifier.uppercased() == uuidString
                    || self.conversationID(from: entry.userInfo) == conversationID
            else { return nil }
            return entry.identifier
        }
    }

    /// Extracts the conversation UUID from an APNs userInfo dict.
    /// Declared `internal` for testability.
    func conversationID(from userInfo: [AnyHashable: Any]) -> UUID? {
        uuidFromRoverPayload(userInfo, key: "conversation")
    }

    /// Extracts the reply UUID from an APNs userInfo dict.
    /// Declared `internal` for testability.
    func replyID(from userInfo: [AnyHashable: Any]) -> UUID? {
        uuidFromRoverPayload(userInfo, key: "reply")
    }

    private func uuidFromRoverPayload(_ userInfo: [AnyHashable: Any], key: String) -> UUID? {
        guard
            let rover = userInfo["rover"] as? [AnyHashable: Any],
            let dict = rover[key] as? [AnyHashable: Any],
            let idString = dict["id"] as? String
        else { return nil }
        return UUID(uuidString: idString)
    }
}

public extension UNNotification {
    /// Decode the Rover notification in the APNS UNNotification, if it contains one.
    var roverNotification: Notification? {
        guard
            let data = try? JSONSerialization.data(withJSONObject: self.request.content.userInfo, options: [])
        else {
            return nil
        }

        struct Payload: Decodable {
            struct Rover: Decodable {
                var notification: Notification
            }
            var rover: Rover
        }

        do {
            return try JSONDecoder.default.decode(Payload.self, from: data).rover.notification
        } catch {
            return nil
        }
    }

    var roverActionURL: URL? {
        guard let data = try? JSONSerialization.data(withJSONObject: self.request.content.userInfo, options: []) else {
            return nil
        }

        struct Payload: Decodable {
            struct Rover: Decodable {
                struct Action: Decodable {
                    var url: URL
                }

                var action: Action
            }

            var rover: Rover
        }

        do {
            return try JSONDecoder.default.decode(Payload.self, from: data).rover.action.url
        } catch {
            return nil
        }
    }
}
