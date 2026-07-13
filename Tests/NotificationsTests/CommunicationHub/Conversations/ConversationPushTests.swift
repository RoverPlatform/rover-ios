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

import XCTest

@testable import RoverNotifications

final class ConversationPushTests: InboxPersistentContainerTestCase {

    // MARK: - monotonic read-state tests

    func testStageConversationWritesReadFieldsForNewConversation() async throws {
        let conversationID = UUID()
        let now = Date()
        let readReplyID = UUID()

        let item = TestDataGenerator.makeConversationItem(
            id: conversationID,
            subject: "Default",
            lastReplyAt: now,
            lastIncomingReplyAt: now,
            lastReadAt: now,
            lastReadReplyID: readReplyID,
            lastReplyPreview: "preview",
            createdAt: now.addingTimeInterval(-60),
            updatedAt: now
        )

        try await MainActor.run {
            try container.stageConversation(item, participants: [])
            try container.viewContext.save()
        }

        let conversation = await MainActor.run { container.fetchConversation(id: conversationID) }
        XCTAssertEqual(conversation?.lastReadAt, now)
        XCTAssertEqual(conversation?.lastReadReplyID, readReplyID)
    }

    func testStageConversationAdvancesReadStateWhenIncomingReadStateIsNewer() async throws {
        let conversationID = UUID()
        let olderReadAt = Date().addingTimeInterval(-60)
        let newerReadAt = Date()
        let existingReadReplyID = UUID()
        let incomingReadReplyID = UUID()

        try await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = conversationID
            conv.createdAt = olderReadAt.addingTimeInterval(-3600)
            conv.updatedAt = olderReadAt
            conv.lastReadAt = olderReadAt
            conv.lastReadReplyID = existingReadReplyID
            try container.viewContext.save()
        }

        let item = TestDataGenerator.makeConversationItem(
            id: conversationID,
            subject: "Updated",
            lastReplyAt: newerReadAt,
            lastIncomingReplyAt: newerReadAt,
            lastReadAt: newerReadAt,
            lastReadReplyID: incomingReadReplyID,
            lastReplyPreview: "new preview",
            createdAt: olderReadAt.addingTimeInterval(-3600),
            updatedAt: newerReadAt
        )

        try await MainActor.run {
            try container.stageConversation(item, participants: [])
            try container.viewContext.save()
        }

        let conversation = await MainActor.run { container.fetchConversation(id: conversationID) }
        XCTAssertEqual(conversation?.subject, "Updated")
        XCTAssertEqual(conversation?.lastReadAt, newerReadAt)
        XCTAssertEqual(conversation?.lastReadReplyID, incomingReadReplyID)
    }

    func testStageConversationDoesNotRollBackReadStateWhenIncomingReadStateIsOlder() async throws {
        let conversationID = UUID()
        let newerReadAt = Date()
        let olderReadAt = newerReadAt.addingTimeInterval(-60)
        let incomingUpdatedAt = newerReadAt.addingTimeInterval(1)
        let existingReadReplyID = UUID()
        let incomingReadReplyID = UUID()

        try await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = conversationID
            conv.createdAt = olderReadAt.addingTimeInterval(-3600)
            conv.updatedAt = newerReadAt
            conv.lastReadAt = newerReadAt
            conv.lastReadReplyID = existingReadReplyID
            try container.viewContext.save()
        }

        let item = TestDataGenerator.makeConversationItem(
            id: conversationID,
            subject: "Updated",
            lastReplyAt: newerReadAt,
            lastIncomingReplyAt: newerReadAt,
            lastReadAt: olderReadAt,
            lastReadReplyID: incomingReadReplyID,
            lastReplyPreview: "new preview",
            createdAt: olderReadAt.addingTimeInterval(-3600),
            updatedAt: incomingUpdatedAt
        )

        try await MainActor.run {
            try container.stageConversation(item, participants: [])
            try container.viewContext.save()
        }

        let conversation = await MainActor.run { container.fetchConversation(id: conversationID) }
        XCTAssertEqual(conversation?.subject, "Updated")
        XCTAssertEqual(conversation?.lastReadAt, newerReadAt)
        XCTAssertEqual(conversation?.lastReadReplyID, existingReadReplyID)
    }

    func testStageConversationDoesNotClearReadStateWhenIncomingReadStateIsNil() async throws {
        let conversationID = UUID()
        let existingReadAt = Date()
        let incomingUpdatedAt = existingReadAt.addingTimeInterval(1)
        let existingReadReplyID = UUID()

        try await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = conversationID
            conv.createdAt = existingReadAt.addingTimeInterval(-3600)
            conv.updatedAt = existingReadAt
            conv.lastReadAt = existingReadAt
            conv.lastReadReplyID = existingReadReplyID
            try container.viewContext.save()
        }

        let item = ConversationItem(
            id: conversationID,
            subject: "Updated",
            lastReplyAt: existingReadAt,
            lastIncomingReplyAt: existingReadAt,
            lastIncomingParticipantID: nil,
            lastReadAt: nil,
            lastReadReplyID: nil,
            lastReplyPreview: "new preview",
            participantIDs: [],
            createdAt: existingReadAt.addingTimeInterval(-3600),
            updatedAt: incomingUpdatedAt
        )

        try await MainActor.run {
            try container.stageConversation(item, participants: [])
            try container.viewContext.save()
        }

        let conversation = await MainActor.run { container.fetchConversation(id: conversationID) }
        XCTAssertEqual(conversation?.subject, "Updated")
        XCTAssertEqual(conversation?.lastReadAt, existingReadAt)
        XCTAssertEqual(conversation?.lastReadReplyID, existingReadReplyID)
    }

    // MARK: - receiveFromPush tests

    func testReceiveFromPushHandlesConversationPush() async {
        let conversationID = UUID(uuidString: "019cbce7-86de-7610-94f0-cf590c499243")!
        let replyID = UUID(uuidString: "019cbe27-287b-7d82-a1a0-7ed7bc204cf1")!
        let participantID = "07c18e88-7ae4-48e2-a1c4-c5d992f0a964"
        let dateString = "2026-03-05T13:19:23.260Z"

        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": [
                    "id": conversationID.uuidString,
                    "subject": "Test",
                    "lastReplyAt": dateString,
                    "lastIncomingReplyAt": dateString,
                    "lastReplyPreview": "a test notification",
                    "participantIDs": [participantID],
                    "createdAt": "2026-03-05T07:30:15.902Z",
                    "updatedAt": dateString
                ] as [String: Any],
                "reply": [
                    "id": replyID.uuidString,
                    "conversationID": conversationID.uuidString,
                    "senderType": "participant",
                    "participantID": participantID,
                    "content": [["type": "text", "text": "a test notification"]],
                    "createdAt": dateString
                ] as [String: Any],
                "participant": [
                    "id": participantID,
                    "name": "John Doe",
                    "updatedAt": dateString
                ] as [String: Any]
            ] as [String: Any]
        ]

        let result = await MainActor.run { container.receiveFromPush(userInfo: userInfo) }
        XCTAssertTrue(result, "receiveFromPush should return true for a conversation push")

        let conversation = await MainActor.run { container.fetchConversation(id: conversationID) }
        XCTAssertNotNil(conversation, "Conversation should be persisted")
        XCTAssertEqual(conversation?.subject, "Test")
        XCTAssertNil(conversation?.lastReadAt, "Push should not set lastReadAt")
        XCTAssertNil(conversation?.lastReadReplyID, "Push should not set lastReadReplyID")

        let reply = await MainActor.run { () -> Reply? in
            let request = Reply.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", replyID as CVarArg)
            request.fetchLimit = 1
            return try? container.viewContext.fetch(request).first
        }
        XCTAssertNotNil(reply, "Reply should be persisted")
        XCTAssertEqual(reply?.participantID, participantID)
        XCTAssertEqual(reply?.persistedContentBlocks, [.text(text: "a test notification")])

        let participant = await MainActor.run { () -> Participant? in
            let request = Participant.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", participantID)
            request.fetchLimit = 1
            return try? container.viewContext.fetch(request).first
        }
        XCTAssertNotNil(participant, "Participant should be persisted")
        XCTAssertEqual(participant?.name, "John Doe")
    }

    func testReceiveFromPushHandlesConversationPushFromBackgroundQueue() async {
        let conversationID = UUID(uuidString: "019cbce7-86de-7610-94f0-cf590c499243")!
        let replyID = UUID(uuidString: "019cbe27-287b-7d82-a1a0-7ed7bc204cf1")!
        let participantID = "07c18e88-7ae4-48e2-a1c4-c5d992f0a964"
        let dateString = "2026-03-05T13:19:23.260Z"

        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": [
                    "id": conversationID.uuidString,
                    "subject": "Test",
                    "lastReplyAt": dateString,
                    "lastIncomingReplyAt": dateString,
                    "lastReplyPreview": "a test notification",
                    "participantIDs": [participantID],
                    "createdAt": "2026-03-05T07:30:15.902Z",
                    "updatedAt": dateString
                ] as [String: Any],
                "reply": [
                    "id": replyID.uuidString,
                    "conversationID": conversationID.uuidString,
                    "senderType": "participant",
                    "participantID": participantID,
                    "content": [["type": "text", "text": "a test notification"]],
                    "createdAt": dateString
                ] as [String: Any],
                "participant": [
                    "id": participantID,
                    "name": "John Doe",
                    "updatedAt": dateString
                ] as [String: Any]
            ] as [String: Any]
        ]

        let result = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: self.container.receiveFromPush(userInfo: userInfo))
            }
        }
        XCTAssertTrue(result, "receiveFromPush should return true from a background queue caller")

        let conversation = await MainActor.run { container.fetchConversation(id: conversationID) }
        XCTAssertNotNil(conversation, "Conversation should be persisted")
        XCTAssertEqual(conversation?.subject, "Test")
    }

    func testReceiveFromPushReturnsFalseForNonRoverPush() async {
        let userInfo: [AnyHashable: Any] = ["foo": "bar"]
        let result = await MainActor.run { container.receiveFromPush(userInfo: userInfo) }
        XCTAssertFalse(result)
    }

    func testReceiveFromPushReturnsFalseForRoverPushWithoutConversationOrPost() async {
        let userInfo: [AnyHashable: Any] = ["rover": ["notification": ["id": "abc"]] as [String: Any]]
        let result = await MainActor.run { container.receiveFromPush(userInfo: userInfo) }
        XCTAssertFalse(result)
    }

    func testReceiveFromPushReturnsFalseForConversationPushMissingReplyKey() async {
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["id": UUID().uuidString] as [String: Any],
                "participant": ["id": "p1", "updatedAt": "2026-03-05T13:00:00.000Z"] as [String: Any]
                    // "reply" key intentionally absent
            ] as [String: Any]
        ]
        let result = await MainActor.run { container.receiveFromPush(userInfo: userInfo) }
        XCTAssertFalse(result)
    }

    func testReceiveFromPushReturnsFalseForConversationPushMissingParticipantKey() async {
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["id": UUID().uuidString] as [String: Any],
                "reply": ["id": UUID().uuidString] as [String: Any]
                    // "participant" key intentionally absent
            ] as [String: Any]
        ]
        let result = await MainActor.run { container.receiveFromPush(userInfo: userInfo) }
        XCTAssertFalse(result)
    }

    func testReceiveFromPushReturnsFalseWhenConversationDecodeFails() async {
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["not-valid": "data"] as [String: Any],
                "reply": ["id": UUID().uuidString] as [String: Any],
                "participant": ["id": "p1", "updatedAt": "2026-03-05T13:00:00.000Z"] as [String: Any]
            ] as [String: Any]
        ]
        let result = await MainActor.run { container.receiveFromPush(userInfo: userInfo) }
        XCTAssertFalse(result)
    }

    func testReceiveFromPushReturnsFalseWhenReplyConversationIDDoesNotMatchConversation() async {
        let conversationID = UUID(uuidString: "019cbce7-86de-7610-94f0-cf590c499243")!
        let replyConversationID = UUID(uuidString: "019cbce7-86de-7610-94f0-cf590c499244")!
        let replyID = UUID(uuidString: "019cbe27-287b-7d82-a1a0-7ed7bc204cf1")!
        let participantID = "07c18e88-7ae4-48e2-a1c4-c5d992f0a964"
        let dateString = "2026-03-05T13:19:23.260Z"

        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": [
                    "id": conversationID.uuidString,
                    "subject": "Test",
                    "lastReplyAt": dateString,
                    "lastIncomingReplyAt": dateString,
                    "lastReplyPreview": "a test notification",
                    "participantIDs": [participantID],
                    "createdAt": "2026-03-05T07:30:15.902Z",
                    "updatedAt": dateString
                ] as [String: Any],
                "reply": [
                    "id": replyID.uuidString,
                    "conversationID": replyConversationID.uuidString,
                    "senderType": "participant",
                    "participantID": participantID,
                    "content": [["type": "text", "text": "a test notification"]],
                    "createdAt": dateString
                ] as [String: Any],
                "participant": [
                    "id": participantID,
                    "name": "John Doe",
                    "updatedAt": dateString
                ] as [String: Any]
            ] as [String: Any]
        ]

        let result = await MainActor.run { container.receiveFromPush(userInfo: userInfo) }
        XCTAssertFalse(result)

        let conversation = await MainActor.run { container.fetchConversation(id: conversationID) }
        XCTAssertNil(conversation, "Conversation should not be persisted when reply conversationID mismatches")

        let reply = await MainActor.run { () -> Reply? in
            let request = Reply.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", replyID as CVarArg)
            request.fetchLimit = 1
            return try? container.viewContext.fetch(request).first
        }
        XCTAssertNil(reply, "Reply should not be persisted when conversationID mismatches")
    }

    func testReceiveFromPushConversationDoesNotRollbackForOutOfOrderPushes() async {
        let conversationID = UUID(uuidString: "019cbce7-86de-7610-94f0-cf590c499243")!
        let participantID = "07c18e88-7ae4-48e2-a1c4-c5d992f0a964"
        let newerReplyID = UUID(uuidString: "019cbe27-287b-7d82-a1a0-7ed7bc204cf1")!
        let olderReplyID = UUID(uuidString: "019cbe27-287b-7d82-a1a0-7ed7bc204cf2")!
        let newerDateString = "2026-03-05T13:19:23.260Z"
        let olderDateString = "2026-03-05T13:18:23.260Z"

        let newerPush: [AnyHashable: Any] = [
            "rover": [
                "conversation": [
                    "id": conversationID.uuidString,
                    "subject": "New Subject",
                    "lastReplyAt": newerDateString,
                    "lastIncomingReplyAt": newerDateString,
                    "lastReplyPreview": "new preview",
                    "participantIDs": [participantID],
                    "createdAt": "2026-03-05T07:30:15.902Z",
                    "updatedAt": newerDateString
                ] as [String: Any],
                "reply": [
                    "id": newerReplyID.uuidString,
                    "conversationID": conversationID.uuidString,
                    "senderType": "participant",
                    "participantID": participantID,
                    "content": [["type": "text", "text": "new reply"]],
                    "createdAt": newerDateString
                ] as [String: Any],
                "participant": [
                    "id": participantID,
                    "name": "Support",
                    "updatedAt": newerDateString
                ] as [String: Any]
            ] as [String: Any]
        ]

        let olderPush: [AnyHashable: Any] = [
            "rover": [
                "conversation": [
                    "id": conversationID.uuidString,
                    "subject": "Old Subject",
                    "lastReplyAt": olderDateString,
                    "lastIncomingReplyAt": olderDateString,
                    "lastReplyPreview": "old preview",
                    "participantIDs": [participantID],
                    "createdAt": "2026-03-05T07:30:15.902Z",
                    "updatedAt": olderDateString
                ] as [String: Any],
                "reply": [
                    "id": olderReplyID.uuidString,
                    "conversationID": conversationID.uuidString,
                    "senderType": "participant",
                    "participantID": participantID,
                    "content": [["type": "text", "text": "old reply"]],
                    "createdAt": olderDateString
                ] as [String: Any],
                "participant": [
                    "id": participantID,
                    "name": "Support",
                    "updatedAt": olderDateString
                ] as [String: Any]
            ] as [String: Any]
        ]

        let newerResult = await MainActor.run { container.receiveFromPush(userInfo: newerPush) }
        XCTAssertTrue(newerResult)

        // Capture the stored dates after the newer push so assertions use the same
        // decoded values rather than an independently-parsed date string.
        let conversationAfterNewerPush = await MainActor.run { container.fetchConversation(id: conversationID) }
        let expectedLastReplyAt = conversationAfterNewerPush?.lastReplyAt
        let expectedLastIncomingReplyAt = conversationAfterNewerPush?.lastIncomingReplyAt
        let expectedUpdatedAt = conversationAfterNewerPush?.updatedAt

        let olderResult = await MainActor.run { container.receiveFromPush(userInfo: olderPush) }
        XCTAssertTrue(olderResult)

        // The second push is older and should not replace latest conversation fields.
        let conversation = await MainActor.run { container.fetchConversation(id: conversationID) }
        XCTAssertEqual(conversation?.subject, "New Subject")
        XCTAssertEqual(conversation?.lastReplyPreview, "new preview")
        XCTAssertEqual(conversation?.lastReplyAt, expectedLastReplyAt)
        XCTAssertEqual(conversation?.lastIncomingReplyAt, expectedLastIncomingReplyAt)
        XCTAssertEqual(conversation?.updatedAt, expectedUpdatedAt)
    }

    func testReceiveFromPushConversationPreservesExistingMetadataWhenUpdatedAtTies() async {
        let conversationID = UUID(uuidString: "019cbce7-86de-7610-94f0-cf590c499243")!
        let participantID = "07c18e88-7ae4-48e2-a1c4-c5d992f0a964"
        let firstReplyID = UUID(uuidString: "019cbe27-287b-7d82-a1a0-7ed7bc204cf1")!
        let secondReplyID = UUID(uuidString: "019cbe27-287b-7d82-a1a0-7ed7bc204cf2")!
        let sharedDateString = "2026-03-05T13:19:23.260Z"

        let initialPush: [AnyHashable: Any] = [
            "rover": [
                "conversation": [
                    "id": conversationID.uuidString,
                    "subject": "Original Subject",
                    "lastReplyAt": sharedDateString,
                    "lastIncomingReplyAt": sharedDateString,
                    "lastReplyPreview": "original preview",
                    "participantIDs": [participantID],
                    "createdAt": "2026-03-05T07:30:15.902Z",
                    "updatedAt": sharedDateString
                ] as [String: Any],
                "reply": [
                    "id": firstReplyID.uuidString,
                    "conversationID": conversationID.uuidString,
                    "senderType": "participant",
                    "participantID": participantID,
                    "content": [["type": "text", "text": "original reply"]],
                    "createdAt": sharedDateString
                ] as [String: Any],
                "participant": [
                    "id": participantID,
                    "name": "Support",
                    "updatedAt": sharedDateString
                ] as [String: Any]
            ] as [String: Any]
        ]

        let tiedPush: [AnyHashable: Any] = [
            "rover": [
                "conversation": [
                    "id": conversationID.uuidString,
                    "subject": "New Subject",
                    "lastReplyAt": sharedDateString,
                    "lastIncomingReplyAt": sharedDateString,
                    "lastReplyPreview": "new preview",
                    "participantIDs": [participantID],
                    "createdAt": "2026-03-05T07:30:15.902Z",
                    "updatedAt": sharedDateString
                ] as [String: Any],
                "reply": [
                    "id": secondReplyID.uuidString,
                    "conversationID": conversationID.uuidString,
                    "senderType": "participant",
                    "participantID": participantID,
                    "content": [["type": "text", "text": "new reply"]],
                    "createdAt": sharedDateString
                ] as [String: Any],
                "participant": [
                    "id": participantID,
                    "name": "Support",
                    "updatedAt": sharedDateString
                ] as [String: Any]
            ] as [String: Any]
        ]

        let initialResult = await MainActor.run { container.receiveFromPush(userInfo: initialPush) }
        XCTAssertTrue(initialResult)

        let tiedResult = await MainActor.run { container.receiveFromPush(userInfo: tiedPush) }
        XCTAssertTrue(tiedResult)

        let conversation = await MainActor.run { container.fetchConversation(id: conversationID) }
        XCTAssertEqual(conversation?.subject, "Original Subject")
        XCTAssertEqual(conversation?.lastReplyPreview, "original preview")
    }

    func testReceiveFromPushConversationDoesNotOverwriteLocalReadState() async throws {
        let conversationID = UUID(uuidString: "019cbce7-86de-7610-94f0-cf590c499243")!
        let existingReadReplyID = UUID()
        let existingReadAt = Date(timeIntervalSince1970: 1_000_000)
        let dateString = "2026-03-05T13:19:23.260Z"
        let participantID = "07c18e88-7ae4-48e2-a1c4-c5d992f0a964"
        let replyID = UUID(uuidString: "019cbe27-287b-7d82-a1a0-7ed7bc204cf1")!

        // Pre-seed conversation with existing read state
        try await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = conversationID
            conv.createdAt = existingReadAt
            conv.updatedAt = existingReadAt
            conv.lastReadAt = existingReadAt
            conv.lastReadReplyID = existingReadReplyID
            try container.viewContext.save()
        }

        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": [
                    "id": conversationID.uuidString,
                    "subject": "Updated",
                    "lastReplyAt": dateString,
                    "lastIncomingReplyAt": dateString,
                    "lastReplyPreview": "new reply",
                    "participantIDs": [participantID],
                    "createdAt": "2026-03-05T07:30:15.902Z",
                    "updatedAt": dateString
                ] as [String: Any],
                "reply": [
                    "id": replyID.uuidString,
                    "conversationID": conversationID.uuidString,
                    "senderType": "participant",
                    "participantID": participantID,
                    "content": [["type": "text", "text": "new reply"]],
                    "createdAt": dateString
                ] as [String: Any],
                "participant": [
                    "id": participantID,
                    "name": "Support",
                    "updatedAt": dateString
                ] as [String: Any]
            ] as [String: Any]
        ]

        _ = await MainActor.run { container.receiveFromPush(userInfo: userInfo) }

        let conversation = await MainActor.run { container.fetchConversation(id: conversationID) }
        // Local read state preserved
        XCTAssertEqual(conversation?.lastReadAt, existingReadAt)
        XCTAssertEqual(conversation?.lastReadReplyID, existingReadReplyID)
        // Subject updated
        XCTAssertEqual(conversation?.subject, "Updated")
    }
}
