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

final class ConversationSyncTests: HubSyncTestBase {
    var conversationSync: ConversationSync!
    private struct EmptyBody: Encodable {}

    override func setUp() async throws {
        try await super.setUp()
        httpClient.authContext.enableSDKAuthIDTokenRefreshForDomain(pattern: "*.test.com")
        conversationSync = ConversationSync(
            persistentContainer: testContainer,
            hubSyncCoordinator: hubSyncCoordinator
        )
    }

    override func tearDown() async throws {
        conversationSync = nil
        try await super.tearDown()
    }

    func testLaunchSyncInsertsNewConversations() async {
        let convID = UUID()
        URLProtocolMock.stubConversations(
            [
                TestDataGenerator.makeConversationItem(id: convID, subject: "Test", lastReplyPreview: "Hello")
            ],
            nextCursor: "cursor-1",
            nextBefore: "before-1",
            hasMore: false,
            included: nil
        )

        _ = await conversationSync.sync()

        let convs = await MainActor.run { () -> [Conversation] in
            let req = Conversation.fetchRequest()
            return (try? self.testContainer.viewContext.fetch(req)) ?? []
        }
        XCTAssertEqual(convs.count, 1)
        XCTAssertEqual(convs.first?.subject, "Test")
    }

    func testLaunchSyncStoresCursors() async {
        URLProtocolMock.stubConversations(
            [],
            nextCursor: "fwd-cursor",
            nextBefore: "bwd-cursor",
            hasMore: false,
            included: nil
        )
        _ = await conversationSync.sync()

        let syncStatus = await MainActor.run { self.testContainer.getConversationsSyncStatus() }
        XCTAssertEqual(syncStatus?.cursor, "fwd-cursor")
        XCTAssertEqual(syncStatus?.backwardsCursor, "bwd-cursor")
    }

    func testUpsertDoesNotDuplicateConversations() async {
        let convID = UUID()
        let item = TestDataGenerator.makeConversationItem(id: convID, subject: "Original")
        URLProtocolMock.stubConversations([item], nextCursor: nil, nextBefore: nil, hasMore: false, included: nil)
        _ = await conversationSync.sync()

        let updatedItem = TestDataGenerator.makeConversationItem(id: convID, subject: "Updated")
        URLProtocolMock.reset()
        URLProtocolMock.stubConversations(
            [updatedItem],
            nextCursor: nil,
            nextBefore: nil,
            hasMore: false,
            included: nil
        )
        _ = await conversationSync.sync()

        let count = await MainActor.run { () -> Int in
            let req = Conversation.fetchRequest()
            return (try? self.testContainer.viewContext.count(for: req)) ?? -1
        }
        XCTAssertEqual(count, 1, "Sync twice should not duplicate")

        let conv = await MainActor.run { () -> Conversation? in
            let req = Conversation.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", convID as CVarArg)
            return try? self.testContainer.viewContext.fetch(req).first
        }
        XCTAssertEqual(conv?.subject, "Updated")
    }

    func testIsReadCachedOnUpsert() async {
        let lastIncomingReply = Date().addingTimeInterval(-3600)
        let lastRead = Date().addingTimeInterval(-7200)
        let item = TestDataGenerator.makeConversationItem(lastIncomingReplyAt: lastIncomingReply, lastReadAt: lastRead)
        URLProtocolMock.stubConversations([item], nextCursor: nil, nextBefore: nil, hasMore: false, included: nil)
        _ = await conversationSync.sync()

        let conv = await MainActor.run { () -> Conversation? in
            let req = Conversation.fetchRequest()
            return try? self.testContainer.viewContext.fetch(req).first
        }
        XCTAssertEqual(conv?.isRead, false, "lastIncomingReplyAt > lastReadAt means unread")
    }

    func testHistoryCompleteSetWhenHasMoreFalse() async {
        URLProtocolMock.stubConversations([], nextCursor: nil, nextBefore: "bwd", hasMore: false, included: nil)
        _ = await conversationSync.sync()

        URLProtocolMock.reset()
        URLProtocolMock.stubConversationsBackwards([], nextBefore: nil, hasMore: false, included: nil)
        await conversationSync.syncBackward()

        let syncStatus = await MainActor.run { self.testContainer.getConversationsSyncStatus() }
        XCTAssertEqual(syncStatus?.historyComplete, true)
    }

    func testForwardSyncPassesStoredCursorToRequest() async throws {
        try await MainActor.run {
            try testContainer.stageConversationsSyncStatus(
                cursor: "stored-cursor",
                backwardsCursor: nil,
                historyComplete: false
            )
            try testContainer.viewContext.save()
        }
        URLProtocolMock.stubConversations(
            [],
            nextCursor: "next",
            nextBefore: nil,
            hasMore: false,
            included: nil
        )

        await conversationSync.syncForward()

        let capturedCursor = URLProtocolMock.getCallLog().first?.url?.queryParameters?["cursor"]
        XCTAssertEqual(capturedCursor, "stored-cursor")
    }

    func testForwardSyncUpdatesForwardCursorAfterResponse() async {
        URLProtocolMock.stubConversations([], nextCursor: "new-cursor", nextBefore: nil, hasMore: false, included: nil)
        await conversationSync.syncForward()

        let syncStatus = await MainActor.run { self.testContainer.getConversationsSyncStatus() }
        XCTAssertEqual(syncStatus?.cursor, "new-cursor")
    }

    func testBootstrapSendsIfModifiedSinceWhenLocalDataExists() async throws {
        let knownDate = Date(timeIntervalSince1970: 1_700_000_000)
        try await MainActor.run {
            let conversation = Conversation(context: testContainer.viewContext)
            conversation.id = UUID()
            conversation.lastReplyAt = knownDate
            conversation.updatedAt = knownDate
            conversation.createdAt = knownDate
            try testContainer.viewContext.save()
        }

        var capturedIfModifiedSince: String?
        var capturedCursor: String?
        URLProtocolMock.stub { request in
            guard let url = request.url, url.path.contains("/conversations") else {
                return nil
            }
            capturedIfModifiedSince = request.value(forHTTPHeaderField: "If-Modified-Since")
            capturedCursor = url.queryParameters?["cursor"]
            let response = ConversationsSyncResponse(
                conversations: [],
                included: nil,
                nextCursor: nil,
                nextBefore: nil,
                hasMore: false
            )
            return .success(object: response)
        }

        _ = await conversationSync.sync()

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        XCTAssertEqual(capturedIfModifiedSince, formatter.string(from: knownDate))
        XCTAssertNil(capturedCursor, "Bootstrap sync should not send cursor")
    }

    func testDeltaSyncDoesNotSendIfModifiedSinceWhenCursorPresent() async throws {
        try await MainActor.run {
            try testContainer.stageConversationsSyncStatus(
                cursor: "stored-cursor",
                backwardsCursor: nil,
                historyComplete: false
            )
            try testContainer.viewContext.save()
        }

        var capturedIfModifiedSince: String?
        URLProtocolMock.stub { request in
            guard let url = request.url, url.path.contains("/conversations") else {
                return nil
            }
            capturedIfModifiedSince = request.value(forHTTPHeaderField: "If-Modified-Since")
            let response = ConversationsSyncResponse(
                conversations: [],
                included: nil,
                nextCursor: "next-cursor",
                nextBefore: nil,
                hasMore: false
            )
            return .success(object: response)
        }

        await conversationSync.syncForward()

        XCTAssertNil(capturedIfModifiedSince, "Delta sync with cursor should not send If-Modified-Since")
    }

    func testBootstrapIfModifiedSinceUsesCreatedAtWhenLastReplyAtIsNil() async throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        try await MainActor.run {
            let conversation = Conversation(context: testContainer.viewContext)
            conversation.id = UUID()
            conversation.lastReplyAt = nil
            conversation.createdAt = createdAt
            conversation.updatedAt = updatedAt
            try testContainer.viewContext.save()
        }

        var capturedIfModifiedSince: String?
        URLProtocolMock.stub { request in
            guard let url = request.url, url.path.contains("/conversations") else {
                return nil
            }
            capturedIfModifiedSince = request.value(forHTTPHeaderField: "If-Modified-Since")
            let response = ConversationsSyncResponse(
                conversations: [],
                included: nil,
                nextCursor: nil,
                nextBefore: nil,
                hasMore: false
            )
            return .success(object: response)
        }

        _ = await conversationSync.sync()

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        XCTAssertEqual(capturedIfModifiedSince, formatter.string(from: createdAt))
    }

    func testConversationsRequestIncludesAuthorizationWhenUserIDPresent() async {
        mockUserInfoManager.mockUserID = "fan-123"
        httpClient.authContext.setSDKAuthenticationIDToken("identified-fan-token")

        var capturedAuthorization: String?
        URLProtocolMock.stub { request in
            guard let url = request.url, url.path.contains("/conversations") else {
                return nil
            }
            capturedAuthorization = request.value(forHTTPHeaderField: "Authorization")
            let response = ConversationsSyncResponse(
                conversations: [],
                included: nil,
                nextCursor: nil,
                nextBefore: nil,
                hasMore: false
            )
            return .success(object: response)
        }

        _ = await conversationSync.sync()

        XCTAssertEqual(capturedAuthorization, "Bearer identified-fan-token")
    }

    func testConversationsRequestWithoutTokenStillCallsServerWhenUserIDPresent() async {
        mockUserInfoManager.mockUserID = "fan-123"
        httpClient.authContext.clearSDKAuthenticationIDToken()

        var requestMade = false
        var capturedAuthorization: String?
        URLProtocolMock.stub { request in
            guard let url = request.url, url.path.contains("/conversations") else {
                return nil
            }
            requestMade = true
            capturedAuthorization = request.value(forHTTPHeaderField: "Authorization")
            let response = ConversationsSyncResponse(
                conversations: [],
                included: nil,
                nextCursor: nil,
                nextBefore: nil,
                hasMore: false
            )
            return .success(object: response)
        }

        let didSync = await conversationSync.sync()

        XCTAssertTrue(didSync)
        XCTAssertTrue(requestMade)
        XCTAssertNil(capturedAuthorization)
    }

    func testStatus304SkipsUpsertAndPreservesCursors() async throws {
        try await MainActor.run {
            try testContainer.stageConversationsSyncStatus(
                cursor: "existing-cursor",
                backwardsCursor: "existing-back",
                historyComplete: false
            )
            try testContainer.viewContext.save()
            let conversation = Conversation(context: testContainer.viewContext)
            conversation.id = UUID()
            conversation.lastReplyAt = Date()
            conversation.updatedAt = Date()
            conversation.createdAt = Date()
            try testContainer.viewContext.save()
        }

        URLProtocolMock.stub { request in
            guard let url = request.url, url.path.contains("/conversations") else {
                return nil
            }
            return .success(object: EmptyBody(), statusCode: 304)
        }

        _ = await conversationSync.sync()

        let conversationCount = await MainActor.run { () -> Int in
            (try? self.testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(conversationCount, 1, "304 should not alter local data")

        let syncStatus = await MainActor.run { self.testContainer.getConversationsSyncStatus() }
        XCTAssertEqual(syncStatus?.cursor, "existing-cursor")
        XCTAssertEqual(syncStatus?.backwardsCursor, "existing-back")
        XCTAssertEqual(syncStatus?.historyComplete, false)
    }

    func testBackwardsSyncPassesStoredBackwardsCursorToRequest() async throws {
        try await MainActor.run {
            try testContainer.stageConversationsSyncStatus(
                cursor: nil,
                backwardsCursor: "bwd-cursor",
                historyComplete: false
            )
            try testContainer.viewContext.save()
        }
        URLProtocolMock.stubConversationsBackwards(
            nextBefore: nil,
            hasMore: false,
            included: nil
        )

        await conversationSync.syncBackward()

        let capturedBefore = URLProtocolMock.getCallLog().first?.url?.queryParameters?["before"]
        XCTAssertEqual(capturedBefore, "bwd-cursor")
    }

    func testBackwardsSyncIsNoOpWhenHistoryComplete() async throws {
        try await MainActor.run {
            try testContainer.stageConversationsSyncStatus(cursor: nil, backwardsCursor: "bwd", historyComplete: true)
            try testContainer.viewContext.save()
        }

        await conversationSync.syncBackward()

        XCTAssertEqual(URLProtocolMock.callCount(), 0, "Should not make HTTP call when historyComplete")
    }

    func testBackwardsSyncIsNoOpWhenNoBackwardsCursor() async {
        await conversationSync.syncBackward()

        XCTAssertEqual(URLProtocolMock.callCount(), 0, "Should not make HTTP call when no backwards cursor")
    }

    func testDrainBackwardHistoryFetchesAllPagesUntilDone() async throws {
        try await MainActor.run {
            try testContainer.stageConversationsSyncStatus(
                cursor: "forward-cursor",
                backwardsCursor: "bwd-page-1",
                historyComplete: false
            )
            try testContainer.viewContext.save()
        }

        var pagesFetched = 0
        URLProtocolMock.stub { request in
            guard
                let url = request.url,
                url.path.contains("/conversations"),
                url.queryParameters?["before"] != nil
            else { return nil }

            pagesFetched += 1
            let hasMore = pagesFetched < 3
            let nextBefore = hasMore ? "bwd-page-\(pagesFetched + 1)" : nil
            let response = ConversationsSyncResponse(
                conversations: [],
                included: nil,
                nextCursor: nil,
                nextBefore: nextBefore,
                hasMore: hasMore
            )
            return .success(object: response)
        }

        await conversationSync.syncBackward()

        XCTAssertEqual(pagesFetched, 3, "Should drain all pages until hasMore is false")
        let syncStatus = await MainActor.run { self.testContainer.getConversationsSyncStatus() }
        XCTAssertEqual(syncStatus?.historyComplete, true)
    }

    func testDrainBackwardHistoryIsNoOpWhenAlreadyComplete() async throws {
        try await MainActor.run {
            try testContainer.stageConversationsSyncStatus(
                cursor: "forward-cursor",
                backwardsCursor: "bwd-page-1",
                historyComplete: true
            )
            try testContainer.viewContext.save()
        }

        await conversationSync.syncBackward()

        XCTAssertEqual(URLProtocolMock.callCount(), 0)
    }

    func testConcurrentSyncCallsDeduplicate() async {
        URLProtocolMock.stubConversations(
            [],
            nextCursor: nil,
            nextBefore: nil,
            hasMore: false,
            included: nil,
            delay: 0.1
        )

        async let first = conversationSync.sync()
        async let second = conversationSync.sync()
        _ = await (first, second)

        XCTAssertEqual(
            URLProtocolMock.callCount(),
            1,
            "Concurrent sync() calls should deduplicate to one HTTP request"
        )
    }

    // MARK: - Participant Tests

    func testUpsertConversationIncludesParticipants() async {
        let convID = UUID()
        URLProtocolMock.stubConversations(
            [
                TestDataGenerator.makeConversationItem(id: convID, subject: "Test", participantIDs: ["p-1"])
            ],
            nextCursor: "cursor-1",
            nextBefore: "before-1",
            hasMore: false,
            included: ConversationsSyncResponse.IncludedData(participants: [
                ParticipantItem(id: "p-1", name: "Sam Rivera", avatarURL: nil, bio: nil, updatedAt: Date())
            ])
        )

        _ = await conversationSync.sync()

        let participant = await MainActor.run { () -> Participant? in
            let req = Participant.fetchRequest()
            return try? self.testContainer.viewContext.fetch(req).first
        }
        XCTAssertNotNil(participant)
        XCTAssertEqual(participant?.name, "Sam Rivera")
        XCTAssertEqual(participant?.id, "p-1")
    }

    func testParticipantsAddedOnReSyncWithoutDeletingExisting() async {
        let convID = UUID()

        // First sync: one participant
        URLProtocolMock.stubConversations(
            [
                TestDataGenerator.makeConversationItem(id: convID, subject: "Test", participantIDs: ["p-1"])
            ],
            nextCursor: "c1",
            nextBefore: nil,
            hasMore: false,
            included: ConversationsSyncResponse.IncludedData(participants: [
                ParticipantItem(id: "p-1", name: "Sam", avatarURL: nil, bio: nil, updatedAt: Date())
            ])
        )
        _ = await conversationSync.sync()

        // Second sync: different participant
        URLProtocolMock.reset()
        URLProtocolMock.stubConversations(
            [
                TestDataGenerator.makeConversationItem(id: convID, subject: "Test", participantIDs: ["p-2"])
            ],
            nextCursor: "c2",
            nextBefore: nil,
            hasMore: false,
            included: ConversationsSyncResponse.IncludedData(participants: [
                ParticipantItem(id: "p-2", name: "Alex", avatarURL: nil, bio: nil, updatedAt: Date())
            ])
        )
        await conversationSync.syncForward()

        let participants = await MainActor.run { () -> [Participant] in
            let req = Participant.fetchRequest()
            return (try? self.testContainer.viewContext.fetch(req)) ?? []
        }
        XCTAssertEqual(participants.count, 2, "Resync should add/update participants, never delete")
        XCTAssertTrue(participants.contains { $0.id == "p-1" })
        XCTAssertTrue(participants.contains { $0.id == "p-2" })
    }

    func testParticipantsPreservedWhenIncludedMissing() async {
        let convID = UUID()

        // First sync: store one participant.
        URLProtocolMock.stubConversations(
            [
                TestDataGenerator.makeConversationItem(id: convID, subject: "Test", participantIDs: ["p-1"])
            ],
            nextCursor: "c1",
            nextBefore: nil,
            hasMore: false,
            included: ConversationsSyncResponse.IncludedData(participants: [
                ParticipantItem(id: "p-1", name: "Sam", avatarURL: nil, bio: nil, updatedAt: Date())
            ])
        )
        _ = await conversationSync.sync()

        // Second sync: no included block. Existing participant should remain unchanged.
        URLProtocolMock.reset()
        URLProtocolMock.stubConversations(
            [
                TestDataGenerator.makeConversationItem(id: convID, subject: "Test", participantIDs: ["p-2"])
            ],
            nextCursor: "c2",
            nextBefore: nil,
            hasMore: false,
            included: nil
        )
        _ = await conversationSync.syncForward()

        let participants = await MainActor.run { () -> [Participant] in
            let req = Participant.fetchRequest()
            return (try? self.testContainer.viewContext.fetch(req)) ?? []
        }
        XCTAssertEqual(participants.count, 1, "Missing included data should not wipe participants")
        XCTAssertEqual(participants.first?.id, "p-1")
    }

    func testConversationsRequestIncludesParticipantsOnLaunchSync() async {
        var includeValue: String?
        URLProtocolMock.stub { request in
            includeValue = request.url?.queryParameters?["include"]
            let response = ConversationsSyncResponse(
                conversations: [],
                included: nil,
                nextCursor: nil,
                nextBefore: nil,
                hasMore: false
            )
            return .success(object: response)
        }

        _ = await conversationSync.sync()

        XCTAssertEqual(includeValue, "participants")
    }

    func testConversationsRequestIncludesParticipantsOnBackwardsSync() async throws {
        try await MainActor.run {
            try testContainer.stageConversationsSyncStatus(
                cursor: nil,
                backwardsCursor: "back-cursor",
                historyComplete: false
            )
            try testContainer.viewContext.save()
        }

        var includeValue: String?
        var beforeValue: String?
        URLProtocolMock.stub { request in
            includeValue = request.url?.queryParameters?["include"]
            beforeValue = request.url?.queryParameters?["before"]
            let response = ConversationsSyncResponse(
                conversations: [],
                included: nil,
                nextCursor: nil,
                nextBefore: nil,
                hasMore: false
            )
            return .success(object: response)
        }

        await conversationSync.syncBackward()

        XCTAssertEqual(beforeValue, "back-cursor")
        XCTAssertEqual(includeValue, "participants")
    }

    func testExistingParticipantUpdatedWithoutDuplication() async {
        let convID = UUID()

        URLProtocolMock.stubConversations(
            [
                TestDataGenerator.makeConversationItem(id: convID, subject: "Test", participantIDs: ["p-1"])
            ],
            nextCursor: "c1",
            nextBefore: nil,
            hasMore: false,
            included: ConversationsSyncResponse.IncludedData(participants: [
                ParticipantItem(id: "p-1", name: "Sam", avatarURL: nil, bio: nil, updatedAt: Date())
            ])
        )
        _ = await conversationSync.sync()

        URLProtocolMock.reset()
        URLProtocolMock.stubConversations(
            [
                TestDataGenerator.makeConversationItem(id: convID, subject: "Test", participantIDs: ["p-1"])
            ],
            nextCursor: "c2",
            nextBefore: nil,
            hasMore: false,
            included: ConversationsSyncResponse.IncludedData(participants: [
                ParticipantItem(id: "p-1", name: "Alex", avatarURL: nil, bio: nil, updatedAt: Date())
            ])
        )
        await conversationSync.syncForward()

        let participants = await MainActor.run { () -> [Participant] in
            let req = Participant.fetchRequest()
            return (try? self.testContainer.viewContext.fetch(req)) ?? []
        }
        XCTAssertEqual(participants.count, 1)
        XCTAssertEqual(participants.first?.id, "p-1")
        XCTAssertEqual(participants.first?.name, "Alex")
    }

    func testBackwardsSyncUpsertsParticipants() async throws {
        try await MainActor.run {
            try testContainer.stageConversationsSyncStatus(
                cursor: nil,
                backwardsCursor: "back-cursor",
                historyComplete: false
            )
            try testContainer.viewContext.save()
        }

        let convID = UUID()
        URLProtocolMock.stubConversationsBackwards(
            [
                TestDataGenerator.makeConversationItem(id: convID, subject: "Backfill", participantIDs: ["p-back"])
            ],
            nextBefore: nil,
            hasMore: false,
            included: ConversationsSyncResponse.IncludedData(participants: [
                ParticipantItem(id: "p-back", name: "Backfill User", avatarURL: nil, bio: nil, updatedAt: Date())
            ])
        )
        await conversationSync.syncBackward()

        let participant = await MainActor.run { () -> Participant? in
            let req = Participant.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", "p-back")
            req.fetchLimit = 1
            return try? self.testContainer.viewContext.fetch(req).first
        }
        XCTAssertNotNil(participant)
        XCTAssertEqual(participant?.name, "Backfill User")
    }

    func testConversationWithEmptyParticipantIDsSkipsParticipantUpsert() async {
        let convID = UUID()
        URLProtocolMock.stubConversations(
            [
                TestDataGenerator.makeConversationItem(id: convID, subject: "No participant IDs")
            ],
            nextCursor: nil,
            nextBefore: nil,
            hasMore: false,
            included: ConversationsSyncResponse.IncludedData(participants: [
                ParticipantItem(id: "p-ignored", name: "Ignored", avatarURL: nil, bio: nil, updatedAt: Date())
            ])
        )

        _ = await conversationSync.sync()

        let counts = await MainActor.run { () -> (Int, Int) in
            let conversationsCount =
                (try? self.testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1
            let participantsCount =
                (try? self.testContainer.viewContext.count(for: Participant.fetchRequest())) ?? -1
            return (conversationsCount, participantsCount)
        }
        XCTAssertEqual(counts.0, 1)
        XCTAssertEqual(counts.1, 0, "Empty participantIDs should result in no participant upsert")
    }

    func testGetConversationsPageSendsDeviceIdentifier() async {
        var capturedDeviceIdentifier: String?
        URLProtocolMock.stub { request in
            capturedDeviceIdentifier = request.url?.queryParameters?["deviceIdentifier"]
            let response = ConversationsSyncResponse(
                conversations: [],
                included: nil,
                nextCursor: nil,
                nextBefore: nil,
                hasMore: false
            )
            return .success(object: response)
        }

        _ = await conversationSync.sync()

        XCTAssertNotNil(
            capturedDeviceIdentifier,
            "conversations request must include deviceIdentifier (may be empty when identifierForVendor is unavailable)"
        )
    }

    func testForwardSyncDrainsAllPagesUntilCaughtUp() async {
        var pagesFetched = 0
        URLProtocolMock.stub { request in
            guard let url = request.url, url.path.contains("/conversations"),
                url.queryParameters?["before"] == nil
            else { return nil }
            pagesFetched += 1
            let hasMore = pagesFetched < 3
            let nextCursor = hasMore ? "cursor-page-\(pagesFetched + 1)" : "cursor-final"
            let response = ConversationsSyncResponse(
                conversations: [],
                included: nil,
                nextCursor: nextCursor,
                nextBefore: nil,
                hasMore: hasMore
            )
            return .success(object: response)
        }

        await conversationSync.syncForward()

        XCTAssertEqual(pagesFetched, 3, "syncForward should drain all pages until hasMore is false")
        let syncStatus = await MainActor.run { self.testContainer.getConversationsSyncStatus() }
        XCTAssertEqual(syncStatus?.cursor, "cursor-final")
    }

    func testLaunchSyncDrainsAllPagesUntilCaughtUp() async {
        var pagesFetched = 0
        URLProtocolMock.stub { request in
            guard let url = request.url, url.path.contains("/conversations"),
                url.queryParameters?["before"] == nil
            else { return nil }
            pagesFetched += 1
            let hasMore = pagesFetched < 3
            let nextCursor = hasMore ? "cursor-page-\(pagesFetched + 1)" : "cursor-final"
            let response = ConversationsSyncResponse(
                conversations: [],
                included: nil,
                nextCursor: nextCursor,
                nextBefore: nil,
                hasMore: hasMore
            )
            return .success(object: response)
        }

        _ = await conversationSync.sync()

        XCTAssertEqual(pagesFetched, 3, "sync() should drain all pages until hasMore is false")
        let syncStatus = await MainActor.run { self.testContainer.getConversationsSyncStatus() }
        XCTAssertEqual(syncStatus?.cursor, "cursor-final")
    }

    func testLateSuccessDoesNotRepopulateAfterDrop() async {
        // Seed a conversation so we start with data.
        await MainActor.run {
            let conv = Conversation(context: testContainer.viewContext)
            conv.id = UUID()
            conv.createdAt = Date()
            conv.updatedAt = Date()
            try? testContainer.viewContext.save()
        }

        let convID = UUID()

        // Deterministic gate: the stub yields into this stream the moment the HTTP
        // request arrives, which proves fetchAndUpsertForward has already captured
        // epoch 0 and is now suspended in the network await. The response is then
        // held for 0.1s to give the test body time to perform the drop before it
        // is delivered. No fixed sleep is needed to reach epoch-capture.
        let (requestStartedStream, requestStartedContinuation) = AsyncStream<Void>.makeStream()

        URLProtocolMock.stub { request in
            guard let url = request.url,
                url.path.contains("/conversations"),
                !url.path.contains("/replies"),
                !url.path.contains("/read")
            else { return nil }
            // Signal the test body: epoch is captured, response not yet delivered.
            requestStartedContinuation.yield(())
            requestStartedContinuation.finish()
            return .success(
                object: ConversationsSyncResponse(
                    conversations: [
                        TestDataGenerator.makeConversationItem(id: convID, subject: "Late")
                    ],
                    included: nil,
                    nextCursor: nil,
                    nextBefore: nil,
                    hasMore: false
                ),
                delay: 0.1
            )
        }

        let syncTask = Task { await conversationSync.syncForward() }

        // Block until the request is received — guarantees epoch 0 is already captured.
        for await _ in requestStartedStream { break }

        // Drop while the response is still in the 0.1s delay window (epoch → 1). Bumping the
        // epoch and dropping the store are now separate steps (see
        // `InboxPersistentContainer.bumpConversationStoreGeneration()`); both are needed here —
        // the bump to trigger the guard, the drop to remove the seeded conversation.
        await MainActor.run {
            testContainer.bumpConversationStoreGeneration()
            testContainer.dropAllConversations()
        }

        // Let sync finish — the epoch guard (captured 0 ≠ current 1) discards the save.
        await syncTask.value

        let count = await MainActor.run {
            (try? testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(count, 0, "Late success response must not repopulate after a drop")
    }

}
