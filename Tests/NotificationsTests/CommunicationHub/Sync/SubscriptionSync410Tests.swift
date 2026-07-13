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

/// Covers the subscriptions side of the unified 410 reset: syncing through `SubscriptionSync`
/// routes through `HubSyncCoordinator`, so a 410 anywhere drops the store and
/// generation-guards the save.
final class SubscriptionSync410Tests: SubscriptionSyncTestBase {

    func testSubscriptions410DuringSyncLeavesStoreEmpty() async throws {
        // Seed an existing subscription so we can prove it was dropped, not just absent.
        try await MainActor.run {
            let subscription = Subscription(context: testContainer.viewContext)
            subscription.id = "existing-subscription"
            subscription.name = "Existing Subscription"
            subscription.status = "published"
            subscription.optIn = true
            try testContainer.viewContext.save()
        }

        URLProtocolMock.stubSubscriptions410()

        let result = await subscriptionSync.sync()
        XCTAssertFalse(result, "Sync should report failure on 410")

        // The reset triggered by the 410 is detached from call() (see HubSyncCoordinator);
        // await it explicitly before asserting on post-reset store state.
        await hubSyncCoordinator.awaitCurrentReset()

        let subscriptions = await fetchAllSubscriptions()
        XCTAssertTrue(subscriptions.isEmpty, "410 during subscription sync should drop all subscriptions")
    }

    func testStaleGenerationDuringSubscriptionSyncIsNotPersisted() async throws {
        let subscription = createTestSubscriptions(count: 1).first!
        // Delay the response so we can bump the shared generation while the request is in-flight.
        URLProtocolMock.stubSubscriptions([subscription], delay: 0.1)

        async let syncResult = subscriptionSync.sync()

        // Give the sync task a moment to capture the generation and issue the request before
        // the store is reset out from under it.
        try await Task.sleep(nanoseconds: 20_000_000)
        await MainActor.run { testContainer.bumpConversationStoreGeneration() }

        let result = await syncResult
        XCTAssertFalse(result, "Sync should report failure when the generation moved mid-flight")

        let subscriptions = await fetchAllSubscriptions()
        XCTAssertTrue(subscriptions.isEmpty, "A stale (generation-bumped) response must not be persisted")
    }
}
