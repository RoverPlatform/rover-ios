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
import UserNotifications

@testable import RoverAppExtensions

enum ConversationPushTestFixture {
    static let appGroup = "test.NotificationExtensionHelperTests"

    static func request(userInfo: [AnyHashable: Any]) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        return UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    }

    static func genericRoverUserInfo() -> [AnyHashable: Any] {
        [
            "rover": [
                "notification": [
                    "id": "notif-1",
                    "campaignID": "campaign-1"
                ]
            ]
        ]
    }

    static func conversationUserInfo() -> [AnyHashable: Any] {
        [
            "rover": [
                "notification": [
                    "id": "notif-conv-1",
                    "campaignID": "campaign-conv-1"
                ],
                "conversation": [
                    "id": "conv-123",
                    "subject": "Order inquiry"
                ],
                "reply": [
                    "id": "reply-456",
                    "conversationID": "conv-123",
                    "senderType": "participant",
                    "participantID": "participant-uuid",
                    "content": [
                        [
                            "type": "text",
                            "text": "Hi, I have a question"
                        ]
                    ],
                    "createdAt": "2026-02-27T12:00:00Z"
                ],
                "participant": [
                    "id": "participant-uuid",
                    "name": "Jane Doe",
                    "avatarURL": "https://example.com/avatar.jpg"
                ]
            ]
        ]
    }

    static func conversationUserInfoWithoutNotification() -> [AnyHashable: Any] {
        [
            "rover": [
                "conversation": [
                    "id": "conv-123",
                    "subject": "Order inquiry"
                ],
                "reply": [
                    "id": "reply-456",
                    "conversationID": "conv-123",
                    "senderType": "participant",
                    "participantID": "participant-uuid",
                    "content": [
                        [
                            "type": "text",
                            "text": "Hi, I have a question"
                        ]
                    ],
                    "createdAt": "2026-02-27T12:00:00Z"
                ],
                "participant": [
                    "id": "participant-uuid",
                    "name": "Jane Doe",
                    "avatarURL": "https://example.com/avatar.jpg"
                ]
            ]
        ]
    }

    static func clearDefaults() {
        UserDefaults(suiteName: appGroup)?
            .removePersistentDomain(forName: appGroup)
    }
}
