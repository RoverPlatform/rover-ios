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
import XCTest

@testable import RoverNotifications

// MARK: - Test doubles

/// Records calls to sendReply for assertion in tests.
actor MockReplySending: ReplySending {
    enum Event: Sendable, Equatable {
        case markLocal(conversationID: UUID, lastReadReplyID: UUID)
        case send(conversationID: UUID, text: String)
        case markServerRead(conversationID: UUID)
    }

    struct SendCall: Sendable {
        let conversationID: UUID
        let text: String
    }

    struct LocalReadCall: Sendable {
        let conversationID: UUID
        let lastReadReplyID: UUID
    }

    private(set) var calls: [SendCall] = []
    private(set) var markReadConversationIDs: [UUID] = []
    private(set) var markReadLocallyCalls: [LocalReadCall] = []
    private(set) var eventLog: [Event] = []

    func sendReply(conversationID: UUID, text: String) async -> Task<Bool, Never>? {
        calls.append(SendCall(conversationID: conversationID, text: text))
        eventLog.append(.send(conversationID: conversationID, text: text))
        return nil
    }

    func markConversationRead(conversationID: UUID) async -> Result<MarkConversationReadResponse, Error> {
        markReadConversationIDs.append(conversationID)
        eventLog.append(.markServerRead(conversationID: conversationID))
        return .failure(NSError(domain: "mock", code: 0))  // failure triggers error log in handler; not asserted here
    }

    func markConversationReadLocally(conversationID: UUID, lastReadReplyID: UUID) async {
        markReadLocallyCalls.append(LocalReadCall(conversationID: conversationID, lastReadReplyID: lastReadReplyID))
        eventLog.append(.markLocal(conversationID: conversationID, lastReadReplyID: lastReadReplyID))
    }
}

/// Tracks whether clearLastReceivedNotification was called.
class MockInfluenceTracker: InfluenceTracker {
    var clearCalled = false
    func startMonitoring() {}
    func stopMonitoring() {}
    func clearLastReceivedNotification() { clearCalled = true }
}

/// Records dispatched actions.
class MockDispatcher: Dispatcher {
    var dispatchedActions: [Action] = []
    func dispatch(_ action: Action, completionHandler: (() -> Void)?) {
        dispatchedActions.append(action)
        completionHandler?()
    }
}

/// Stub action returned by the action provider in tests.
class StubAction: Action, @unchecked Sendable {
    func execute(completionHandler: (() -> Void)?) { completionHandler?() }
}

// MARK: - Tests

/// Unit tests for the inline reply branch of NotificationHandlerService.
///
/// UNTextInputNotificationResponse and UNNotificationResponse have no public initialisers,
/// so the handler exposes an internal async method `handleInlineReply(actionIdentifier:userText:userInfo:completionHandler:)`
/// that accepts primitives extracted from the response. Tests drive that method directly.
///
/// The normal-tap path and receiveFromPush are not tested here — they involve
/// UNNotificationResponse (no public init). The normal-tap path is unchanged code covered
/// by prior tests; receiveFromPush is covered by ConversationPushTests and manual
/// Testbench verification.
final class InlineReplyNotificationTests: XCTestCase {

    var replySync: MockReplySending!
    var influenceTracker: MockInfluenceTracker!
    var dispatcher: MockDispatcher!
    var handler: NotificationHandlerService!
    let stubConversationID = UUID(uuidString: "019cbce7-86de-7610-94f0-cf590c499243")!
    let stubReplyID = UUID(uuidString: "019cbce7-86de-7610-94f0-cf590c499244")!

    override func setUp() async throws {
        try await super.setUp()
        replySync = MockReplySending()
        influenceTracker = MockInfluenceTracker()
        dispatcher = MockDispatcher()
        handler = NotificationHandlerService(
            dispatcher: dispatcher,
            influenceTracker: influenceTracker,
            notificationActionProvider: { _ in StubAction() },
            openURLActionProvider: { _ in StubAction() },
            replySync: replySync,
            inboxPersistentContainer: nil,
            notificationCenter: .empty
        )
    }

    // MARK: - replyID(from:) extraction

    func testExtractsReplyIDFromValidUserInfo() {
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["id": stubConversationID.uuidString] as [String: Any],
                "reply": ["id": stubReplyID.uuidString] as [String: Any]
            ] as [String: Any]
        ]
        XCTAssertEqual(handler.replyID(from: userInfo), stubReplyID)
    }

    func testReturnsNilReplyIDForMissingReplyKey() {
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["id": stubConversationID.uuidString] as [String: Any]
            ] as [String: Any]
        ]
        XCTAssertNil(handler.replyID(from: userInfo))
    }

    func testReturnsNilReplyIDForMalformedUUID() {
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "reply": ["id": "not-a-uuid"] as [String: Any]
            ] as [String: Any]
        ]
        XCTAssertNil(handler.replyID(from: userInfo))
    }

    // MARK: - conversationID(from:) extraction

    func testExtractsConversationIDFromValidUserInfo() {
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["id": stubConversationID.uuidString] as [String: Any]
            ] as [String: Any]
        ]
        XCTAssertEqual(handler.conversationID(from: userInfo), stubConversationID)
    }

    func testReturnsNilForMissingRoverKey() {
        XCTAssertNil(handler.conversationID(from: ["foo": "bar"]))
    }

    func testReturnsNilForMissingConversationKey() {
        let userInfo: [AnyHashable: Any] = ["rover": [:] as [String: Any]]
        XCTAssertNil(handler.conversationID(from: userInfo))
    }

    func testReturnsNilForMalformedUUID() {
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["id": "not-a-uuid"] as [String: Any]
            ] as [String: Any]
        ]
        XCTAssertNil(handler.conversationID(from: userInfo))
    }

    // MARK: - handleInlineReply

    func testInlineReplySendsSendReplyWithCorrectArguments() async {
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["id": stubConversationID.uuidString] as [String: Any],
                "reply": ["id": stubReplyID.uuidString] as [String: Any]
            ] as [String: Any]
        ]
        await handler.handleInlineReply(
            actionIdentifier: NotificationCategories.inlineReplyAction,
            userText: "Hello!",
            userInfo: userInfo,
            completionHandler: nil
        )
        let calls = await replySync.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].conversationID, stubConversationID)
        XCTAssertEqual(calls[0].text, "Hello!")
    }

    func testInlineReplyMarksConversationReadLocallyBeforeSend() async {
        // Payload includes both conversation ID and reply ID so local read can be applied.
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["id": stubConversationID.uuidString] as [String: Any],
                "reply": ["id": stubReplyID.uuidString] as [String: Any]
            ] as [String: Any]
        ]
        await handler.handleInlineReply(
            actionIdentifier: NotificationCategories.inlineReplyAction,
            userText: "Hi",
            userInfo: userInfo,
            completionHandler: nil
        )
        let localReadCalls = await replySync.markReadLocallyCalls
        XCTAssertEqual(localReadCalls.count, 1, "markConversationReadLocally must be called when reply ID is present")
        XCTAssertEqual(localReadCalls[0].conversationID, stubConversationID)
        XCTAssertEqual(localReadCalls[0].lastReadReplyID, stubReplyID)
        let eventLog = await replySync.eventLog
        XCTAssertEqual(
            eventLog,
            [
                .markLocal(conversationID: stubConversationID, lastReadReplyID: stubReplyID),
                .send(conversationID: stubConversationID, text: "Hi"),
                .markServerRead(conversationID: stubConversationID)
            ]
        )
    }

    func testInlineReplyWithMissingReplyIDSkipsSendAndMarksNothingRead() async {
        // Payload has only conversation ID — no reply object.
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["id": stubConversationID.uuidString] as [String: Any]
            ] as [String: Any]
        ]
        var completionCalled = false
        await handler.handleInlineReply(
            actionIdentifier: NotificationCategories.inlineReplyAction,
            userText: "Hi",
            userInfo: userInfo,
            completionHandler: { completionCalled = true }
        )
        let localReadCalls = await replySync.markReadLocallyCalls
        XCTAssertTrue(localReadCalls.isEmpty, "markConversationReadLocally must not be called for malformed payload")
        let sendCalls = await replySync.calls
        XCTAssertTrue(sendCalls.isEmpty, "sendReply must not be called for malformed payload")
        let markReadIDs = await replySync.markReadConversationIDs
        XCTAssertTrue(markReadIDs.isEmpty, "markConversationRead must not be called for malformed payload")
        let eventLog = await replySync.eventLog
        XCTAssertTrue(eventLog.isEmpty, "Malformed payload must not record inline-reply events")
        XCTAssertTrue(completionCalled, "completionHandler must still be called")
    }

    func testInlineReplyMarksConversationReadAfterSend() async {
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["id": stubConversationID.uuidString] as [String: Any],
                "reply": ["id": stubReplyID.uuidString] as [String: Any]
            ] as [String: Any]
        ]
        await handler.handleInlineReply(
            actionIdentifier: NotificationCategories.inlineReplyAction,
            userText: "Hi",
            userInfo: userInfo,
            completionHandler: nil
        )
        let markReadIDs = await replySync.markReadConversationIDs
        XCTAssertEqual(markReadIDs.count, 1)
        XCTAssertEqual(markReadIDs[0], stubConversationID)
    }

    func testInlineReplyDoesNotMarkReadWhenConversationIDMissing() async {
        let userInfo: [AnyHashable: Any] = ["rover": [:] as [String: Any]]
        await handler.handleInlineReply(
            actionIdentifier: NotificationCategories.inlineReplyAction,
            userText: "Hi",
            userInfo: userInfo,
            completionHandler: nil
        )
        let localReadCalls = await replySync.markReadLocallyCalls
        XCTAssertTrue(localReadCalls.isEmpty, "markConversationReadLocally must not be called for malformed payload")
        let sendCalls = await replySync.calls
        XCTAssertTrue(sendCalls.isEmpty, "sendReply must not be called for malformed payload")
        let markReadIDs = await replySync.markReadConversationIDs
        XCTAssertTrue(markReadIDs.isEmpty, "markConversationRead must not be called for malformed payload")
    }

    func testInlineReplyCallsCompletionHandler() async {
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["id": stubConversationID.uuidString] as [String: Any],
                "reply": ["id": stubReplyID.uuidString] as [String: Any]
            ] as [String: Any]
        ]
        var completionCalled = false
        await handler.handleInlineReply(
            actionIdentifier: NotificationCategories.inlineReplyAction,
            userText: "Hi",
            userInfo: userInfo,
            completionHandler: { completionCalled = true }
        )
        XCTAssertTrue(completionCalled, "completionHandler must be called")
    }

    func testInlineReplyDoesNotClearInfluenceTracker() async {
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["id": stubConversationID.uuidString] as [String: Any],
                "reply": ["id": stubReplyID.uuidString] as [String: Any]
            ] as [String: Any]
        ]
        await handler.handleInlineReply(
            actionIdentifier: NotificationCategories.inlineReplyAction,
            userText: "Hi",
            userInfo: userInfo,
            completionHandler: nil
        )
        XCTAssertFalse(influenceTracker.clearCalled, "Inline reply must not clear the influence tracker")
    }

    func testInlineReplyDoesNotDispatchOpenAppAction() async {
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["id": stubConversationID.uuidString] as [String: Any],
                "reply": ["id": stubReplyID.uuidString] as [String: Any]
            ] as [String: Any]
        ]
        await handler.handleInlineReply(
            actionIdentifier: NotificationCategories.inlineReplyAction,
            userText: "Hi",
            userInfo: userInfo,
            completionHandler: nil
        )
        XCTAssertTrue(dispatcher.dispatchedActions.isEmpty, "Inline reply must not open the app")
    }

    func testInlineReplyWithMissingConversationIDSkipsSendAndCallsCompletion() async {
        // Malformed payload: reply id exists, but conversation id is missing.
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "reply": ["id": stubReplyID.uuidString] as [String: Any]
            ] as [String: Any]
        ]
        var completionCalled = false
        await handler.handleInlineReply(
            actionIdentifier: NotificationCategories.inlineReplyAction,
            userText: "Hello",
            userInfo: userInfo,
            completionHandler: { completionCalled = true }
        )
        let calls = await replySync.calls
        XCTAssertEqual(calls.count, 0, "sendReply must not be called for malformed payload")
        XCTAssertTrue(completionCalled, "completionHandler must still be called")
        XCTAssertFalse(influenceTracker.clearCalled, "Influence tracker must not be cleared")
    }

    func testInlineReplyWithWrongActionIdentifierDoesNotSend() async {
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["id": stubConversationID.uuidString] as [String: Any]
            ] as [String: Any]
        ]
        var completionCalled = false
        await handler.handleInlineReply(
            actionIdentifier: "com.other.action",
            userText: "Hello",
            userInfo: userInfo,
            completionHandler: { completionCalled = true }
        )
        let calls = await replySync.calls
        XCTAssertEqual(calls.count, 0, "Wrong action identifier must not trigger a send")
        XCTAssertFalse(completionCalled, "Wrong action identifier must not invoke the completion handler")
    }

    func testInlineReplyWithWhitespaceTextSkipsSendAndDoesNotMarkRead() async {
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["id": stubConversationID.uuidString] as [String: Any],
                "reply": ["id": stubReplyID.uuidString] as [String: Any]
            ] as [String: Any]
        ]
        var completionCalled = false
        await handler.handleInlineReply(
            actionIdentifier: NotificationCategories.inlineReplyAction,
            userText: "   ",
            userInfo: userInfo,
            completionHandler: { completionCalled = true }
        )
        // Handler filters empty text; send/read should be skipped.
        let calls = await replySync.calls
        XCTAssertTrue(calls.isEmpty)
        let markReadIDs = await replySync.markReadConversationIDs
        XCTAssertTrue(markReadIDs.isEmpty)
        XCTAssertTrue(completionCalled)
    }

    func testInlineReplyTrimsTextBeforeSend() async {
        let userInfo: [AnyHashable: Any] = [
            "rover": [
                "conversation": ["id": stubConversationID.uuidString] as [String: Any],
                "reply": ["id": stubReplyID.uuidString] as [String: Any]
            ] as [String: Any]
        ]
        await handler.handleInlineReply(
            actionIdentifier: NotificationCategories.inlineReplyAction,
            userText: "  Hello  ",
            userInfo: userInfo,
            completionHandler: nil
        )
        let calls = await replySync.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].text, "Hello")
    }
}
