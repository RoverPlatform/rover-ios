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

final class SubscriptionSyncTests: SubscriptionSyncTestBase {

    // MARK: - Tests

    func testSuccessfulSyncUpsertSubscriptionsAndReturnsTrue() async {
        let subscriptions = TestDataGenerator.createTestSubscriptions(count: 3)
        URLProtocolMock.stubSubscriptions(subscriptions)

        let result = await subscriptionSync.sync()

        XCTAssertTrue(result, "sync() should return true on success")
        let saved = await fetchAllSubscriptions()
        XCTAssertEqual(saved.count, 3, "All 3 subscriptions should be persisted to Core Data")
        XCTAssertTrue(
            saved.contains(where: { $0.id == "subscription-0" }),
            "subscription-0 should be present in Core Data"
        )
    }

    func testNetworkFailureReturnsFalseAndWritesNothing() async {
        URLProtocolMock.stubSubscriptionsError(URLError(.networkConnectionLost), statusCode: 0)

        let result = await subscriptionSync.sync()

        XCTAssertFalse(result, "sync() should return false on network failure")
        let saved = await fetchAllSubscriptions()
        XCTAssertEqual(saved.count, 0, "No subscriptions should be written to Core Data on failure")
    }

    func testConcurrentSyncCallsCoalesce() async {
        URLProtocolMock.setNetworkLatency(0.2)
        let subscriptions = TestDataGenerator.createTestSubscriptions(count: 2)
        URLProtocolMock.stubSubscriptions(subscriptions)

        let results = await withTaskGroup(of: Bool.self) { group in
            group.addTask { await self.subscriptionSync.sync() }
            group.addTask { await self.subscriptionSync.sync() }
            group.addTask { await self.subscriptionSync.sync() }
            var all: [Bool] = []
            for await result in group { all.append(result) }
            return all
        }

        XCTAssertTrue(results.allSatisfy { $0 }, "All coalesced sync() calls should return true")
        let calls = URLProtocolMock.getCallLog()
            .filter { $0.url?.path.contains("/subscriptions") == true }
            .count
        XCTAssertEqual(
            calls,
            1,
            "Only one subscriptions request should be made despite 3 concurrent sync() calls"
        )
    }

    func testSyncWaitsForContainerToLoad() async {
        // Reset published flag to force performActualSync() into the wait loop.
        // The Core Data stack is already initialised - only the flag is being manipulated.
        await MainActor.run { testContainer.state = .loading }

        let subscriptions = TestDataGenerator.createTestSubscriptions(count: 1)
        URLProtocolMock.stubSubscriptions(subscriptions)

        let syncTask = Task { await subscriptionSync.sync() }

        await Task.yield()
        await MainActor.run { testContainer.state = .loaded }

        let networkCallSeen = await waitUntil {
            URLProtocolMock.getCallLog()
                .filter { $0.url?.path.contains("/subscriptions") == true }
                .isEmpty == false
        }
        XCTAssertTrue(networkCallSeen, "sync() should make a network call once the container transitions to .loaded")

        let result = await syncTask.value
        XCTAssertTrue(result, "sync() must succeed once the container transitions to .loaded")
        let saved = await fetchAllSubscriptions()
        XCTAssertEqual(saved.count, 1, "Subscriptions should be persisted after the container finishes loading")
    }
}
