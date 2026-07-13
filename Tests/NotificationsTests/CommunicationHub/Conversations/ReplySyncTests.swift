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
import XCTest

@testable import RoverData
@testable import RoverNotifications

final class ReplySyncTests: HubSyncTestBase {
    var replySync: ReplySync!
    var conversationID: UUID!

    override func setUp() async throws {
        try await super.setUp()
        httpClient.authContext.enableSDKAuthIDTokenRefreshForDomain(pattern: "*.test.com")
        conversationID = UUID()
        await MainActor.run {
            let conv = Conversation(context: testContainer.viewContext)
            conv.id = conversationID
            conv.createdAt = Date()
            conv.updatedAt = Date()
            do {
                try testContainer.viewContext.save()
            } catch {
                XCTFail("Failed to seed conversation in setup: \(error)")
            }
        }
        replySync = ReplySync(
            persistentContainer: testContainer,
            hubSyncCoordinator: hubSyncCoordinator
        )
    }

    override func tearDown() async throws {
        replySync = nil
        conversationID = nil
        try await super.tearDown()
    }

    func testFirstSyncFetchesRepliesAndStoresCursors() async {
        let imageURL = URL(string: "https://cdn.example.com/reply.png")!
        URLProtocolMock.stubReplies(
            conversationID: conversationID,
            replies: [
                ReplyItem(
                    id: UUID(),
                    conversationID: conversationID,
                    senderType: .participant,
                    participantID: "participant-1",
                    content: [.text(text: "Hello"), .image(url: imageURL)],
                    createdAt: Date()
                )
            ],
            nextCursor: "fwd",
            nextBefore: "bwd",
            hasMore: false
        )

        await replySync.syncForward(conversationID: conversationID)

        let replies = await MainActor.run { () -> [Reply] in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "conversation.id == %@", self.conversationID as CVarArg)
            return (try? self.testContainer.viewContext.fetch(req)) ?? []
        }
        XCTAssertEqual(replies.count, 1)
        XCTAssertEqual(replies.first?.senderType, "participant")
        XCTAssertEqual(replies.first?.participantID, "participant-1")
        XCTAssertEqual(replies.first?.persistedContentBlocks, [.text(text: "Hello"), .image(url: imageURL)])

        let persistedBlocks = ((replies.first?.contentBlocks?.allObjects as? [ReplyContentBlock]) ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(persistedBlocks.count, 2)
        XCTAssertEqual(persistedBlocks[0].type, "text")
        XCTAssertEqual(persistedBlocks[0].text, "Hello")
        XCTAssertEqual(persistedBlocks[0].sortOrder, 0)
        XCTAssertEqual(persistedBlocks[1].type, "image")
        XCTAssertEqual(persistedBlocks[1].url, imageURL)
        XCTAssertEqual(persistedBlocks[1].sortOrder, 1)

        let syncStatus = await MainActor.run { self.testContainer.getReplySyncStatus(for: self.conversationID) }
        XCTAssertEqual(syncStatus?.cursor, "fwd")
        XCTAssertEqual(syncStatus?.backwardsCursor, "bwd")
    }

    func testRepliesRequestIncludesAuthorizationWhenUserIDPresent() async {
        mockUserInfoManager.mockUserID = "fan-123"
        httpClient.authContext.setSDKAuthenticationIDToken("identified-fan-token")

        var capturedAuthorization: String?
        URLProtocolMock.stub { request in
            guard let url = request.url, url.path.contains("/replies") else {
                return nil
            }
            capturedAuthorization = request.value(forHTTPHeaderField: "Authorization")
            return .success(object: RepliesSyncResponse(replies: [], nextCursor: nil, nextBefore: nil, hasMore: false))
        }

        await replySync.syncForward(conversationID: conversationID)

        XCTAssertEqual(capturedAuthorization, "Bearer identified-fan-token")
    }

    func testRepliesRequestWithoutTokenStillCallsServerWhenUserIDPresent() async {
        mockUserInfoManager.mockUserID = "fan-123"
        httpClient.authContext.clearSDKAuthenticationIDToken()

        var requestMade = false
        var capturedAuthorization: String?
        URLProtocolMock.stub { request in
            guard let url = request.url, url.path.contains("/replies") else {
                return nil
            }
            requestMade = true
            capturedAuthorization = request.value(forHTTPHeaderField: "Authorization")
            return .success(object: RepliesSyncResponse(replies: [], nextCursor: nil, nextBefore: nil, hasMore: false))
        }

        await replySync.syncForward(conversationID: conversationID)

        XCTAssertTrue(requestMade)
        XCTAssertNil(capturedAuthorization)
    }

    func testRepliesDecodeFallsBackToFanLocalParticipantIDWhenFanParticipantIDIsNull() throws {
        let replyID = UUID()
        let payload = """
            {
              "replies": [
                {
                  "id": "\(replyID.uuidString)",
                  "conversationID": "\(conversationID!.uuidString)",
                  "senderType": "fan",
                  "participantID": null,
                  "content": [{"type": "text", "text": "hello"}],
                  "createdAt": "2026-03-04T10:25:14.178Z"
                }
              ],
              "nextCursor": "cursor-1",
              "nextBefore": null,
              "hasMore": false
            }
            """

        let data = try XCTUnwrap(payload.data(using: .utf8))
        let decoded = try JSONDecoder.default.decode(RepliesSyncResponse.self, from: data)

        XCTAssertEqual(decoded.replies.count, 1)
        XCTAssertEqual(decoded.replies[0].senderType, .fan)
        XCTAssertNil(decoded.replies[0].participantID)
    }

    func testRepliesDecodeFailsWhenParticipantParticipantIDIsNull() throws {
        let replyID = UUID()
        let payload = """
            {
              "replies": [
                {
                  "id": "\(replyID.uuidString)",
                  "conversationID": "\(conversationID!.uuidString)",
                  "senderType": "participant",
                  "participantID": null,
                  "content": [{"type": "text", "text": "hello"}],
                  "createdAt": "2026-03-04T10:25:14.178Z"
                }
              ],
              "nextCursor": "cursor-1",
              "nextBefore": null,
              "hasMore": false
            }
            """

        let data = try XCTUnwrap(payload.data(using: .utf8))

        XCTAssertThrowsError(try JSONDecoder.default.decode(RepliesSyncResponse.self, from: data))
    }

    func testReplyItemDecodesExternalID() throws {
        let replyID = UUID()
        let payload = """
            {
              "replies": [
                {
                  "id": "\(replyID.uuidString)",
                  "conversationID": "\(conversationID!.uuidString)",
                  "senderType": "fan",
                  "content": [{"type": "text", "text": "hello"}],
                  "externalID": "ext-123",
                  "createdAt": "2026-03-04T10:25:14.178Z"
                }
              ],
              "nextCursor": null,
              "nextBefore": null,
              "hasMore": false
            }
            """

        let data = try XCTUnwrap(payload.data(using: .utf8))
        let decoded = try JSONDecoder.default.decode(RepliesSyncResponse.self, from: data)
        XCTAssertEqual(decoded.replies[0].externalID, "ext-123")
    }

    func testReplyItemDecodesNullExternalID() throws {
        let replyID = UUID()
        let payload = """
            {
              "replies": [
                {
                  "id": "\(replyID.uuidString)",
                  "conversationID": "\(conversationID!.uuidString)",
                  "senderType": "participant",
                  "participantID": "p-1",
                  "content": [{"type": "text", "text": "hello"}],
                  "externalID": null,
                  "createdAt": "2026-03-04T10:25:14.178Z"
                }
              ],
              "nextCursor": null,
              "nextBefore": null,
              "hasMore": false
            }
            """

        let data = try XCTUnwrap(payload.data(using: .utf8))
        let decoded = try JSONDecoder.default.decode(RepliesSyncResponse.self, from: data)
        XCTAssertNil(decoded.replies[0].externalID)
    }

    func testUpsertReplyMatchesOptimisticEntryByExternalID() async throws {
        let externalID = "ext-dedup"
        let serverReplyID = UUID()

        try await MainActor.run {
            let optimisticReply = Reply(context: testContainer.viewContext)
            optimisticReply.id = UUID()
            optimisticReply.conversation = testContainer.fetchConversation(id: conversationID)
            optimisticReply.senderType = "fan"
            optimisticReply.participantID = nil
            optimisticReply.createdAt = Date()
            optimisticReply.externalID = externalID
            optimisticReply.syncState = ReplySyncState.queued.rawValue
            optimisticReply.retryCount = 0
            optimisticReply.nextRetryAt = nil
            optimisticReply.lastSendError = nil

            let optimisticContentBlock = ReplyContentBlock(context: testContainer.viewContext)
            optimisticContentBlock.type = "text"
            optimisticContentBlock.text = "Queued"
            optimisticContentBlock.sortOrder = 0
            optimisticContentBlock.reply = optimisticReply
            try testContainer.viewContext.save()
        }

        let serverReply = ReplyItem(
            id: serverReplyID,
            conversationID: conversationID,
            senderType: .fan,
            participantID: "fan-server",
            content: [.text(text: "Confirmed")],
            externalID: externalID,
            createdAt: Date()
        )

        try await MainActor.run {
            guard let conversation = testContainer.fetchConversation(id: conversationID) else {
                XCTFail("Expected seeded conversation")
                return
            }
            try testContainer.stageReply(serverReply, into: conversation)
            try testContainer.viewContext.save()
        }

        let replies = await MainActor.run { () -> [Reply] in
            let request = Reply.fetchRequest()
            request.predicate = NSPredicate(format: "conversation.id == %@", self.conversationID as CVarArg)
            return (try? self.testContainer.viewContext.fetch(request)) ?? []
        }
        XCTAssertEqual(replies.count, 1, "Should replace optimistic entry, not create duplicate")
        XCTAssertEqual(replies.first?.id, serverReplyID)
        XCTAssertNil(replies.first?.externalID, "externalID should be cleared after confirmation")
        XCTAssertEqual(replies.first?.persistedContentBlocks, [.text(text: "Confirmed")])
    }

    func testForwardSyncAppendsNewReplies() async {
        let existingReplyID = UUID()
        URLProtocolMock.stubReplies(
            conversationID: conversationID,
            replies: [
                ReplyItem(
                    id: existingReplyID,
                    conversationID: conversationID,
                    senderType: .participant,
                    participantID: "participant-seeded",
                    content: [.text(text: "Existing")],
                    createdAt: Date()
                )
            ],
            nextCursor: "existing-cursor",
            nextBefore: nil,
            hasMore: false
        )
        await replySync.syncForward(conversationID: conversationID)

        URLProtocolMock.reset()
        URLProtocolMock.stubRepliesForCursor(
            conversationID: conversationID,
            cursor: "existing-cursor",
            replies: [
                ReplyItem(
                    id: UUID(),
                    conversationID: conversationID,
                    senderType: .fan,
                    participantID: "fan-1",
                    content: [
                        .text(
                            text: "Reply"
                        )
                    ],
                    createdAt: Date()
                )
            ],
            nextCursor: "new-cursor",
            nextBefore: nil,
            hasMore: false
        )

        await replySync.syncForward(conversationID: conversationID)

        let count = await MainActor.run { () -> Int in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "conversation.id == %@", self.conversationID as CVarArg)
            return (try? self.testContainer.viewContext.count(for: req)) ?? -1
        }
        XCTAssertEqual(count, 2, "Forward sync should append new replies without removing existing rows")

        let seededReplyStillExists = await MainActor.run { () -> Bool in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", existingReplyID as CVarArg)
            req.fetchLimit = 1
            return (try? self.testContainer.viewContext.fetch(req).first) != nil
        }
        XCTAssertTrue(seededReplyStillExists)

        let syncStatus = await MainActor.run { self.testContainer.getReplySyncStatus(for: self.conversationID) }
        XCTAssertEqual(syncStatus?.cursor, "new-cursor")
    }

    func testBackwardsSyncSetsHistoryComplete() async throws {
        try await MainActor.run {
            try testContainer.stageReplySyncStatus(
                for: conversationID,
                cursor: nil,
                backwardsCursor: "bwd-cursor",
                historyComplete: false
            )
        }
        URLProtocolMock.stubRepliesBackwards(
            conversationID: conversationID,
            before: "bwd-cursor",
            replies: [],
            nextBefore: nil,
            hasMore: false
        )

        await replySync.syncBackwards(conversationID: conversationID)

        let syncStatus = await MainActor.run { self.testContainer.getReplySyncStatus(for: self.conversationID) }
        XCTAssertEqual(syncStatus?.historyComplete, true)
    }

    func testUpsertDoesNotDuplicateReplies() async {
        let replyID = UUID()
        let item = ReplyItem(
            id: replyID,
            conversationID: conversationID,
            senderType: .participant,
            participantID: "participant-1",
            content: [.text(text: "Hi")],
            createdAt: Date()
        )
        URLProtocolMock.stubReplies(
            conversationID: conversationID,
            replies: [item],
            nextCursor: nil,
            nextBefore: nil,
            hasMore: false
        )
        await replySync.syncForward(conversationID: conversationID)

        URLProtocolMock.reset()
        URLProtocolMock.stubReplies(
            conversationID: conversationID,
            replies: [item],
            nextCursor: nil,
            nextBefore: nil,
            hasMore: false
        )
        await replySync.syncForward(conversationID: conversationID)

        let count = await MainActor.run { () -> Int in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "conversation.id == %@", self.conversationID as CVarArg)
            return (try? self.testContainer.viewContext.count(for: req)) ?? -1
        }
        XCTAssertEqual(count, 1, "Same reply synced twice should not duplicate")
    }

    func testForwardSyncPassesStoredCursorToRequest() async throws {
        try await MainActor.run {
            try testContainer.stageReplySyncStatus(
                for: conversationID,
                cursor: "stored-fwd",
                backwardsCursor: nil,
                historyComplete: false
            )
        }
        var capturedCursor: String?
        URLProtocolMock.stub { request in
            capturedCursor = request.url?.queryParameters?["cursor"]
            return .success(object: RepliesSyncResponse(replies: [], nextCursor: nil, nextBefore: nil, hasMore: false))
        }

        await replySync.syncForward(conversationID: conversationID)

        XCTAssertEqual(capturedCursor, "stored-fwd")
    }

    func testForwardSyncWithNoCursorFetchesFromStart() async {
        // No syncStatus stored — syncForward should still fetch (no cursor param).
        // This matters for push-triggered syncs that fire before the conversation is opened.
        var capturedCursor: String? = "sentinel"
        URLProtocolMock.stub { request in
            capturedCursor = request.url?.queryParameters?["cursor"]
            return .success(object: RepliesSyncResponse(replies: [], nextCursor: nil, nextBefore: nil, hasMore: false))
        }

        await replySync.syncForward(conversationID: conversationID)

        XCTAssertNil(capturedCursor, "syncForward with no stored cursor should fetch without a cursor param")
    }

    func testBackwardsSyncPassesStoredBackwardsCursorToRequest() async throws {
        try await MainActor.run {
            try testContainer.stageReplySyncStatus(
                for: conversationID,
                cursor: nil,
                backwardsCursor: "stored-bwd",
                historyComplete: false
            )
        }
        var capturedBefore: String?
        URLProtocolMock.stub { request in
            capturedBefore = request.url?.queryParameters?["before"]
            return .success(object: RepliesSyncResponse(replies: [], nextCursor: nil, nextBefore: nil, hasMore: false))
        }

        await replySync.syncBackwards(conversationID: conversationID)

        XCTAssertEqual(capturedBefore, "stored-bwd")
    }

    func testBackwardsSyncIsNoOpWhenHistoryComplete() async throws {
        try await MainActor.run {
            try testContainer.stageReplySyncStatus(
                for: conversationID,
                cursor: nil,
                backwardsCursor: "bwd",
                historyComplete: true
            )
        }
        var requestMade = false
        URLProtocolMock.stub { _ in
            requestMade = true
            return nil
        }

        await replySync.syncBackwards(conversationID: conversationID)

        XCTAssertFalse(requestMade, "Should not request when historyComplete")
    }

    func testUnknownContentBlockDecodesWithoutThrowingAndCapturesRawJSON() throws {
        let replyID = UUID()
        let payload = """
            {
              "replies": [
                {
                  "id": "\(replyID.uuidString)",
                  "conversationID": "\(conversationID!.uuidString)",
                  "senderType": "participant",
                  "participantID": "p-1",
                  "content": [{"type": "video", "url": "https://cdn.example.com/clip.mp4", "duration": 30}],
                  "createdAt": "2026-03-04T10:25:14.178Z"
                }
              ],
              "nextCursor": null,
              "nextBefore": null,
              "hasMore": false
            }
            """

        let data = try XCTUnwrap(payload.data(using: .utf8))
        let decoded = try JSONDecoder.default.decode(RepliesSyncResponse.self, from: data)

        XCTAssertEqual(decoded.replies.count, 1)
        guard case .unknown(let rawJSON) = decoded.replies[0].content.first else {
            XCTFail("Expected .unknown content block")
            return
        }
        XCTAssertTrue(rawJSON.contains("video"))
        XCTAssertTrue(rawJSON.contains("cdn.example.com/clip.mp4"))
    }

    func testUnknownContentBlockIsPersistedWithRawJSON() async throws {
        let replyID = UUID()
        let item = ReplyItem(
            id: replyID,
            conversationID: conversationID,
            senderType: .participant,
            participantID: "p-1",
            content: [.unknown(rawJSON: #"{"type":"video","url":"https://cdn.example.com/clip.mp4"}"#)],
            createdAt: Date()
        )

        try await MainActor.run {
            guard let conversation = testContainer.fetchConversation(id: conversationID) else {
                XCTFail("Expected seeded conversation")
                return
            }
            try testContainer.stageReply(item, into: conversation)
            try testContainer.viewContext.save()
        }

        let blocks = await MainActor.run { () -> [ReplyContentBlock] in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", replyID as CVarArg)
            req.fetchLimit = 1
            let reply = (try? self.testContainer.viewContext.fetch(req))?.first
            return (reply?.contentBlocks?.allObjects as? [ReplyContentBlock]) ?? []
        }

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks.first?.type, "unknown")
        XCTAssertTrue(blocks.first?.rawJSON?.contains("cdn.example.com/clip.mp4") == true)
        XCTAssertNil(blocks.first?.text)
        XCTAssertNil(blocks.first?.url)
    }

    func testUnknownContentBlockIsNotSurfacedInPersistedContentBlocks() async throws {
        let replyID = UUID()
        let item = ReplyItem(
            id: replyID,
            conversationID: conversationID,
            senderType: .participant,
            participantID: "p-1",
            content: [
                .text(text: "Hello"),
                .unknown(rawJSON: #"{"type":"video","url":"https://cdn.example.com/clip.mp4"}"#),
                .image(url: URL(string: "https://cdn.example.com/photo.jpg")!)
            ],
            createdAt: Date()
        )

        try await MainActor.run {
            guard let conversation = testContainer.fetchConversation(id: conversationID) else {
                XCTFail("Expected seeded conversation")
                return
            }
            try testContainer.stageReply(item, into: conversation)
            try testContainer.viewContext.save()
        }

        let surfaced = await MainActor.run { () -> [ContentBlock] in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", replyID as CVarArg)
            req.fetchLimit = 1
            return (try? self.testContainer.viewContext.fetch(req))?.first?.persistedContentBlocks ?? []
        }

        XCTAssertEqual(surfaced.count, 2, "Unknown block should be silently dropped")
        XCTAssertEqual(surfaced[0], .text(text: "Hello"))
        XCTAssertEqual(surfaced[1], .image(url: URL(string: "https://cdn.example.com/photo.jpg")!))
    }

    func testMarkConversationReadPostsReadCheckpoint() async {
        let lastReadReplyID = UUID()
        var capturedRequest: URLRequest?

        URLProtocolMock.stub { request in
            guard let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/read")
            else { return nil }

            capturedRequest = request

            return .success(
                object: MarkConversationReadResponse(
                    conversationID: self.conversationID,
                    lastReadAt: Date(),
                    lastReadReplyID: lastReadReplyID
                )
            )
        }

        let result = await replySync.markConversationRead(
            conversationID: conversationID,
            lastReadReplyID: lastReadReplyID
        )

        switch result {
        case .success(let response):
            XCTAssertEqual(response.conversationID, conversationID)
            XCTAssertEqual(response.lastReadReplyID, lastReadReplyID)
        case .failure(let error):
            XCTFail("Expected success, got error: \(error)")
        }

        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertTrue(
            capturedRequest?.url?.path.hasSuffix("/conversations/\(conversationID!.uuidString)/read") == true
        )

        guard let body = Self.jsonBody(from: capturedRequest) else {
            return
        }
        XCTAssertEqual(body["lastReadReplyID"] as? String, lastReadReplyID.uuidString)
    }

    func testMarkConversationReadIncludesUserIDWhenAvailable() async {
        mockUserInfoManager.mockUserID = "fan-123"

        let lastReadReplyID = UUID()
        var capturedUserID: String?
        URLProtocolMock.stub { request in
            guard let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/read")
            else { return nil }

            capturedUserID = url.queryParameters?["userID"]

            return .success(
                object: MarkConversationReadResponse(
                    conversationID: self.conversationID,
                    lastReadAt: Date(),
                    lastReadReplyID: lastReadReplyID
                )
            )
        }

        _ = await replySync.markConversationRead(
            conversationID: conversationID,
            lastReadReplyID: lastReadReplyID
        )

        XCTAssertEqual(capturedUserID, "fan-123")
    }

    func testMarkConversationReadIncludesAuthorizationWhenUserIDPresent() async {
        mockUserInfoManager.mockUserID = "fan-123"
        httpClient.authContext.setSDKAuthenticationIDToken("identified-fan-token")

        let lastReadReplyID = UUID()
        var capturedRequest: URLRequest?
        var capturedAuthorization: String?
        URLProtocolMock.stub { request in
            guard let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/read")
            else { return nil }

            capturedRequest = request
            capturedAuthorization = request.value(forHTTPHeaderField: "Authorization")

            return .success(
                object: MarkConversationReadResponse(
                    conversationID: self.conversationID,
                    lastReadAt: Date(),
                    lastReadReplyID: lastReadReplyID
                )
            )
        }

        _ = await replySync.markConversationRead(
            conversationID: conversationID,
            lastReadReplyID: lastReadReplyID
        )

        XCTAssertEqual(capturedAuthorization, "Bearer identified-fan-token")
        guard let body = Self.jsonBody(from: capturedRequest) else {
            return
        }
        XCTAssertEqual(body["lastReadReplyID"] as? String, lastReadReplyID.uuidString)
    }

    func testMarkConversationReadOmitsLastReadReplyIDWhenNil() async {
        var capturedRequest: URLRequest?
        URLProtocolMock.stub { request in
            guard let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/read")
            else { return nil }

            capturedRequest = request

            return .success(
                object: MarkConversationReadResponse(
                    conversationID: self.conversationID,
                    lastReadAt: Date(),
                    lastReadReplyID: UUID()
                )
            )
        }

        _ = await replySync.markConversationRead(conversationID: conversationID, lastReadReplyID: nil)

        guard let body = Self.jsonBody(from: capturedRequest) else {
            return
        }
        XCTAssertNil(body["lastReadReplyID"])
    }

    func testMarkConversationReadResponseDecodesWithNullLastReadReplyID() throws {
        let json = """
            {
                "conversationID": "00000000-0000-0000-0000-000000000001",
                "lastReadAt": "2026-01-01T00:00:00.000Z",
                "lastReadReplyID": null
            }
            """.data(using: .utf8)!
        let response = try JSONDecoder.default.decode(MarkConversationReadResponse.self, from: json)
        XCTAssertNil(response.lastReadReplyID)
    }

    func testSendReplyPostsExternalIDAndTextContent() async {
        var capturedRequestBody: [String: Any]?

        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }

            capturedRequestBody = Self.jsonBody(from: request)

            return .success(object: EmptyBody(), statusCode: 202)
        }

        await replySync.sendReply(conversationID: conversationID, text: "Hi")?.value

        let externalID = capturedRequestBody?["externalID"] as? String
        let content = capturedRequestBody?["content"] as? [[String: Any]]

        XCTAssertNotNil(externalID)
        XCTAssertFalse(externalID?.isEmpty ?? true)
        XCTAssertEqual(content?.count, 1)
        XCTAssertEqual(content?.first?["type"] as? String, "text")
        XCTAssertEqual(content?.first?["text"] as? String, "Hi")
    }

    func testSendReplyIncludesAuthorizationWhenUserIDPresent() async {
        mockUserInfoManager.mockUserID = "fan-123"
        httpClient.authContext.setSDKAuthenticationIDToken("identified-fan-token")

        var capturedAuthorization: String?
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }

            capturedAuthorization = request.value(forHTTPHeaderField: "Authorization")
            return .success(object: EmptyBody(), statusCode: 202)
        }

        await replySync.sendReply(conversationID: conversationID, text: "Hi")?.value

        XCTAssertEqual(capturedAuthorization, "Bearer identified-fan-token")
    }

    func testSendReplySuccessMarksSentState() async {
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }

            return .success(object: EmptyBody(), statusCode: 202)
        }

        await replySync.sendReply(conversationID: conversationID, text: "Accepted")?.value

        let savedReplies = await MainActor.run { () -> [Reply] in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "conversation.id == %@", self.conversationID as CVarArg)
            return (try? self.testContainer.viewContext.fetch(req)) ?? []
        }

        XCTAssertEqual(savedReplies.count, 1)
        XCTAssertEqual(savedReplies.first?.syncState, ReplySyncState.sent.rawValue)
        XCTAssertNotNil(savedReplies.first?.externalID, "externalID should be preserved until forward sync confirms")
        XCTAssertEqual(savedReplies.first?.persistedContentBlocks, [.text(text: "Accepted")])
    }

    func testSendReplyServerErrorQueuesRetry() async {
        let beforeAttempt = Date()
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }

            return .failure(error: URLError(.badServerResponse), statusCode: 503)
        }

        await replySync.sendReply(conversationID: conversationID, text: "Retry required")?.value

        let reply = await MainActor.run { self.fetchSavedReply() }

        XCTAssertEqual(reply?.syncState, ReplySyncState.queued.rawValue)
        XCTAssertEqual(reply?.retryCount, 1)
        XCTAssertTrue((reply?.nextRetryAt ?? .distantPast) > beforeAttempt)
        XCTAssertNotNil(reply?.lastSendError)
        XCTAssertEqual(reply?.persistedContentBlocks, [.text(text: "Retry required")])
    }

    func testSendReplyNonAcceptedSuccessStatusQueuesRetry() async {
        let beforeAttempt = Date()
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }

            return .success(object: EmptyBody(), statusCode: 200)
        }

        await replySync.sendReply(conversationID: conversationID, text: "Retry required")?.value

        let reply = await MainActor.run { self.fetchSavedReply() }

        XCTAssertEqual(reply?.syncState, ReplySyncState.queued.rawValue)
        XCTAssertEqual(reply?.retryCount, 1)
        XCTAssertTrue((reply?.nextRetryAt ?? .distantPast) > beforeAttempt)
        XCTAssertNotNil(reply?.lastSendError)
        XCTAssertEqual(reply?.persistedContentBlocks, [.text(text: "Retry required")])
    }

    func testSendReplyBadRequestStopsRetry() async {
        await assertTerminalStatusCodeStopsRetry(statusCode: 400, text: "Bad Request")
    }

    func testSendReplyUnauthorizedStopsRetry() async {
        await assertTerminalStatusCodeStopsRetry(statusCode: 401, text: "Unauthorized")
    }

    func testSendReplyForbiddenStopsRetry() async {
        await assertTerminalStatusCodeStopsRetry(statusCode: 403, text: "Forbidden")
    }

    func testSendReply429IsRetried() async {
        await assertRetryableStatusCodeQueues(statusCode: 429, text: "Rate Limited")
    }

    func testSendReply408IsRetried() async {
        await assertRetryableStatusCodeQueues(statusCode: 408, text: "Request Timeout")
    }

    func testSendReplyUnprocessableEntityStopsRetry() async {
        await assertTerminalStatusCodeStopsRetry(statusCode: 422, text: "Unprocessable")
    }

    func testSyncFlushesEligibleQueuedRepliesAcrossConversations() async {
        let now = Date()
        let secondConversationID = UUID()

        await MainActor.run {
            let conversation = Conversation(context: self.testContainer.viewContext)
            conversation.id = secondConversationID
            conversation.createdAt = now
            conversation.updatedAt = now
            try? self.testContainer.viewContext.save()
        }

        await seedQueuedReply(
            conversationID: conversationID,
            externalID: "ext-1",
            text: "Queued 1",
            createdAt: now.addingTimeInterval(-2),
            nextRetryAt: now.addingTimeInterval(-1)
        )
        await seedQueuedReply(
            conversationID: secondConversationID,
            externalID: "ext-2",
            text: "Queued 2",
            createdAt: now.addingTimeInterval(-1),
            nextRetryAt: now.addingTimeInterval(-1)
        )

        URLProtocolMock.stubSendReply(
            conversationID: conversationID,
            reply: ReplyItem(
                id: UUID(),
                conversationID: conversationID,
                senderType: .fan,
                participantID: "fan-server",
                content: [.text(text: "Queued 1")],
                createdAt: now
            )
        )
        URLProtocolMock.stubSendReply(
            conversationID: secondConversationID,
            reply: ReplyItem(
                id: UUID(),
                conversationID: secondConversationID,
                senderType: .fan,
                participantID: "fan-server",
                content: [.text(text: "Queued 2")],
                createdAt: now
            )
        )

        _ = await replySync.sync()

        let remainingQueued = await MainActor.run { () -> Int in
            let request = Reply.fetchRequest()
            request.predicate = NSPredicate(format: "syncState == %@", ReplySyncState.queued.rawValue)
            return (try? self.testContainer.viewContext.count(for: request)) ?? -1
        }
        XCTAssertEqual(remainingQueued, 0)
    }

    func testSyncSkipsQueuedRepliesWithFutureNextRetryAt() async {
        let now = Date()
        await seedQueuedReply(
            conversationID: conversationID,
            externalID: "ext-future",
            text: "Future",
            createdAt: now,
            nextRetryAt: now.addingTimeInterval(120)
        )

        var requestMade = false
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }
            requestMade = true
            return nil
        }

        _ = await replySync.sync()

        XCTAssertFalse(requestMade)
    }

    func testSendReplyFailureThenBackoffWindowAllowsRetry() async {
        // Step 1: first send attempt fails — reply ends up queued with future nextRetryAt.
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }
            return .failure(error: URLError(.cannotFindHost), statusCode: 500)
        }

        await replySync.sendReply(conversationID: conversationID, text: "Retry me")?.value

        let replyAfterFailure = await MainActor.run { () -> Reply? in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "conversation.id == %@", self.conversationID as CVarArg)
            req.fetchLimit = 1
            return try? self.testContainer.viewContext.fetch(req).first
        }
        XCTAssertEqual(replyAfterFailure?.syncState, ReplySyncState.queued.rawValue)
        XCTAssertEqual(replyAfterFailure?.retryCount, 1)
        let nextRetryAt = try! XCTUnwrap(replyAfterFailure?.nextRetryAt)
        XCTAssertTrue(nextRetryAt > Date(), "nextRetryAt should be in the future after first failure")

        // Step 2: sync before the backoff window — reply should be skipped.
        var requestMadeDuringBackoff = false
        URLProtocolMock.reset()
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }
            requestMadeDuringBackoff = true
            return nil
        }
        _ = await replySync.sync()
        XCTAssertFalse(requestMadeDuringBackoff, "flush should skip reply whose backoff window has not elapsed")

        // Step 3: advance nextRetryAt to the past, then sync — reply should be picked up and reconciled.
        let failedExternalID = try! XCTUnwrap(replyAfterFailure?.externalID)
        await MainActor.run {
            guard let reply = replyAfterFailure else { return }
            reply.nextRetryAt = Date().addingTimeInterval(-1)
            try? self.testContainer.viewContext.save()
        }

        URLProtocolMock.reset()
        URLProtocolMock.stubSendReply(
            conversationID: conversationID,
            reply: ReplyItem(
                id: UUID(),
                conversationID: conversationID,
                senderType: .fan,
                participantID: "fan-server",
                content: [.text(text: "Retry me")],
                createdAt: Date()
            )
        )
        _ = await replySync.sync()

        let finalReply = await MainActor.run { () -> Reply? in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "externalID == %@", failedExternalID)
            req.fetchLimit = 1
            return try? self.testContainer.viewContext.fetch(req).first
        }
        XCTAssertNotNil(finalReply, "reply should transition to sent after backoff window elapses")
        XCTAssertEqual(finalReply?.syncState, ReplySyncState.sent.rawValue)
    }

    func testSyncFailureIncrementsRetryCountAndSetsBackoff() async {
        let now = Date()
        await seedQueuedReply(
            conversationID: conversationID,
            externalID: "ext-fail",
            text: "Will fail",
            createdAt: now,
            nextRetryAt: now.addingTimeInterval(-1)
        )

        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }

            return .failure(error: URLError(.cannotFindHost), statusCode: 500)
        }

        _ = await replySync.sync()

        let reply = await MainActor.run { () -> Reply? in
            let request = Reply.fetchRequest()
            request.predicate = NSPredicate(format: "externalID == %@", "ext-fail")
            request.fetchLimit = 1
            return try? self.testContainer.viewContext.fetch(request).first
        }

        XCTAssertEqual(reply?.syncState, ReplySyncState.queued.rawValue)
        XCTAssertEqual(reply?.retryCount, 1)
        XCTAssertNotNil(reply?.lastSendError)
        XCTAssertTrue((reply?.nextRetryAt ?? .distantPast) > now)
    }

    func testSyncUnauthorizedFailureStopsRetryForQueuedReply() async {
        let now = Date()
        await seedQueuedReply(
            conversationID: conversationID,
            externalID: "ext-stop",
            text: "Will stop",
            createdAt: now,
            nextRetryAt: now.addingTimeInterval(-1)
        )

        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }

            return .failure(error: URLError(.userAuthenticationRequired), statusCode: 404)
        }

        _ = await replySync.sync()

        let reply = await MainActor.run { () -> Reply? in
            let request = Reply.fetchRequest()
            request.predicate = NSPredicate(format: "externalID == %@", "ext-stop")
            request.fetchLimit = 1
            return try? self.testContainer.viewContext.fetch(request).first
        }

        let queuedCount = await MainActor.run { () -> Int in
            let request = Reply.fetchRequest()
            request.predicate = NSPredicate(format: "syncState == %@", ReplySyncState.queued.rawValue)
            return (try? self.testContainer.viewContext.count(for: request)) ?? -1
        }

        XCTAssertEqual(reply?.syncState, ReplySyncState.failed.rawValue)
        XCTAssertEqual(reply?.retryCount, 1)
        XCTAssertNil(reply?.nextRetryAt)
        XCTAssertNotNil(reply?.lastSendError)
        XCTAssertEqual(queuedCount, 0)
    }

    func testSyncReturnsFalseWhenQueuedSnapshotIsInvalid() async {
        let now = Date()
        await seedQueuedReply(
            conversationID: conversationID,
            externalID: "ext-invalid",
            text: "Invalid",
            createdAt: now,
            nextRetryAt: now.addingTimeInterval(-1)
        )

        await MainActor.run {
            let request = Reply.fetchRequest()
            request.predicate = NSPredicate(format: "externalID == %@", "ext-invalid")
            request.fetchLimit = 1
            guard let reply = try? self.testContainer.viewContext.fetch(request).first else {
                XCTFail("Expected queued reply fixture")
                return
            }

            if let existingBlocks = reply.contentBlocks?.allObjects as? [ReplyContentBlock] {
                for block in existingBlocks {
                    self.testContainer.viewContext.delete(block)
                }
            }
            do {
                try self.testContainer.viewContext.save()
            } catch {
                XCTFail("Failed to save invalid queued reply fixture: \(error)")
            }
        }

        var requestMade = false
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }
            requestMade = true
            return nil
        }

        let result = await replySync.sync()
        XCTAssertFalse(result)
        XCTAssertFalse(requestMade)

        let reply = await MainActor.run { () -> Reply? in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "externalID == %@", "ext-invalid")
            req.fetchLimit = 1
            return try? self.testContainer.viewContext.fetch(req).first
        }
        XCTAssertEqual(
            reply?.syncState,
            ReplySyncState.failed.rawValue,
            "Unresolvable reply should be transitioned to .failed so it doesn't permanently block the conversation"
        )
        XCTAssertNil(reply?.nextRetryAt)
        XCTAssertNotNil(reply?.lastSendError)
    }

    func testFlushQueuedRepliesForConversationPreservesFIFO() async {
        let now = Date()
        await seedQueuedReply(
            conversationID: conversationID,
            externalID: "ext-first",
            text: "First",
            createdAt: now.addingTimeInterval(-5),
            nextRetryAt: now.addingTimeInterval(-1)
        )
        await seedQueuedReply(
            conversationID: conversationID,
            externalID: "ext-second",
            text: "Second",
            createdAt: now.addingTimeInterval(-4),
            nextRetryAt: now.addingTimeInterval(-1)
        )

        var sendOrder: [String] = []
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }

            if let body = Self.jsonBody(from: request),
                let externalID = body["externalID"] as? String
            {
                sendOrder.append(externalID)
            }

            return .success(object: EmptyBody(), statusCode: 202)
        }

        _ = await replySync.flushQueuedReplies(conversationID: conversationID)

        XCTAssertEqual(sendOrder, ["ext-first", "ext-second"])
    }

    func testSendReplyFlushAlsoSendsBackloggedQueuedReply() async {
        // The old direct-send path only sent the fresh reply; the flush path also
        // picks up previously queued replies for the same conversation. This verifies
        // the routing change: sendReply now goes through flushQueuedReplies.
        let now = Date()
        await seedQueuedReply(
            conversationID: conversationID,
            externalID: "ext-backlog",
            text: "Backlogged",
            createdAt: now.addingTimeInterval(-5),
            nextRetryAt: now.addingTimeInterval(-1)
        )

        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }
            return .success(object: EmptyBody(), statusCode: 202)
        }

        // sendReply spawns a per-conversation flush; that flush finds both the backlog
        // reply and the newly inserted reply and sends them all.
        await replySync.sendReply(conversationID: conversationID, text: "Fresh")?.value

        let backlogReply = await MainActor.run { () -> Reply? in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "externalID == %@", "ext-backlog")
            req.fetchLimit = 1
            return try? self.testContainer.viewContext.fetch(req).first
        }
        XCTAssertEqual(
            backlogReply?.syncState,
            ReplySyncState.sent.rawValue,
            "sendReply should trigger a flush that also sends previously queued replies"
        )

        let allReplies = await MainActor.run { () -> [Reply] in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "conversation.id == %@", self.conversationID as CVarArg)
            return (try? self.testContainer.viewContext.fetch(req)) ?? []
        }
        XCTAssertEqual(allReplies.count, 2, "both the fresh reply and the backlogged reply should be present")
        XCTAssertTrue(
            allReplies.allSatisfy { $0.syncState == ReplySyncState.sent.rawValue },
            "sendReply flush should send the fresh reply as well as the backlogged one"
        )
    }

    func testConcurrentSendRepliesDoNotDoubleSend() async {
        // Two concurrent sendReply calls for the same conversation must not double-send either reply.
        var requestCount = 0
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }
            requestCount += 1
            return .success(object: EmptyBody(), statusCode: 202)
        }

        // Use async let so both sendReply calls are queued concurrently on the actor,
        // exercising the activeSendTasks dedup path.
        async let t1 = replySync.sendReply(conversationID: conversationID, text: "First")
        async let t2 = replySync.sendReply(conversationID: conversationID, text: "Second")
        let (task1, task2) = await (t1, t2)
        _ = await task1?.value
        _ = await task2?.value

        XCTAssertEqual(requestCount, 2, "Each reply should be sent exactly once")

        let allReplies = await MainActor.run { () -> [Reply] in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(
                format: "conversation.id == %@",
                self.conversationID as CVarArg
            )
            return (try? self.testContainer.viewContext.fetch(req)) ?? []
        }
        XCTAssertEqual(allReplies.count, 2)
        XCTAssertTrue(
            allReplies.allSatisfy { $0.syncState == ReplySyncState.sent.rawValue },
            "Both replies should be .sent"
        )
    }

    func testBackoffDelayIsCappedAt30Seconds() {
        // retryCount 5 → exponent clamped to 5 → 2^5 = 32 → capped to 30
        XCTAssertEqual(replySync.backoffDelay(for: 5), 30.0)
        // retryCount 10 → exponent clamped to 5 → still 30
        XCTAssertEqual(replySync.backoffDelay(for: 10), 30.0)
        // retryCount 1 → 2^1 = 2
        XCTAssertEqual(replySync.backoffDelay(for: 1), 2.0)
        // retryCount 4 → 2^4 = 16
        XCTAssertEqual(replySync.backoffDelay(for: 4), 16.0)
    }

    func testRetryableFailureAfterDeadlineTransitionsToFailed() async {
        // createdAt is 118 s ago: within the 120 s sweep window (so the pre-flush sweep doesn't catch
        // it), but the proposed next retry at retryCount=2 lands 4 s from now (now+4 > createdAt+120=now+2),
        // so effectiveRetryable is false and the send path permanently fails the reply.
        let createdAt = Date().addingTimeInterval(-118)
        await seedQueuedReply(
            conversationID: conversationID,
            externalID: "ext-deadline",
            text: "Deadline test",
            createdAt: createdAt,
            nextRetryAt: Date().addingTimeInterval(-1),
            retryCount: 1
        )

        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }
            return .failure(error: URLError(.cannotFindHost), statusCode: 500)
        }

        _ = await replySync.sync()

        let reply = await MainActor.run { () -> Reply? in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "externalID == %@", "ext-deadline")
            req.fetchLimit = 1
            return try? self.testContainer.viewContext.fetch(req).first
        }
        XCTAssertEqual(
            reply?.syncState,
            ReplySyncState.failed.rawValue,
            "Reply past 2-minute deadline should transition to .failed on retryable failure"
        )
        XCTAssertNil(reply?.nextRetryAt)
        XCTAssertNotNil(reply?.lastSendError)
    }

    func testFlushSweepsNeverAttemptedReplyOlderThanDeadlineWithoutSending() async {
        // A reply with retryCount=0 whose createdAt is older than the 120s deadline is swept
        // to .failed by the deadline sweep — no network attempt is made, matching the same
        // behaviour as a reply that exhausted its retries.
        let createdAt = Date().addingTimeInterval(-121)
        await seedQueuedReply(
            conversationID: conversationID,
            externalID: "ext-never-attempted-expired",
            text: "Never attempted expired",
            createdAt: createdAt,
            nextRetryAt: Date().addingTimeInterval(-1),
            retryCount: 0
        )

        var requestMade = false
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }
            requestMade = true
            return .success(object: EmptyBody(), statusCode: 202)
        }

        _ = await replySync.sync()

        XCTAssertFalse(requestMade, "No network request should be made for an expired reply")

        let reply = await MainActor.run { () -> Reply? in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "externalID == %@", "ext-never-attempted-expired")
            req.fetchLimit = 1
            return try? self.testContainer.viewContext.fetch(req).first
        }
        XCTAssertEqual(
            reply?.syncState,
            ReplySyncState.failed.rawValue,
            "Never-attempted reply older than the deadline should be swept to .failed without a send attempt"
        )
        XCTAssertNil(reply?.nextRetryAt)
    }

    func testRetryableFailureWithinDeadlineTransitionsToQueued() async {
        // createdAt is 30 s ago; retryCount 0 → next retry delay = 2 s → nextRetryAt = now + 2 = createdAt + 32 < createdAt + 120
        let createdAt = Date().addingTimeInterval(-30)
        await seedQueuedReply(
            conversationID: conversationID,
            externalID: "ext-within-window",
            text: "Within window",
            createdAt: createdAt,
            nextRetryAt: Date().addingTimeInterval(-1)
        )

        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }
            return .failure(error: URLError(.cannotFindHost), statusCode: 500)
        }

        _ = await replySync.sync()

        let reply = await MainActor.run { () -> Reply? in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "externalID == %@", "ext-within-window")
            req.fetchLimit = 1
            return try? self.testContainer.viewContext.fetch(req).first
        }
        XCTAssertEqual(
            reply?.syncState,
            ReplySyncState.queued.rawValue,
            "Reply within 2-minute window should remain .queued on retryable failure"
        )
        XCTAssertNotNil(reply?.nextRetryAt)
    }

    func testHeadOfLineBlockingPreventsNewerReplyFromJumpingAhead() async {
        let now = Date()

        // Older reply with nextRetryAt in the future (blocked in backoff)
        await seedQueuedReply(
            conversationID: conversationID,
            externalID: "ext-blocked",
            text: "Blocked older",
            createdAt: now.addingTimeInterval(-10),
            nextRetryAt: now.addingTimeInterval(30)
        )
        // Newer reply with nextRetryAt in the past (eligible)
        await seedQueuedReply(
            conversationID: conversationID,
            externalID: "ext-newer",
            text: "Newer eligible",
            createdAt: now.addingTimeInterval(-5),
            nextRetryAt: now.addingTimeInterval(-1)
        )

        var requestMade = false
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }
            requestMade = true
            return nil
        }

        _ = await replySync.sync()

        XCTAssertFalse(
            requestMade,
            "Newer eligible reply must not be sent while older reply is in backoff (head-of-line blocking)"
        )
        let newerReply = await MainActor.run { () -> Reply? in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "externalID == %@", "ext-newer")
            req.fetchLimit = 1
            return try? self.testContainer.viewContext.fetch(req).first
        }
        XCTAssertEqual(newerReply?.syncState, ReplySyncState.queued.rawValue)
    }

    func testBlockedConversationDoesNotPreventOtherConversationSends() async {
        let now = Date()
        let otherConversationID = UUID()

        await MainActor.run {
            let conv = Conversation(context: self.testContainer.viewContext)
            conv.id = otherConversationID
            conv.createdAt = now
            conv.updatedAt = now
            try? self.testContainer.viewContext.save()
        }

        // Conversation A: blocked by a reply in backoff
        await seedQueuedReply(
            conversationID: conversationID,
            externalID: "ext-a-blocked",
            text: "A blocked",
            createdAt: now.addingTimeInterval(-10),
            nextRetryAt: now.addingTimeInterval(30)
        )

        // Conversation B: eligible reply
        await seedQueuedReply(
            conversationID: otherConversationID,
            externalID: "ext-b-eligible",
            text: "B eligible",
            createdAt: now.addingTimeInterval(-5),
            nextRetryAt: now.addingTimeInterval(-1)
        )

        URLProtocolMock.stubSendReply(
            conversationID: otherConversationID,
            reply: ReplyItem(
                id: UUID(),
                conversationID: otherConversationID,
                senderType: .fan,
                participantID: "fan-server",
                content: [.text(text: "B eligible")],
                createdAt: now
            )
        )

        _ = await replySync.sync()

        let bReply = await MainActor.run { () -> Reply? in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "externalID == %@", "ext-b-eligible")
            req.fetchLimit = 1
            return try? self.testContainer.viewContext.fetch(req).first
        }
        XCTAssertEqual(
            bReply?.syncState,
            ReplySyncState.sent.rawValue,
            "Conversation B reply should send normally even though conversation A is blocked"
        )

        let aReply = await MainActor.run { () -> Reply? in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "externalID == %@", "ext-a-blocked")
            req.fetchLimit = 1
            return try? self.testContainer.viewContext.fetch(req).first
        }
        XCTAssertEqual(aReply?.syncState, ReplySyncState.queued.rawValue)
    }

    private func assertRetryableStatusCodeQueues(statusCode: Int, text: String) async {
        let beforeAttempt = Date()
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }
            return .failure(error: URLError(.badServerResponse), statusCode: statusCode)
        }

        await replySync.sendReply(conversationID: conversationID, text: text)?.value

        let reply = await MainActor.run { self.fetchSavedReply() }

        XCTAssertEqual(reply?.syncState, ReplySyncState.queued.rawValue)
        XCTAssertEqual(reply?.retryCount, 1)
        XCTAssertTrue((reply?.nextRetryAt ?? .distantPast) > beforeAttempt)
        XCTAssertNotNil(reply?.lastSendError)
    }

    private func assertTerminalStatusCodeStopsRetry(statusCode: Int, text: String) async {
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }
            return .failure(error: URLError(.badServerResponse), statusCode: statusCode)
        }

        await replySync.sendReply(conversationID: conversationID, text: text)?.value

        let reply = await MainActor.run { self.fetchSavedReply() }

        XCTAssertEqual(reply?.syncState, ReplySyncState.failed.rawValue)
        XCTAssertEqual(reply?.retryCount, 1)
        XCTAssertNil(reply?.nextRetryAt)
        XCTAssertNotNil(reply?.lastSendError)
        XCTAssertEqual(reply?.persistedContentBlocks, [.text(text: text)])
    }

    @MainActor
    private func fetchSavedReply() -> Reply? {
        let req = Reply.fetchRequest()
        req.predicate = NSPredicate(format: "conversation.id == %@", self.conversationID as CVarArg)
        req.fetchLimit = 1
        return try? self.testContainer.viewContext.fetch(req).first
    }

    private func seedQueuedReply(
        conversationID: UUID,
        externalID: String,
        text: String,
        createdAt: Date,
        nextRetryAt: Date,
        retryCount: Int16 = 0
    ) async {
        await MainActor.run {
            if self.testContainer.fetchConversation(id: conversationID) == nil {
                let conversation = Conversation(context: self.testContainer.viewContext)
                conversation.id = conversationID
                conversation.createdAt = createdAt
                conversation.updatedAt = createdAt
            }

            let reply = self.testContainer.insertOptimisticReply(
                conversationID: conversationID,
                text: text,
                externalID: externalID
            )
            guard let reply else {
                XCTFail("Expected optimistic reply insert to succeed for fixture setup")
                return
            }

            reply.createdAt = createdAt
            reply.nextRetryAt = nextRetryAt
            reply.retryCount = retryCount
            do {
                try self.testContainer.viewContext.save()
            } catch {
                XCTFail("Failed to save queued reply fixture: \(error)")
            }
        }
    }

    private static func jsonBody(
        from request: URLRequest?,
        filename: StaticString = #filePath,
        line: UInt = #line
    ) -> [String: Any]? {
        guard let request else {
            XCTFail("Expected captured request", file: filename, line: line)
            return nil
        }

        let bodyData: Data?
        if let body = request.httpBody {
            bodyData = body
        } else if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }

            var collected = Data()
            var buffer = [UInt8](repeating: 0, count: 4_096)
            while stream.hasBytesAvailable {
                let bytesRead = stream.read(&buffer, maxLength: buffer.count)
                guard bytesRead > 0 else { break }
                collected.append(buffer, count: bytesRead)
            }
            bodyData = collected
        } else {
            bodyData = nil
        }

        guard let bodyData else {
            XCTFail("Expected request body data", file: filename, line: line)
            return nil
        }

        do {
            let object = try JSONSerialization.jsonObject(with: bodyData)
            guard let body = object as? [String: Any] else {
                XCTFail("Expected JSON object dictionary body", file: filename, line: line)
                return nil
            }
            return body
        } catch {
            XCTFail("Expected valid JSON request body, got error: \(error)", file: filename, line: line)
            return nil
        }
    }

    func testFlushSweepsExpiredQueuedRepliesWithoutSendingThem() async {
        // A reply whose createdAt is older than the 120s retry window must be marked .failed
        // by the deadline sweep at the start of flushQueuedReplies — no network request should
        // be made for it.
        let expiredCreatedAt = Date().addingTimeInterval(-130)
        await seedQueuedReply(
            conversationID: conversationID,
            externalID: "ext-expired",
            text: "Expired",
            createdAt: expiredCreatedAt,
            nextRetryAt: Date().addingTimeInterval(-1)
        )

        var requestMade = false
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }
            requestMade = true
            return .success(object: EmptyBody(), statusCode: 202)
        }

        _ = await replySync.sync()

        XCTAssertFalse(requestMade, "No network request should be made for an expired reply")

        let reply = await MainActor.run { () -> Reply? in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(format: "externalID == %@", "ext-expired")
            req.fetchLimit = 1
            return try? self.testContainer.viewContext.fetch(req).first
        }
        XCTAssertEqual(reply?.syncState, ReplySyncState.failed.rawValue)
        XCTAssertNil(reply?.nextRetryAt)
    }

    // Contract test: documents that the actor recovers normally after cancelAllTasks.
    // A fresh sendReply after cancel must create a new task and complete normally.
    // Note: the pendingFlushConversationIDs.removeAll() cleanup line in cancelAllTasks
    // cannot be regression-tested via observable behavior (a stale entry only causes
    // a spurious empty re-run with no HTTP calls). This test guards actor recovery,
    // not the specific cleanup line.
    func testSendReplyAfterCancelAllTasksCompletesNormally() async {
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }
            return .success(object: EmptyBody(), statusCode: 202)
        }

        // Two concurrent sends to attempt to exercise the pending-flag insertion path.
        // The stub returns immediately, so the set may already be empty by the time
        // cancelAllTasks runs — this is best-effort, not a guarantee.
        async let t1 = replySync.sendReply(conversationID: conversationID, text: "Before cancel 1")
        async let t2 = replySync.sendReply(conversationID: conversationID, text: "Before cancel 2")
        _ = await (t1, t2)

        await replySync.cancelAllTasks()

        await replySync.sendReply(conversationID: conversationID, text: "After cancel")?.value

        let afterCancelReply = await MainActor.run { () -> Reply? in
            let req = Reply.fetchRequest()
            req.predicate = NSPredicate(
                format: "conversation.id == %@",
                self.conversationID as CVarArg
            )
            let all = (try? self.testContainer.viewContext.fetch(req)) ?? []
            return all.first { $0.persistedContentBlocks == [.text(text: "After cancel")] }
        }

        XCTAssertNotNil(afterCancelReply, "sendReply after cancelAllTasks should insert and send the reply")
        XCTAssertEqual(
            afterCancelReply?.syncState,
            ReplySyncState.sent.rawValue,
            "Reply sent after cancelAllTasks should reach .sent"
        )
    }

    func testRetryTimerSendsDueReplyWithNoExternalTrigger() async throws {
        // Seed a reply in backoff with nextRetryAt 100 ms from now.
        // Call sync() once to arm the timer. Then wait (up to 5 s) for the reply
        // to reach .sent without any further external trigger.
        let retryAt = Date().addingTimeInterval(0.1)
        await MainActor.run {
            guard
                let reply = try? XCTUnwrap(
                    testContainer.insertOptimisticReply(
                        conversationID: conversationID,
                        text: "Timer test reply",
                        externalID: "ext-timer-test"
                    )
                )
            else { return }
            reply.nextRetryAt = retryAt
            reply.retryCount = 1
            try? testContainer.viewContext.save()
        }

        URLProtocolMock.stubSendReply(
            conversationID: conversationID,
            reply: ReplyItem(
                id: UUID(),
                conversationID: conversationID,
                senderType: .fan,
                participantID: "fan-server",
                content: [.text(text: "Timer test reply")],
                createdAt: Date().addingTimeInterval(-5)
            )
        )

        // Initial sync arms the timer (reply is in backoff, not sent yet).
        _ = await replySync.sync()

        // Poll until the reply reaches .sent or the timeout expires.
        let deadline = Date().addingTimeInterval(5)
        var sentState: String? = nil
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)  // 50 ms
            sentState = await MainActor.run {
                let req = Reply.fetchRequest()
                req.predicate = NSPredicate(format: "externalID == %@", "ext-timer-test")
                req.fetchLimit = 1
                return (try? testContainer.viewContext.fetch(req))?.first?.syncState
            }
            if sentState == ReplySyncState.sent.rawValue { break }
        }

        XCTAssertEqual(
            sentState,
            ReplySyncState.sent.rawValue,
            "Timer should have fired and sent the due reply without an external trigger"
        )
    }

    func testRetryTimerIsCancelledBycancelAllTasks() async throws {
        // This test specifically guards against the re-arm-after-cancel bug: cancelAllTasks()
        // cancels and then *awaits* flush tasks, which means a task's trailing rearmRetryTimer()
        // could run after cancellation and leave a live timer behind. The Task.isCancelled
        // guard in sync() and the sendReply task body prevents this. If that guard were
        // removed, this test would catch it.
        //
        // Seed a reply in backoff with nextRetryAt 300 ms from now.
        // Call sync() to arm the timer, then immediately cancel.
        // Wait 1 s and assert the reply was NOT sent (timer was cancelled).
        let retryAt = Date().addingTimeInterval(0.3)
        await MainActor.run {
            guard
                let reply = try? XCTUnwrap(
                    testContainer.insertOptimisticReply(
                        conversationID: conversationID,
                        text: "Cancel timer test",
                        externalID: "ext-cancel-timer"
                    )
                )
            else { return }
            reply.nextRetryAt = retryAt
            reply.retryCount = 1
            try? testContainer.viewContext.save()
        }

        var requestMade = false
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations/\(self.conversationID!.uuidString)/replies"),
                request.httpMethod == "POST"
            else { return nil }
            requestMade = true
            return .success(object: EmptyBody(), statusCode: 202)
        }

        _ = await replySync.sync()
        await replySync.cancelAllTasks()

        // Wait past the would-be fire time.
        try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 s

        XCTAssertFalse(requestMade, "Timer should have been cancelled — no network request expected")
    }

}
