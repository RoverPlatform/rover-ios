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

import MobileCoreServices
import RoverFoundation
import UserNotifications
import os

private let helperLogger = Logger(subsystem: "io.rover.sdk", category: "NotificationExtension")

/// Use `NotificationExtensionHelper` from your `UNNotificationServiceExtension` to let Rover
/// finish processing a notification before delivery.
///
/// Create a mutable copy of the incoming content in your extension's
/// `didReceive(_:withContentHandler:)`.
///
/// Use `didReceive(_:withContent:withContentHandler:)`. This lets Rover hand Apple's enriched
/// `UNNotificationContent` back through your content handler, which is required when the system
/// replaces the original mutable content during communication-notification updates.
public class NotificationExtensionHelper {
    let userDefaults: UserDefaults
    let conversationEnricher: ConversationNotificationEnriching

    public init?(appGroup: String) {
        guard let userDefaults = UserDefaults(suiteName: appGroup) else {
            return nil
        }
        self.userDefaults = userDefaults
        self.conversationEnricher = ConversationNotificationEnricher.live
    }

    init(userDefaults: UserDefaults, conversationEnricher: ConversationNotificationEnriching) {
        self.userDefaults = userDefaults
        self.conversationEnricher = conversationEnricher
    }

    public var unreadNotifications: Int {
        return userDefaults.integer(forKey: "io.rover.unreadNotifications")
    }

    /// Applies Rover's standard notification-service-extension behavior in place.
    ///
    /// Call this overload when your extension only needs Rover's receipt tracking and media
    /// attachment handling on the mutable notification content provided by iOS.
    @discardableResult
    public func didReceive(_ request: UNNotificationRequest, withContent content: UNMutableNotificationContent) -> Bool
    {
        handleRoverNotification(for: request, withContent: content)
    }

    /// Applies Rover notification processing and delivers the final notification content.
    ///
    /// Call this overload when you want Rover to upgrade eligible conversation pushes into
    /// Apple's communication-notification presentation. Rover still applies its standard receipt
    /// tracking and media attachment handling before it calls your content handler with the final
    /// notification content.
    public func didReceive(
        _ request: UNNotificationRequest,
        withContent content: UNMutableNotificationContent,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        Task {
            let deliveredContent = await notificationContent(for: request, withContent: content)
            helperLogger.debug(
                "delivering content for request \(request.identifier, privacy: .public) with title \(deliveredContent.title, privacy: .private)"
            )
            contentHandler(deliveredContent)
        }
    }

    /// Applies Rover notification handling then attempts conversation-notification enrichment.
    ///
    /// Always returns usable content: returns the enriched content on success, or `content`
    /// (the mutable copy) as a fallback when the push is not a conversation push or enrichment fails.
    func notificationContent(
        for request: UNNotificationRequest,
        withContent content: UNMutableNotificationContent
    ) async -> UNNotificationContent {
        handleRoverNotification(for: request, withContent: content)

        // Communication notifications are sourced from the conversation-specific payload, not
        // from the standard `rover.notification` title/body metadata.
        guard let conversationPayload = ConversationPushPayload.from(userInfo: content.userInfo) else {
            return content
        }
        if let updatedContent = await conversationEnricher.enrichedContent(
            payload: conversationPayload,
            from: content
        ) {
            helperLogger.debug(
                "conversation enrichment succeeded for conversation \(conversationPayload.rover.conversation.id, privacy: .public)"
            )
            return updatedContent
        }

        return content
    }

    /// Stores the delivered-notification receipt used by Rover's influence tracker.
    ///
    /// Communication notifications still pass through this bookkeeping path today because the
    /// branch intentionally preserves the existing Rover notification contract while layering the
    /// new conversation semantics on top.
    func setLastReceivedNotification(notificationID: String, campaignID: String) {
        struct NotificationReceipt: Encodable {
            var notificationID: String
            var campaignID: String
            var receivedAt: Date
        }

        let now = Date()
        let lastReceivedNotification = NotificationReceipt(
            notificationID: notificationID, campaignID: campaignID, receivedAt: now)

        guard let data = try? PropertyListEncoder().encode(lastReceivedNotification) else {
            clearLastReceivedNotification()
            return
        }

        userDefaults.set(data, forKey: "io.rover.lastReceivedNotification")
    }

    @discardableResult
    func handleRoverNotification(
        for request: UNNotificationRequest,
        withContent content: UNMutableNotificationContent
    ) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: content.userInfo, options: []) else {
            helperLogger.error(
                "failed to serialize userInfo for request \(request.identifier, privacy: .public)"
            )
            clearLastReceivedNotification()
            return false
        }

        guard let payload = try? JSONDecoder.default.decode(RoverNotificationPushPayload.self, from: data) else {
            helperLogger.debug(
                "payload is not a standard Rover notification for request \(request.identifier, privacy: .public)"
            )
            // Only clear the receipt if this is definitely not a Rover push.
            // Conversation pushes that lack rover.notification must not
            // erase an existing campaign receipt — the user may open that campaign notification
            // shortly after, and the influenced-open attribution would be lost.
            if ConversationPushPayload.from(userInfo: content.userInfo) == nil {
                clearLastReceivedNotification()
            }
            return false
        }

        let notification = payload.rover.notification
        setLastReceivedNotification(notificationID: notification.id, campaignID: notification.campaignID)
        helperLogger.debug(
            "decoded Rover notification \(notification.id, privacy: .public) for campaign \(notification.campaignID, privacy: .public)"
        )

        // Keep Rover's standard notification behavior intact before attempting any
        // conversation-specific upgrade path.
        if let attachment = notification.attachment {
            helperLogger.debug(
                "attempting media attachment from \(attachment.url.absoluteString, privacy: .private)"
            )
            attachMedia(from: attachment.url, to: content)
        }
        return true
    }

    func clearLastReceivedNotification() {
        userDefaults.removeObject(forKey: "io.rover.lastReceivedNotification")
    }

    // attachMedia is fairly clear, so silence the function length warning.
    // swiftlint:disable function_body_length
    func attachMedia(from attachmentURL: URL, to content: UNMutableNotificationContent) {
        guard let scheme = attachmentURL.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return
        }

        typealias DownloadResult = (attachmentLocation: URL?, response: URLResponse?, error: Error?)

        let downloadAttachment: (URL) -> DownloadResult = { url in
            var fileLocation: URL?
            var response: URLResponse?
            var error: Error?

            let semaphore = DispatchSemaphore(value: 0)
            URLSession.shared.downloadTask(with: url) {
                fileLocation = $0
                response = $1
                error = $2
                semaphore.signal()
            }.resume()
            _ = semaphore.wait(timeout: .distantFuture)

            return (fileLocation, response, error)
        }

        let downloadResult = downloadAttachment(attachmentURL)

        if let error = downloadResult.error {
            helperLogger.error("media attachment download failed: \(error.logDescription, privacy: .public)")
            return
        }

        guard let attachmentLocation = downloadResult.attachmentLocation else {
            return
        }

        let utiFromURL: (URL) -> CFString? = { url in
            let ext = url.pathExtension
            if ext.isEmpty {
                return nil
            }
            let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext as CFString, nil)?
                .takeRetainedValue()

            if let uti = uti {
                // return nil if dynamic UTI is assigned, which means the platform could not infer a type from the path extension.
                if String(uti).starts(with: "dyn") {
                    return nil
                }
            }

            return uti
        }

        let utiFromResponse: (URLResponse?) -> CFString? = { response in
            guard let mimeType = (response as? HTTPURLResponse)?.allHeaderFields["Content-Type"] as? String else {
                return nil
            }

            return UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)?
                .takeRetainedValue()
        }

        guard let uti = utiFromURL(attachmentURL) ?? utiFromResponse(downloadResult.response) else {
            return
        }

        let acceptedTypes = [
            kUTTypeAudioInterchangeFileFormat, kUTTypeWaveformAudio, kUTTypeMP3, kUTTypeMPEG4Audio, kUTTypeJPEG,
            kUTTypeGIF, kUTTypePNG, kUTTypeMPEG, kUTTypeMPEG2Video, kUTTypeMPEG4, kUTTypeAVIMovie,
        ]

        guard acceptedTypes.contains(uti) else {
            return
        }

        let options = [UNNotificationAttachmentOptionsTypeHintKey: uti as String]
        if let attachment = try? UNNotificationAttachment(identifier: "", url: attachmentLocation, options: options) {
            content.attachments = [attachment]
        }
    }
}
