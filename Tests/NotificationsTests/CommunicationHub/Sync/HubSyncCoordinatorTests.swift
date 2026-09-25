import CoreData
import XCTest

@testable import RoverData
@testable import RoverNotifications

final class HubSyncCoordinatorTests: HubSyncTestBase {

    var coordinator: HubSyncCoordinator!
    var spyNotificationCenter: SpyDeliveredNotificationCenter!

    override func setUp() async throws {
        try await super.setUp()
        spyNotificationCenter = SpyDeliveredNotificationCenter()
        coordinator = await MainActor.run {
            HubSyncCoordinator(
                httpClient: httpClient,
                persistentContainer: testContainer,
                seenWatermark: seenWatermark,
                notificationCenter: spyNotificationCenter.asDeliveredNotificationCenter()
            )
        }
    }

    override func tearDown() async throws {
        coordinator = nil
        spyNotificationCenter = nil
        try await super.tearDown()
    }

    // MARK: - 410 triggers invalidation

    func testConversations410TriggersDropAndCancellation() async throws {
        let cancellable = MockHubSyncCancellable()
        await coordinator.register(cancellable)

        try await seedConversation()
        try await seedPost()
        URLProtocolMock.stubConversations410()

        _ = await coordinator.getConversationsPage()
        await coordinator.awaitCurrentReset()

        let convCount = await MainActor.run {
            (try? testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(convCount, 0, "410 on conversations should drop all conversations")

        let postCount = await MainActor.run {
            (try? testContainer.viewContext.count(for: Post.fetchRequest())) ?? -1
        }
        XCTAssertEqual(postCount, 0, "410 on conversations should drop all posts too (unified reset)")

        let cancelCount = await cancellable.cancelCallCount
        XCTAssertEqual(cancelCount, 1, "cancelAllTasks() should be called once on 410")
    }

    func testReplies410TriggersDropAndCancellation() async throws {
        let cancellable = MockHubSyncCancellable()
        await coordinator.register(cancellable)

        let convID = try await seedConversation()
        URLProtocolMock.stubReplies410(conversationID: convID)

        _ = await coordinator.getRepliesPage(conversationID: convID, cursor: .forward(nil))
        await coordinator.awaitCurrentReset()

        let convCount = await MainActor.run {
            (try? testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(convCount, 0, "410 on replies should drop all conversations")
        let cancelCount = await cancellable.cancelCallCount
        XCTAssertEqual(cancelCount, 1, "cancelAllTasks() should be called once on 410")
    }

    func testSendReply410TriggersDropAndCancellation() async throws {
        let cancellable = MockHubSyncCancellable()
        await coordinator.register(cancellable)

        let convID = try await seedConversation()
        URLProtocolMock.stubSendReply410(conversationID: convID)

        _ = await coordinator.sendReply(
            conversationID: convID,
            content: [.text(text: "hello")],
            externalID: UUID().uuidString
        )
        await coordinator.awaitCurrentReset()

        let convCount = await MainActor.run {
            (try? testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(convCount, 0, "410 on sendReply should drop all conversations")
        let cancelCount = await cancellable.cancelCallCount
        XCTAssertEqual(cancelCount, 1, "cancelAllTasks() should be called once on 410")
    }

    func testMarkConversationRead410TriggersDropAndCancellation() async throws {
        let cancellable = MockHubSyncCancellable()
        await coordinator.register(cancellable)

        let convID = try await seedConversation()
        URLProtocolMock.stubMarkRead410(conversationID: convID)

        _ = await coordinator.markConversationRead(conversationID: convID, lastReadReplyID: nil)
        await coordinator.awaitCurrentReset()

        let convCount = await MainActor.run {
            (try? testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(convCount, 0, "410 on markConversationRead should drop all conversations")
        let cancelCount = await cancellable.cancelCallCount
        XCTAssertEqual(cancelCount, 1, "cancelAllTasks() should be called once on 410")
    }

    func testParticipants410TriggersDropAndCancellation() async throws {
        let cancellable = MockHubSyncCancellable()
        await coordinator.register(cancellable)

        try await seedConversation()
        URLProtocolMock.stubParticipants410()

        _ = await coordinator.getParticipants()
        await coordinator.awaitCurrentReset()

        let convCount = await MainActor.run {
            (try? testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(convCount, 0, "410 on participants should drop all conversations")
        let cancelCount = await cancellable.cancelCallCount
        XCTAssertEqual(cancelCount, 1, "cancelAllTasks() should be called once on 410")
    }

    func testPosts410TriggersDropAndCancellation() async throws {
        let cancellable = MockHubSyncCancellable()
        await coordinator.register(cancellable)

        try await seedConversation()
        try await seedPost()
        URLProtocolMock.stubPosts410()

        _ = await coordinator.getPosts(from: nil)
        await coordinator.awaitCurrentReset()

        let convCount = await MainActor.run {
            (try? testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(convCount, 0, "410 on posts should drop all conversations too (unified reset)")

        let postCount = await MainActor.run {
            (try? testContainer.viewContext.count(for: Post.fetchRequest())) ?? -1
        }
        XCTAssertEqual(postCount, 0, "410 on posts should drop all posts")

        let cancelCount = await cancellable.cancelCallCount
        XCTAssertEqual(cancelCount, 1, "cancelAllTasks() should be called once on 410")
    }

    func testSubscriptions410TriggersDropAndCancellation() async throws {
        let cancellable = MockHubSyncCancellable()
        await coordinator.register(cancellable)

        try await seedConversation()
        try await seedPost()
        try await seedSubscription()
        URLProtocolMock.stubSubscriptions410()

        _ = await coordinator.getSubscriptions()
        await coordinator.awaitCurrentReset()

        let convCount = await MainActor.run {
            (try? testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(convCount, 0, "410 on subscriptions should drop all conversations too (unified reset)")

        let postCount = await MainActor.run {
            (try? testContainer.viewContext.count(for: Post.fetchRequest())) ?? -1
        }
        XCTAssertEqual(postCount, 0, "410 on subscriptions should drop all posts too (unified reset)")

        let subscriptionCount = await MainActor.run {
            (try? testContainer.viewContext.count(for: Subscription.fetchRequest())) ?? -1
        }
        XCTAssertEqual(subscriptionCount, 0, "410 on subscriptions should drop all subscriptions")

        let cancelCount = await cancellable.cancelCallCount
        XCTAssertEqual(cancelCount, 1, "cancelAllTasks() should be called once on 410")
    }

    // MARK: - Reset advances the inbox seen watermark

    func testPosts410AdvancesTheInboxSeenWatermark() async throws {
        let seeded = await MainActor.run { seenWatermark.lastSeenAt }
        // UserDefaults dates round-trip through JSON, so ensure a measurable gap.
        Thread.sleep(forTimeInterval: 0.01)

        try await seedPost()
        URLProtocolMock.stubPosts410()

        _ = await coordinator.getPosts(from: nil)
        await coordinator.awaitCurrentReset()

        let advanced = await MainActor.run { seenWatermark.lastSeenAt }
        XCTAssertGreaterThan(
            advanced,
            seeded,
            "A 410 reset must advance the watermark so refetched history does not re-badge"
        )
    }

    func testNon410ErrorDoesNotAdvanceTheInboxSeenWatermark() async throws {
        let seeded = await MainActor.run { seenWatermark.lastSeenAt }
        Thread.sleep(forTimeInterval: 0.01)

        URLProtocolMock.stubPostsError(URLError(.badServerResponse))

        _ = await coordinator.getPosts(from: nil)

        let unchanged = await MainActor.run { seenWatermark.lastSeenAt }
        XCTAssertEqual(unchanged.timeIntervalSince1970, seeded.timeIntervalSince1970, accuracy: 0.002)
    }

    // MARK: - Non-410 errors do NOT trigger invalidation

    func testNon410ErrorDoesNotTriggerDrop() async throws {
        let cancellable = MockHubSyncCancellable()
        await coordinator.register(cancellable)

        try await seedConversation()
        URLProtocolMock.stub { request in
            guard let url = request.url, url.path.contains("/conversations") else {
                return nil
            }
            return .failure(error: URLError(.badServerResponse), statusCode: 500, delay: 0)
        }

        _ = await coordinator.getConversationsPage()

        let convCount = await MainActor.run {
            (try? testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(convCount, 1, "Non-410 error must not drop conversations")
        let cancelCount = await cancellable.cancelCallCount
        XCTAssertEqual(cancelCount, 0, "cancelAllTasks() must not be called for non-410 errors")
    }

    // MARK: - Multiple registered cancellables are all cancelled in parallel

    func testAllRegisteredCancellablesAreCancelledOn410() async throws {
        let c1 = MockHubSyncCancellable()
        let c2 = MockHubSyncCancellable()
        let c3 = MockHubSyncCancellable()
        let postSync = await MainActor.run {
            PostSync(persistentContainer: testContainer, hubSyncCoordinator: coordinator)
        }
        let postSyncSpy = SpyPostSyncCancellable(postSync: postSync)
        let subscriptionSync = SubscriptionSync(persistentContainer: testContainer, hubSyncCoordinator: coordinator)
        let subscriptionSyncSpy = SpySubscriptionSyncCancellable(subscriptionSync: subscriptionSync)
        await coordinator.register(c1)
        await coordinator.register(c2)
        await coordinator.register(c3)
        await coordinator.register(postSyncSpy)
        await coordinator.register(subscriptionSyncSpy)

        try await seedConversation()
        URLProtocolMock.stubConversations410()

        _ = await coordinator.getConversationsPage()
        await coordinator.awaitCurrentReset()

        for (i, cancellable) in [c1, c2, c3].enumerated() {
            let count = await cancellable.cancelCallCount
            XCTAssertEqual(count, 1, "Cancellable \(i) should have cancelAllTasks() called once")
        }
        let postSyncCancelCount = await postSyncSpy.cancelCallCount
        XCTAssertEqual(postSyncCancelCount, 1, "PostSync should also be cancelled — unified reset spans both domains")
        let subscriptionSyncCancelCount = await subscriptionSyncSpy.cancelCallCount
        XCTAssertEqual(
            subscriptionSyncCancelCount,
            1,
            "SubscriptionSync should also be cancelled — unified reset spans all three domains"
        )
    }

    // MARK: - Double-invalidation is coalesced into one logical reset

    func testConcurrent410sCoalesceIntoSingleInvalidation() async throws {
        let cancellable = MockHubSyncCancellable()
        // Holds the reset the first 410 starts open until this test says otherwise, so the second
        // 410 cannot possibly find `invalidationTask` back at nil and start a reset of its own.
        // Coalescing is only promised for the lifetime of that handle, and with nothing registered
        // that does real work in cancellation, that lifetime was measured in the tens of
        // microseconds. The barrier below releases the two 410s together, but they are still
        // resumed on independent threads, so without this gate the assertions would be a bet on
        // the two being *processed* closer together than that — which they are not under load.
        // Releasing together is not arriving together. A second reset here is not a coordinator
        // bug, it is the documented behaviour `testSequential410sEachTriggerReset` pins down.
        let resetGate = GatedMockHubSyncCancellable()
        let postSync = await MainActor.run {
            PostSync(persistentContainer: testContainer, hubSyncCoordinator: coordinator)
        }
        let postSyncSpy = SpyPostSyncCancellable(postSync: postSync)
        let subscriptionSync = SubscriptionSync(persistentContainer: testContainer, hubSyncCoordinator: coordinator)
        let subscriptionSyncSpy = SpySubscriptionSyncCancellable(subscriptionSync: subscriptionSync)
        await coordinator.register(cancellable)
        await coordinator.register(resetGate)
        await coordinator.register(postSyncSpy)
        await coordinator.register(subscriptionSyncSpy)

        try await seedConversation()
        // Neither 410 is answered until both requests have arrived. That is what makes this a test
        // of `startResetIfNeeded`'s in-flight guard: both calls are past `call()`'s prologue guard
        // before either reset exists, so the second 410 can only be turned away by the guard under
        // test. A response delay would merely have made that likely — a request cannot be answered
        // early here, however the machine is loaded, because the answer is gated on its sibling's
        // arrival rather than on a clock.
        URLProtocolMock.requireSimultaneousRequests(2)
        URLProtocolMock.stubConversations410()

        // Fire two concurrent 410-bound calls
        async let r1 = coordinator.getConversationsPage()
        async let r2 = coordinator.getConversationsPage()
        _ = await (r1, r2)

        // Both calls have returned, so each has either had its 410 handled or been turned away in
        // the prologue, and exactly one reset was started — `resetGate` is still holding it, since
        // no reset can get past `cancelRegisteredSyncWork()` until this test says so. Only now is
        // it safe to let it finish. Both calls return StaleGenerationError immediately because the
        // reset runs independently of them (see HubSyncCoordinator.startResetIfNeeded), so awaiting
        // it is what puts the drops behind us before the store is inspected.
        await resetGate.release()
        await coordinator.awaitCurrentReset()

        // If the barrier gave up, its quota was not met in time, so everything below was observed
        // under conditions this test does not describe — whatever the two requests went on to do.
        XCTAssertFalse(
            URLProtocolMock.didTimeOutWaitingForSimultaneousRequests,
            "both conversation requests must have been in flight before either 410 was answered; "
                + "the barrier timed out waiting for the second one instead"
        )

        // Store is empty
        let convCount = await MainActor.run {
            (try? testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(convCount, 0, "Store should be empty after concurrent 410s")

        // cancelAllTasks() was invoked exactly once — the in-flight-reset guard prevented the second run
        let cancelCount = await cancellable.cancelCallCount
        XCTAssertEqual(cancelCount, 1, "the in-flight-reset guard must coalesce concurrent 410s into one invalidation")

        let postSyncCancelCount = await postSyncSpy.cancelCallCount
        XCTAssertEqual(
            postSyncCancelCount,
            1,
            "the in-flight-reset guard must coalesce concurrent 410s into one invalidation for PostSync too"
        )

        let subscriptionSyncCancelCount = await subscriptionSyncSpy.cancelCallCount
        XCTAssertEqual(
            subscriptionSyncCancelCount,
            1,
            "the in-flight-reset guard must coalesce concurrent 410s into one invalidation for SubscriptionSync too"
        )
    }

    // MARK: - Sequential 410s each trigger their own reset

    /// Regression test: each sequential 410 (on a *separate* sync, not concurrent) must run its
    /// own full reset, so a store repopulated between syncs is dropped again rather than the
    /// reset being silently skipped.
    func testSequential410sEachTriggerReset() async throws {
        let cancellable = MockHubSyncCancellable()
        await coordinator.register(cancellable)

        try await seedConversation()
        URLProtocolMock.stubConversations410()

        // First sync: 410 → reset.
        _ = await coordinator.getConversationsPage()
        await coordinator.awaitCurrentReset()

        let countAfterFirst = await MainActor.run {
            (try? testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(countAfterFirst, 0, "First 410 should drop conversations")

        // Store gets repopulated by some later successful activity...
        try await seedConversation()

        // Second sync, still 410 → must reset again, not be silently skipped.
        _ = await coordinator.getConversationsPage()
        await coordinator.awaitCurrentReset()

        let countAfterSecond = await MainActor.run {
            (try? testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(countAfterSecond, 0, "Second 410 must also drop the repopulated conversation")

        let cancelCount = await cancellable.cancelCallCount
        XCTAssertEqual(cancelCount, 2, "Each sequential 410 must trigger its own reset")
    }

    // MARK: - Deadlock regression

    /// Regression test for a self-join deadlock: if the reset ran *inline* on the failing call's
    /// stack, and that stack belonged to a registered actor's own tracked task — exactly the
    /// shape here, where a real `ConversationSync` is registered as a cancellable and driven
    /// through its own `sync()` (not through the coordinator directly) — `cancelAllTasks()` would
    /// await the very task it was running on, hanging forever. Every production 410 path has this
    /// shape, so this is the realistic repro; a test that only triggers 410s from its own task,
    /// never from inside a registered actor's tracked task, would never catch this.
    ///
    /// The `XCTestExpectation` + `fulfillment(timeout:)` guard turns a reintroduced deadlock into
    /// a clean failure instead of hanging the whole suite.
    func testConversationSyncThroughRealActorDoesNotDeadlockOn410() async throws {
        let realConversationSync = ConversationSync(
            persistentContainer: testContainer,
            hubSyncCoordinator: coordinator
        )
        await coordinator.register(realConversationSync)

        try await seedConversation()
        URLProtocolMock.stubConversations410()

        // (a) sync() returns within the timeout — does not deadlock.
        let firstResult = try await runWithTimeoutGuard(description: "first sync()") {
            await realConversationSync.sync()
        }
        XCTAssertFalse(firstResult, "sync() should report failure on 410")

        // (b) after awaiting the reset, the store is dropped.
        await coordinator.awaitCurrentReset()
        let countAfterFirst = await MainActor.run {
            (try? testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(countAfterFirst, 0, "410 driven through a tracked sync task must still drop the store")

        // (c) a SECOND 410-driven sync (after reseeding) also completes and drops again.
        try await seedConversation()
        let secondResult = try await runWithTimeoutGuard(description: "second sync()") {
            await realConversationSync.sync()
        }
        XCTAssertFalse(secondResult, "second sync() should also report failure on 410")

        await coordinator.awaitCurrentReset()
        let countAfterSecond = await MainActor.run {
            (try? testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(countAfterSecond, 0, "a second 410-through-sync must reset again, not be silently skipped")

        // (d) after clearing stubs and stubbing a successful response, a third sync() succeeds
        // and repopulates.
        URLProtocolMock.reset()
        let recoveredConvID = UUID()
        URLProtocolMock.stubConversations(
            [TestDataGenerator.makeConversationItem(id: recoveredConvID, subject: "Recovered")],
            nextCursor: nil,
            nextBefore: nil,
            hasMore: false,
            included: nil
        )
        let thirdResult = try await runWithTimeoutGuard(description: "third sync()") {
            await realConversationSync.sync()
        }
        XCTAssertTrue(thirdResult, "sync() should succeed once the endpoint recovers")

        let countAfterThird = await MainActor.run {
            (try? testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(countAfterThird, 1, "a successful sync after a reset should repopulate the store")
    }

    /// Runs `operation` on its own `Task` and waits for it via an `XCTestExpectation`, so that a
    /// regression back to the self-join deadlock fails this test after `timeout` instead of
    /// hanging the entire test process.
    private func runWithTimeoutGuard<T: Sendable>(
        description: String,
        timeout: TimeInterval = 5,
        _ operation: @escaping @Sendable () async -> T
    ) async throws -> T {
        let expectation = XCTestExpectation(description: description)
        let box = ResultBox<T>()
        Task {
            let value = await operation()
            await box.set(value)
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: timeout)
        let result = await box.get()
        return try XCTUnwrap(result, "\(description) did not complete within \(timeout)s — possible deadlock")
    }

    // MARK: - Re-enable: second sync after invalidation proceeds normally

    func testSecondSyncAfterInvalidationProceedsNormally() async throws {
        try await seedConversation()
        URLProtocolMock.stubConversations410()
        _ = await coordinator.getConversationsPage()
        // Real callers only retry once the reset has actually finished (e.g. on the next sync
        // cadence) — `call()` now fails fast for the full lifetime of the reset, so a call fired
        // before it completes is expected to fail, not "proceed normally".
        await coordinator.awaitCurrentReset()

        let newConvID = UUID()
        URLProtocolMock.reset()
        URLProtocolMock.stubConversations(
            [TestDataGenerator.makeConversationItem(id: newConvID, subject: "Fresh")],
            nextCursor: nil,
            nextBefore: nil,
            hasMore: false,
            included: nil
        )

        let response = await coordinator.getConversationsPage()
        if case .failure(let error) = response.result {
            XCTFail("Second sync should succeed, got error: \(error)")
        }
    }

    // MARK: - Calls during an in-flight reset are rejected

    /// Regression test: `call()` must fail fast for the *entire* lifetime of an in-flight reset,
    /// not just at the instant a 410 is detected. `runReset()` bumps the shared generation epoch
    /// before cancellation or drops run ("epoch-first invalidation"), so a completely unrelated
    /// call that starts once the epoch has moved — but before the drops finish — would otherwise
    /// capture the already-bumped generation, read pre-drop cursor state, succeed, and pass
    /// `saveIfGenerationUnchanged`, repopulating the store from stale pre-reset state instead of
    /// forcing a clean post-reset resync.
    func testCallDuringInFlightResetIsRejected() async throws {
        // A gated cancellable keeps the reset in flight until this test releases it, so the call
        // fired below lands inside the reset's lifetime however the machine is loaded.
        let resetGate = GatedMockHubSyncCancellable()
        await coordinator.register(resetGate)

        try await seedConversation()
        URLProtocolMock.stubConversations410()
        URLProtocolMock.stubParticipants([])

        _ = await coordinator.getConversationsPage()  // triggers the reset; returns immediately

        // Fired while `invalidationTask` is non-nil and `resetGate` is keeping it that way — which
        // is the whole lifetime the rejection is promised for, whether or not the reset task body
        // has reached cancellation yet. Must not be allowed to succeed against pre-drop state.
        let duringReset = await coordinator.getParticipants()

        await resetGate.release()
        await coordinator.awaitCurrentReset()

        guard case .failure(let error) = duringReset.result else {
            XCTFail("Expected a call issued during an in-flight reset to fail fast, but it succeeded")
            return
        }
        XCTAssertTrue(
            error is StaleGenerationError,
            "Expected StaleGenerationError for a call rejected mid-reset, got \(error)"
        )
    }

    // MARK: - Reset on request, with no 410 behind it

    /// Everything the Debug tab's "Reset Hub Data" row promises: every domain dropped, in one
    /// pass, through the store the Hub is holding open.
    ///
    /// `testContainer` is in-memory, which is also where a device lands when the SQLite store
    /// fails to load and `InboxPersistentContainer` falls back. A reset expressed as "destroy
    /// the store at its URL" only reaches such a container by way of the `file:///dev/null`
    /// placeholder Core Data happens to hand an in-memory store, which is not a promise
    /// documented anywhere; dropping rows through the context is storage-mode-agnostic and
    /// needs no such luck.
    func testResetOnDemandDropsEveryDomain() async throws {
        let cancellable = MockHubSyncCancellable()
        await coordinator.register(cancellable)

        try await seedConversation()
        try await seedPost()
        try await seedSubscription()
        try await seedSyncCursors()

        await MainActor.run { coordinator.resetHubDataOnDemand() }
        await coordinator.awaitCurrentReset()

        let counts = await MainActor.run {
            (
                conversations: (try? testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1,
                posts: (try? testContainer.viewContext.count(for: Post.fetchRequest())) ?? -1,
                subscriptions: (try? testContainer.viewContext.count(for: Subscription.fetchRequest())) ?? -1,
                syncStatuses: (try? testContainer.viewContext.count(for: SyncStatus.fetchRequest())) ?? -1
            )
        }
        XCTAssertEqual(counts.conversations, 0, "an on-demand reset should drop all conversations")
        XCTAssertEqual(counts.posts, 0, "an on-demand reset should drop all posts")
        XCTAssertEqual(counts.subscriptions, 0, "an on-demand reset should drop all subscriptions")
        XCTAssertEqual(
            counts.syncStatuses,
            0,
            "the cursors go with the rows, or the next sync resumes mid-stream instead of refetching"
        )

        let cancelCount = await cancellable.cancelCallCount
        XCTAssertEqual(cancelCount, 1, "an on-demand reset should cancel in-flight sync, exactly as a 410 does")
    }

    /// The half of the reset a bare drop would miss: a sync that was already awaiting HTTP when
    /// the reset ran.
    ///
    /// `call()` captures the store generation before the network await, and the response is
    /// persisted under that captured value. A reset that drops rows without moving the epoch
    /// leaves that captured value still current, so the response — fetched from a pre-reset
    /// cursor, and possibly from the endpoint being left behind — passes
    /// `saveIfGenerationUnchanged` and repopulates the store that was just emptied.
    func testResetOnDemandRefusesASaveCapturedBeforeIt() async throws {
        let cancellable = MockHubSyncCancellable()
        await coordinator.register(cancellable)
        try await seedConversation()

        // What `call()` hands to a sync that is still awaiting HTTP when the reset arrives.
        let capturedGeneration = await MainActor.run { testContainer.conversationStoreGeneration }

        await MainActor.run { coordinator.resetHubDataOnDemand() }
        await coordinator.awaitCurrentReset()

        let generationAfter = await MainActor.run { testContainer.conversationStoreGeneration }
        XCTAssertEqual(
            generationAfter,
            capturedGeneration + 1,
            "an on-demand reset must move the epoch, or nothing invalidates the responses already in flight"
        )

        try await MainActor.run {
            // The late response landing: it writes its page, then asks to save under the
            // generation it captured before the reset.
            let stale = Conversation(context: testContainer.viewContext)
            stale.id = UUID()
            stale.createdAt = Date()
            stale.updatedAt = Date()

            XCTAssertThrowsError(try testContainer.saveIfGenerationUnchanged(capturedGeneration)) { error in
                XCTAssertTrue(
                    error is StaleGenerationError,
                    "expected StaleGenerationError for a response captured before the reset, got \(error)"
                )
            }
            XCTAssertEqual(
                (try? testContainer.viewContext.count(for: Conversation.fetchRequest())) ?? -1,
                0,
                "a response captured before the reset must not repopulate the store behind it"
            )
        }
    }

    /// A call that starts while the reset is still unwinding is held off the same way one that
    /// starts during a 410 reset is: it would otherwise capture the epoch the reset just moved
    /// to, read a cursor the drops had not reached, and persist behind them.
    func testCallDuringOnDemandResetIsRejected() async throws {
        let resetGate = GatedMockHubSyncCancellable()
        await coordinator.register(resetGate)

        try await seedConversation()
        URLProtocolMock.stubParticipants([])

        await MainActor.run { coordinator.resetHubDataOnDemand() }
        let duringReset = await coordinator.getParticipants()
        await resetGate.release()
        await coordinator.awaitCurrentReset()

        guard case .failure(let error) = duringReset.result else {
            XCTFail("Expected a call issued during an in-flight on-demand reset to fail fast, but it succeeded")
            return
        }
        XCTAssertTrue(
            error is StaleGenerationError,
            "Expected StaleGenerationError for a call rejected mid-reset, got \(error)"
        )
    }

    // MARK: - Notification clearing (pure function)

    private func postUserInfo(id: UUID = UUID()) -> [AnyHashable: Any] {
        ["rover": ["post": ["id": id.uuidString]]]
    }

    private func conversationUserInfo(id: UUID = UUID()) -> [AnyHashable: Any] {
        [
            "rover": [
                "conversation": ["id": id.uuidString],
                "reply": ["id": UUID().uuidString],
                "participant": ["id": "p1"]
            ]
        ]
    }

    func testHubNotificationIdentifiersMatchesPostPayload() {
        let delivered = [
            (identifier: "notif-post", userInfo: postUserInfo())
        ]
        let result = coordinator.hubNotificationIdentifiers(from: delivered)
        XCTAssertEqual(result, ["notif-post"])
    }

    func testHubNotificationIdentifiersMatchesConversationPayload() {
        let delivered = [
            (identifier: "notif-conv", userInfo: conversationUserInfo())
        ]
        let result = coordinator.hubNotificationIdentifiers(from: delivered)
        XCTAssertEqual(result, ["notif-conv"])
    }

    /// A delivered post notification and a delivered conversation notification are both selected —
    /// the store-ID-based predecessor cleared neither posts nor unsynced conversations.
    func testHubNotificationIdentifiersMatchesBothDomains() {
        let delivered = [
            (identifier: "notif-post", userInfo: postUserInfo()),
            (identifier: "notif-conv", userInfo: conversationUserInfo()),
            (identifier: "notif-none", userInfo: ["rover": ["action": ["url": "https://example.com"]]])
        ]
        let result = coordinator.hubNotificationIdentifiers(from: delivered)
        XCTAssertEqual(Set(result), Set(["notif-post", "notif-conv"]))
    }

    func testHubNotificationIdentifiersIgnoresNonHubPayload() {
        let delivered = [
            (identifier: "notif-action", userInfo: ["rover": ["action": ["url": "https://example.com"]]])
        ]
        let result = coordinator.hubNotificationIdentifiers(from: delivered)
        XCTAssertTrue(result.isEmpty)
    }

    func testHubNotificationIdentifiersIgnoresMalformedPayload() {
        let delivered = [
            (identifier: "notif-no-rover", userInfo: ["aps": ["alert": "hi"]] as [AnyHashable: Any]),
            (identifier: "notif-empty", userInfo: [:] as [AnyHashable: Any])
        ]
        let result = coordinator.hubNotificationIdentifiers(from: delivered)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Helpers

    @discardableResult
    private func seedConversation() async throws -> UUID {
        let id = UUID()
        try await MainActor.run {
            let conv = Conversation(context: testContainer.viewContext)
            conv.id = id
            conv.createdAt = Date()
            conv.updatedAt = Date()
            try testContainer.viewContext.save()
        }
        return id
    }

    @discardableResult
    private func seedPost() async throws -> UUID {
        let id = UUID()
        try await MainActor.run {
            let post = Post(context: testContainer.viewContext)
            post.id = id
            post.receivedAt = Date()
            post.isRead = false
            post.subject = "Test Post"
            post.previewText = "Test preview"
            post.url = URL(string: "https://example.com/post")!
            try testContainer.viewContext.save()
        }
        return id
    }

    /// A cursor for each paginated domain, so a reset can be asked whether it took them with it.
    private func seedSyncCursors() async throws {
        try await MainActor.run {
            for entity in [InboxPersistentContainer.SyncEntity.posts, .conversations] {
                let status = SyncStatus(context: testContainer.viewContext)
                status.roverEntity = entity.rawValue
                status.cursor = "cursor-\(entity.rawValue)"
            }
            try testContainer.viewContext.save()
        }
    }

    @discardableResult
    private func seedSubscription() async throws -> String {
        let id = "subscription-\(UUID().uuidString)"
        try await MainActor.run {
            let subscription = Subscription(context: testContainer.viewContext)
            subscription.id = id
            subscription.name = "Test Subscription"
            subscription.status = "published"
            subscription.optIn = true
            try testContainer.viewContext.save()
        }
        return id
    }
}

// MARK: - Mocks

/// Thread-safe box for bridging a value out of an unstructured `Task` — used by
/// `runWithTimeoutGuard` to hand a result back from the guarded `Task` to the awaiting test.
private actor ResultBox<T> {
    private var value: T?

    func set(_ value: T) {
        self.value = value
    }

    func get() -> T? {
        value
    }
}

actor MockHubSyncCancellable: HubSyncCancellable {
    private(set) var cancelCallCount: Int = 0

    func cancelAllTasks() async {
        cancelCallCount += 1
    }
}

/// A cancellable whose `cancelAllTasks()` suspends until the test calls `release()`, holding any
/// `HubSyncCoordinator` reset that reaches it open until then.
///
/// Everything a test can assert about a reset — that a concurrent 410 was coalesced into it, that
/// a call issued during it is rejected — holds only while `invalidationTask` is non-nil, and
/// `runReset()` is short enough (an epoch bump, one task group, one drop) that a sleep long enough
/// on an idle machine is a race under load. Suspending here instead makes the window a signal the
/// test owns rather than a duration it hopes for.
///
/// `cancelRegisteredSyncWork()` awaits every registered cancellable, so the reset cannot finish
/// while this one is suspended; because the suspension is on this actor rather than the
/// coordinator's, the main actor stays free to serve the calls the test makes meanwhile.
actor GatedMockHubSyncCancellable: HubSyncCancellable {
    private(set) var cancelCallCount: Int = 0
    /// Every waiter, not one slot: the regression `testConcurrent410sCoalesceIntoSingleInvalidation`
    /// exists to catch is precisely the one that starts a *second* reset, and both resets reach
    /// this gate. A single slot would overwrite the first reset's continuation and strand its task
    /// forever, turning the clean assertion failure that test is trying to produce into a leaked
    /// continuation. The gate's other two users only ever produce one reset.
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var isReleased = false

    func cancelAllTasks() async {
        cancelCallCount += 1
        guard !isReleased else { return }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    /// Lets every held reset finish, and keeps later ones from being held at all. Safe in either
    /// order: releasing before `cancelAllTasks()` is ever reached records the release rather than
    /// dropping a wake-up, so a test that no longer needs the window never hangs waiting for one —
    /// at the cost that the gate never actually suspended. No assertion here rests on it having
    /// suspended, given a coordinator that coalesces correctly: what the assertions rest on is
    /// `invalidationTask` staying non-nil, which holds from the moment the 410 is seen.
    func release() {
        isReleased = true
        let held = continuations
        continuations = []
        for continuation in held {
            continuation.resume()
        }
    }
}

/// Wraps a real `PostSync` so its `cancelAllTasks()` calls can be counted alongside the mock
/// cancellables, proving PostSync genuinely participates in the coordinator's registered set
/// (rather than only exercising a stand-in mock) as part of the unified hub reset.
actor SpyPostSyncCancellable: HubSyncCancellable {
    private let postSync: PostSync
    private(set) var cancelCallCount: Int = 0

    init(postSync: PostSync) {
        self.postSync = postSync
    }

    func cancelAllTasks() async {
        cancelCallCount += 1
        await postSync.cancelAllTasks()
    }
}

/// Wraps a real `SubscriptionSync` so its `cancelAllTasks()` calls can be counted alongside the
/// mock cancellables, proving SubscriptionSync genuinely participates in the coordinator's
/// registered set (rather than only exercising a stand-in mock) as part of the unified hub reset.
actor SpySubscriptionSyncCancellable: HubSyncCancellable {
    private let subscriptionSync: SubscriptionSync
    private(set) var cancelCallCount: Int = 0

    init(subscriptionSync: SubscriptionSync) {
        self.subscriptionSync = subscriptionSync
    }

    func cancelAllTasks() async {
        cancelCallCount += 1
        await subscriptionSync.cancelAllTasks()
    }
}

/// Spy for `DeliveredNotificationCenter` — records `removeDeliveredNotifications` calls.
///
/// `UNNotification` has no public initialiser, so `getDeliveredNotifications` always returns
/// an empty array. End-to-end notification-clearing behaviour is verified via the pure-function
/// `hubNotificationIdentifiers` tests above — the same pattern used by `NotificationHandlerService`.
final class SpyDeliveredNotificationCenter {
    private(set) var removedIdentifiers: [String] = []

    func asDeliveredNotificationCenter() -> DeliveredNotificationCenter {
        DeliveredNotificationCenter(
            getDeliveredNotifications: { [] },
            removeDeliveredNotifications: { [weak self] ids in
                self?.removedIdentifiers.append(contentsOf: ids)
            }
        )
    }
}
