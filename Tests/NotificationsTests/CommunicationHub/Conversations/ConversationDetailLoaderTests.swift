//
// Copyright (c) 2026, Rover Labs, Inc. All rights reserved.
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

/// The conversation detail screen used to dismiss itself when the conversation was not in Core
/// Data yet. These pin the replacement: fetch it on demand, forward first and then the history
/// backfill, and report honestly when it is nowhere to be found.
final class ConversationDetailLoaderTests: HubSyncTestBase {
    private var conversationSync: ConversationSync!
    private var loader: ConversationDetailLoader!

    override func setUp() async throws {
        try await super.setUp()
        httpClient.authContext.enableSDKAuthIDTokenRefreshForDomain(pattern: "*.test.com")
        conversationSync = ConversationSync(
            persistentContainer: testContainer,
            hubSyncCoordinator: hubSyncCoordinator
        )
        loader = await MainActor.run {
            ConversationDetailLoader(container: testContainer, conversationSync: conversationSync)
        }
    }

    override func tearDown() async throws {
        loader = nil
        conversationSync = nil
        try await super.tearDown()
    }

    func testAConversationAlreadyInTheStoreIsAvailableWithoutAnyRequest() async {
        let convID = UUID()
        URLProtocolMock.stubConversations(
            [TestDataGenerator.makeConversationItem(id: convID, subject: "Local", lastReplyPreview: nil)],
            nextCursor: nil,
            nextBefore: nil,
            hasMore: false
        )
        _ = await conversationSync.sync()
        URLProtocolMock.reset()

        let available = await loader.ensureAvailable(conversationID: convID)

        XCTAssertTrue(available)
        XCTAssertTrue(URLProtocolMock.getCallLog().isEmpty, "a local hit must not go to the network")
    }

    func testAConversationMissingLocallyIsFetchedByTheForwardSync() async {
        let convID = UUID()
        // The forward page hands back a history cursor, so a backfill that ran anyway would
        // have somewhere to go and would show up in the call log.
        URLProtocolMock.stubConversations(
            [TestDataGenerator.makeConversationItem(id: convID, subject: "Forward", lastReplyPreview: nil)],
            nextCursor: "cursor-1",
            nextBefore: "before-1",
            hasMore: false
        )
        URLProtocolMock.stubConversationsBackwards([], nextBefore: nil, hasMore: false)

        let available = await loader.ensureAvailable(conversationID: convID)

        XCTAssertTrue(available)
        let stored = await MainActor.run { self.testContainer.fetchConversation(id: convID) }
        XCTAssertEqual(stored?.subject, "Forward")
        XCTAssertTrue(
            backwardRequests().isEmpty,
            "the history backfill must not run once the forward sync has found the conversation"
        )
    }

    func testAConversationOnlyInHistoryIsFetchedByTheBackwardSync() async {
        let convID = UUID()
        // Forward page: nothing new, but a backwards cursor to follow.
        URLProtocolMock.stubConversations([], nextCursor: "cursor-1", nextBefore: "before-1", hasMore: false)
        // Backward page: the conversation lives in history.
        URLProtocolMock.stubConversationsBackwards(
            [TestDataGenerator.makeConversationItem(id: convID, subject: "History", lastReplyPreview: nil)],
            nextBefore: nil,
            hasMore: false
        )

        let available = await loader.ensureAvailable(conversationID: convID)

        XCTAssertTrue(available)
        let stored = await MainActor.run { self.testContainer.fetchConversation(id: convID) }
        XCTAssertEqual(stored?.subject, "History")
    }

    func testAFailingForwardSyncReportsUnavailableInsteadOfHanging() async {
        URLProtocolMock.stub { request in
            guard request.url?.path.contains("/conversations") == true else { return nil }
            return .failure(error: URLError(.badServerResponse), statusCode: 500)
        }

        let available = await loader.ensureAvailable(conversationID: UUID())

        XCTAssertFalse(available)
        XCTAssertEqual(
            URLProtocolMock.callCount(),
            1,
            "one forward attempt; a fresh store has no history cursor to follow"
        )
        XCTAssertTrue(backwardRequests().isEmpty)
    }

    func testAConversationNowhereOnTheServerIsReportedUnavailable() async {
        URLProtocolMock.stubConversations([], nextCursor: "cursor-1", nextBefore: "before-1", hasMore: false)
        URLProtocolMock.stubConversationsBackwards([], nextBefore: nil, hasMore: false)

        let available = await loader.ensureAvailable(conversationID: UUID())

        XCTAssertFalse(available)
    }

    /// Pins the outcome, not the layer: the loader returns early on cancellation, and even
    /// without that `ConversationSync.syncBackward` cancels its own task before it reads the
    /// cursor. Removing both is what this test catches; removing one alone is not observable.
    func testACancelledFetchStopsBeforeTheHistoryBackfill() async {
        // Seed a history cursor first, so a backfill that ran anyway would have somewhere to go
        // and would show up in the call log.
        URLProtocolMock.stubConversations([], nextCursor: "cursor-1", nextBefore: "before-1", hasMore: false)
        _ = await conversationSync.sync()
        URLProtocolMock.reset()

        // Leaving the screen mid-fetch: the forward request's own stub cancels the fetch while
        // that request is in flight, so the cancellation is a fact of the test, not a race won
        // against a response delay.
        let fetch = CancellableFetch()
        URLProtocolMock.stub { request in
            guard let url = request.url,
                url.path.contains("/conversations"),
                url.queryParameters?["before"] == nil
            else { return nil }
            fetch.cancelOnceStarted()
            let response = ConversationsSyncResponse(
                conversations: [],
                included: nil,
                nextCursor: "cursor-2",
                nextBefore: "before-1",
                hasMore: false
            )
            return .success(object: response)
        }
        URLProtocolMock.stubConversationsBackwards([], nextBefore: nil, hasMore: false)

        let loader = self.loader!
        let conversationID = UUID()
        fetch.start(Task { await loader.ensureAvailable(conversationID: conversationID) })
        let available = await fetch.value()

        XCTAssertFalse(available)
        XCTAssertTrue(fetch.didCancel, "the forward request never reached the stub, so nothing was cancelled")
        XCTAssertFalse(fetch.timedOutWaitingToStart, "the forward request arrived before the fetch task was registered")
        XCTAssertTrue(
            backwardRequests().isEmpty,
            "a fetch cancelled during the forward sync must not start the history backfill"
        )
    }

    // MARK: - Helpers

    /// Requests that followed the history cursor, as opposed to forward polls.
    private func backwardRequests() -> [URLRequest] {
        URLProtocolMock.getCallLog().filter { $0.url?.queryParameters?["before"] != nil }
    }
}

/// Lets a stub handler, which runs on a URL loading thread, cancel the fetch task the test is
/// about to await. The handler may fire before the test has registered the task, so it waits on
/// the registration rather than reading a possibly-nil reference.
private final class CancellableFetch: @unchecked Sendable {
    private let registered = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var task: Task<Bool, Never>?
    private var hasTimedOutWaitingToStart = false
    private var hasCancelled = false

    /// True once the stub handler gave up waiting for the task to be registered.
    var timedOutWaitingToStart: Bool { lock.withLock { hasTimedOutWaitingToStart } }
    /// True once the stub handler actually cancelled the task; proves the handler ran at all.
    var didCancel: Bool { lock.withLock { hasCancelled } }

    func start(_ task: Task<Bool, Never>) {
        lock.withLock { self.task = task }
        registered.signal()
    }

    func cancelOnceStarted() {
        guard registered.wait(timeout: .now() + 5) == .success else {
            lock.withLock { hasTimedOutWaitingToStart = true }
            return
        }
        lock.withLock {
            task?.cancel()
            hasCancelled = true
        }
    }

    func value() async -> Bool {
        guard let task = lock.withLock({ task }) else {
            return false
        }
        return await task.value
    }
}
