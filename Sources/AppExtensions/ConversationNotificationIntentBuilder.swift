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

/// Converts Rover's conversation payload into the SiriKit intent Apple uses to style
/// communication notifications.
///
/// The returned `INSendMessageIntent` is not about sending a reply from the device. It is the
/// metadata Apple needs to understand "this notification represents an incoming message from this
/// sender in this conversation."
struct ConversationNotificationIntentBuilder {
    func canMakeIntent(from payload: ConversationPushPayload) -> Bool {
        ConversationNotificationPreviewTextExtractor.previewText(
            from: payload.rover.reply.content
        ) != nil
    }

    func makeIntent(from payload: ConversationPushPayload, avatar: INImage?) -> INSendMessageIntent? {
        guard
            let text = ConversationNotificationPreviewTextExtractor.previewText(
                from: payload.rover.reply.content
            )
        else {
            return nil
        }

        let handle = INPersonHandle(value: payload.rover.participant.id, type: .unknown)
        let sender = INPerson(
            personHandle: handle,
            nameComponents: nil,
            displayName: payload.rover.participant.name,
            image: avatar,
            contactIdentifier: nil,
            customIdentifier: payload.rover.participant.id
        )

        return INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: text,
            speakableGroupName: nil,
            // This is the thread identity Apple uses when grouping and surfacing the message as a
            // conversation notification.
            conversationIdentifier: payload.rover.conversation.id,
            serviceName: nil,
            sender: sender,
            attachments: nil
        )
    }
}
