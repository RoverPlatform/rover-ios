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
import Intents
import UserNotifications
import os

private let enricherLogger = Logger(subsystem: "io.rover.sdk", category: "NotificationExtension")

/// Wraps Apple's interaction donation so tests can verify the orchestration without invoking the
/// real Siri donation APIs.
protocol ConversationNotificationDonating {
    func donate(_ interaction: INInteraction) async throws
}

/// Wraps Apple's `UNNotificationContent.updating(from:)` seam, which returns the upgraded
/// notification content used for communication-style presentation.
protocol ConversationNotificationContentUpdating {
    func updatedContent(
        from content: UNNotificationContent,
        using intent: INSendMessageIntent
    ) throws -> UNNotificationContent
}

/// High-level abstraction for the full conversation-notification upgrade path.
///
/// `NotificationExtensionHelper` depends on this protocol so helper tests can focus on fallback
/// behavior without also exercising avatar loading, intent donation, or Apple's content update
/// API.
protocol ConversationNotificationEnriching {
    func enrichedContent(
        payload: ConversationPushPayload,
        from content: UNMutableNotificationContent
    ) async -> UNNotificationContent?
}

/// Orchestrates the communication-notification upgrade pipeline.
///
/// Flow:
/// 1. Set the notification's thread identifier.
/// 2. Confirm the reply can be represented as a message intent.
/// 3. Resolve the sender avatar (remote image or generated initials).
/// 4. Donate the interaction so iOS recognizes the message semantics.
/// 5. Ask Apple to return the upgraded `UNNotificationContent`.
struct ConversationNotificationEnricher: ConversationNotificationEnriching {
    let avatarLoader: ConversationNotificationAvatarLoading
    let donor: ConversationNotificationDonating
    let contentUpdater: ConversationNotificationContentUpdating
    let intentBuilder: ConversationNotificationIntentBuilder

    func enrichedContent(
        payload: ConversationPushPayload,
        from content: UNMutableNotificationContent
    ) async -> UNNotificationContent? {
        enricherLogger.debug(
            "attempting conversation enrichment for conversation \(payload.rover.conversation.id, privacy: .public)"
        )
        // Normalize the notification's grouping key so iOS stacks messages by Rover conversation ID.
        content.threadIdentifier = payload.rover.conversation.id

        guard intentBuilder.canMakeIntent(from: payload) else {
            enricherLogger.error(
                "failed to build message intent for conversation \(payload.rover.conversation.id, privacy: .public)"
            )
            return nil
        }

        let avatar = await avatarLoader.avatar(
            participantID: payload.rover.participant.id,
            participantName: payload.rover.participant.name,
            avatarURL: payload.rover.participant.avatarURL
        )

        guard let intent = intentBuilder.makeIntent(from: payload, avatar: avatar) else {
            enricherLogger.error(
                "failed to build message intent for conversation \(payload.rover.conversation.id, privacy: .public)"
            )
            return nil
        }

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming

        do {
            try await donor.donate(interaction)
            enricherLogger.debug(
                "donated interaction for conversation \(payload.rover.conversation.id, privacy: .public)"
            )
            let updatedContent = try contentUpdater.updatedContent(from: content, using: intent)
            enricherLogger.debug(
                "updated notification content from message intent for conversation \(payload.rover.conversation.id, privacy: .public)"
            )
            return updatedContent
        } catch {
            enricherLogger.error(
                "conversation enrichment failed for conversation \(payload.rover.conversation.id, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }
}

/// Production adapter over `INInteraction.donate()`.
struct LiveConversationNotificationDonor: ConversationNotificationDonating {
    func donate(_ interaction: INInteraction) async throws {
        try await interaction.donate()
    }
}

/// Production adapter over `UNNotificationContent.updating(from:)`.
struct LiveConversationNotificationContentUpdater: ConversationNotificationContentUpdating {
    func updatedContent(
        from content: UNNotificationContent,
        using intent: INSendMessageIntent
    ) throws -> UNNotificationContent {
        try content.updating(from: intent)
    }
}

extension ConversationNotificationEnricher {
    static let live = ConversationNotificationEnricher(
        avatarLoader: ConversationNotificationAvatarProvider.live,
        donor: LiveConversationNotificationDonor(),
        contentUpdater: LiveConversationNotificationContentUpdater(),
        intentBuilder: ConversationNotificationIntentBuilder()
    )
}
