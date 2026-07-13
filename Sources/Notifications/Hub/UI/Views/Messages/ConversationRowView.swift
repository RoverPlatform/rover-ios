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

import SwiftUI
import os.log

struct ConversationRowView: View {
    @ObservedObject var conversation: Conversation
    @Binding var navigationPath: NavigationPath

    var body: some View {
        if let participant = displayParticipant {
            ConversationRowBody(
                conversation: conversation,
                participant: participant,
                navigationPath: $navigationPath
            )
        } else {
            MessageRowView(
                isRead: conversation.isRead,
                avatarURL: nil,
                senderKind: .participant,
                senderName: nil,
                date: conversation.lastReplyAt ?? conversation.createdAt,
                subject: conversation.subject,
                previewText: conversation.lastReplyPreview
            ) {
                guard let id = conversation.id else {
                    os_log("Conversation missing ID, cannot navigate", log: .hub, type: .error)
                    return
                }
                navigationPath.append(ConversationDestination(conversationID: id))
            }
        }
    }

    // Returns nil when no incoming reply has been recorded or the participant
    // hasn't synced locally yet.
    private var displayParticipant: Participant? {
        guard let participantID = conversation.lastIncomingParticipantID else {
            return nil
        }
        let allParticipants = (conversation.participants as? Set<Participant>) ?? []
        return allParticipants.first(where: { $0.id == participantID && !$0.isDeleted })
    }
}

private struct ConversationRowBody: View {
    @ObservedObject var conversation: Conversation
    @ObservedObject var participant: Participant
    @Binding var navigationPath: NavigationPath

    var body: some View {
        MessageRowView(
            isRead: conversation.isRead,
            avatarURL: participant.avatarURL.flatMap(URL.init(string:)),
            senderKind: .participant,
            senderName: participant.name,
            date: conversation.lastReplyAt ?? conversation.createdAt,
            subject: conversation.subject,
            previewText: conversation.lastReplyPreview
        ) {
            guard let id = conversation.id else {
                os_log("Conversation missing ID, cannot navigate", log: .hub, type: .error)
                return
            }
            navigationPath.append(ConversationDestination(conversationID: id))
        }
    }
}
