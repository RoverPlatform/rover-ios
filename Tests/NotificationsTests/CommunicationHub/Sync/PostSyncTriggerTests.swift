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

/// Tests for PostSync triggers and SDK integration
final class PostSyncTriggerTests: PostSyncTestBase {

    // MARK: - Sync Trigger Tests

    /// Test sync initiation during app launch lifecycle
    func testAppLaunchSync() async {
        // Configure mock for successful sync
        configureMockForSuccess(subscriptions: [], posts: [])

        // Simulate app launch by directly calling sync on PostSync
        // In real app, this would be triggered by SyncCoordinator during app launch
        let syncResult = await postSync.sync()

        // Verify sync completed (returns false when no new posts available)
        XCTAssertFalse(
            syncResult,
            "App launch sync should return false when no new posts are available"
        )

        // Verify sync uses the posts endpoint with embedded subscriptions only
        let callLog = URLProtocolMock.getCallLog()
        assertPostSyncUsesPostsWithEmbeddedSubscriptions(callLog)

        // Test that persistence container is properly loaded before sync
        // This is handled internally by PostSync.performActualSync()
        let isLoaded = await MainActor.run { testContainer.state == .loaded }
        XCTAssertTrue(isLoaded, "Persistence container should be loaded during app launch sync")
    }

    /// Test sync triggered by silent push notifications
    func testBackgroundPushSync() async {
        // Configure mock for successful background sync
        let testSubscriptions = createTestSubscriptions(count: 2)
        let testPosts = createTestPosts(count: 3, subscriptionID: testSubscriptions.first?.id)

        configureMockForSuccess(subscriptions: testSubscriptions, posts: testPosts)

        // Simulate background push notification triggering sync
        // In real app, this would be triggered by SyncCoordinator.sync(completionHandler:)
        // when a silent push notification is received
        let syncResult = await postSync.sync()

        // Verify background sync was successful
        XCTAssertTrue(syncResult, "Background push sync should succeed")

        // Verify data was synced from the "background" API call
        let savedSubscriptions = await fetchAllSubscriptions()
        let savedPosts = await fetchAllPosts()

        XCTAssertEqual(savedSubscriptions.count, 2, "Background sync should save subscriptions")
        XCTAssertEqual(savedPosts.count, 3, "Background sync should save posts")

        // Verify background sync uses the posts endpoint with embedded subscriptions only
        let backgroundCallLog = URLProtocolMock.getCallLog()
        assertPostSyncUsesPostsWithEmbeddedSubscriptions(backgroundCallLog)

        let isLoaded = await MainActor.run { testContainer.state == .loaded }
        XCTAssertTrue(isLoaded, "Persistence container should finish loading before background sync proceeds")

        // Test that a single posts request can update subscriptions even when there are no new posts
        URLProtocolMock.reset()
        let refreshedSubscriptions = createTestSubscriptions(count: 3)
        URLProtocolMock.stubPosts(
            [],
            included: PostsSyncResponse.IncludedData(subscriptions: refreshedSubscriptions)
        )

        let partialSyncResult = await postSync.sync()
        XCTAssertFalse(
            partialSyncResult,
            "Background sync should return false when no new posts are retrieved"
        )

        let refreshedSavedSubscriptions = await fetchAllSubscriptions()
        XCTAssertEqual(
            refreshedSavedSubscriptions.count,
            3,
            "Background sync should persist embedded subscriptions even when no posts are returned"
        )

        // Verify the posts request still requested embedded subscriptions only
        let partialCallLog = URLProtocolMock.getCallLog()
        assertPostSyncUsesPostsWithEmbeddedSubscriptions(partialCallLog)
    }

    /// Test sync triggered by manual UI refresh actions
    func testManualRefreshSync() async {
        // Set up initial data
        let initialSubscriptions = createTestSubscriptions(count: 1)
        let initialPosts = createTestPosts(count: 2, subscriptionID: initialSubscriptions.first?.id)

        configureMockForSuccess(subscriptions: initialSubscriptions, posts: initialPosts)

        // Perform initial sync
        _ = await postSync.sync()
        URLProtocolMock.reset()

        // Verify initial data was saved
        let initialSavedPosts = await fetchAllPosts()
        XCTAssertEqual(initialSavedPosts.count, 2, "Initial sync should save posts")

        // Configure mock for manual refresh with new data
        let newSubscriptions = createTestSubscriptions(count: 2)
        let newPosts = createTestPosts(count: 3, subscriptionID: newSubscriptions.first?.id)

        configureMockForSuccess(subscriptions: newSubscriptions, posts: newPosts)

        // Simulate manual refresh by calling sync again
        // In real app, this would be triggered by HubView.refreshHub()
        // which calls SyncCoordinator.syncAsync()
        let refreshResult = await postSync.sync()

        // Verify manual refresh was successful
        XCTAssertTrue(refreshResult, "Manual refresh sync should succeed with new data")

        // Verify new data was retrieved and saved (accumulated with existing posts)
        let allSavedPosts = await fetchAllPosts()
        XCTAssertEqual(
            allSavedPosts.count,
            5,
            "Manual refresh should save new posts in addition to existing posts (2 initial + 3 new)"
        )

        // Verify refresh used the posts endpoint with embedded subscriptions only
        let refreshCallLog = URLProtocolMock.getCallLog()
        assertPostSyncUsesPostsWithEmbeddedSubscriptions(refreshCallLog)

        let isLoadedAfterRefresh = await MainActor.run { testContainer.state == .loaded }
        XCTAssertTrue(
            isLoadedAfterRefresh,
            "Persistence container should finish loading before manual refresh proceeds"
        )

        // Test manual refresh with no new data
        URLProtocolMock.reset()
        configureMockForSuccess(subscriptions: [], posts: [])  // No new data

        let noDataRefreshResult = await postSync.sync()
        XCTAssertFalse(
            noDataRefreshResult,
            "Manual refresh should return false when no new data is available"
        )

        // Verify the posts API was still called even with no new data
        let noDataCallLog = URLProtocolMock.getCallLog()
        assertPostSyncUsesPostsWithEmbeddedSubscriptions(noDataCallLog)

        // Regression: subscriptions-only updates should preserve the false return contract
        URLProtocolMock.reset()
        let embeddedOnlySubscriptions = createTestSubscriptions(count: 4)
        URLProtocolMock.stubPosts(
            [],
            included: PostsSyncResponse.IncludedData(subscriptions: embeddedOnlySubscriptions)
        )

        let embeddedOnlyRefreshResult = await postSync.sync()
        XCTAssertFalse(
            embeddedOnlyRefreshResult,
            "Manual refresh should still return false when only embedded subscriptions change"
        )

        let savedSubscriptions = await fetchAllSubscriptions()
        XCTAssertEqual(
            savedSubscriptions.count,
            4,
            "Manual refresh should persist embedded subscriptions even when no posts are returned"
        )

        let embeddedOnlyCallLog = URLProtocolMock.getCallLog()
        assertPostSyncUsesPostsWithEmbeddedSubscriptions(embeddedOnlyCallLog)
        XCTAssertEqual(
            embeddedOnlyCallLog.filter { $0.url?.path.contains("/posts") == true }.count,
            1,
            "Subscriptions-only refresh should make exactly one posts request"
        )
    }

    /// Test sync behavior when network is unavailable and then recovers
    func testOfflineFailureAndRecovery() async {
        // Test sync failure when network is completely unavailable
        configureMockForFailure(postsError: URLError(.notConnectedToInternet))

        let offlineSyncResult = await postSync.sync()

        // Verify sync fails gracefully when offline
        XCTAssertFalse(offlineSyncResult, "Sync should return false when network is unavailable")

        // Verify the posts request was attempted with embedded subscriptions only
        let offlineCallLog = URLProtocolMock.getCallLog()
        assertPostSyncUsesPostsWithEmbeddedSubscriptions(offlineCallLog)

        let isLoadedWhileOffline = await MainActor.run { testContainer.state == .loaded }
        XCTAssertTrue(
            isLoadedWhileOffline,
            "Persistence container should finish loading before offline sync proceeds"
        )

        // Verify no data was saved due to network failure
        let offlinePosts = await fetchAllPosts()
        let offlineSubscriptions = await fetchAllSubscriptions()
        XCTAssertEqual(offlinePosts.count, 0, "No posts should be saved when network is unavailable")
        XCTAssertEqual(
            offlineSubscriptions.count,
            0,
            "No subscriptions should be saved when network is unavailable"
        )

        // Test partial network availability where posts succeed with embedded subscriptions
        URLProtocolMock.reset()
        let partialSubscriptions = createTestSubscriptions(count: 1)
        let testPosts = createTestPosts(count: 2, subscriptionID: partialSubscriptions.first?.id)
        URLProtocolMock.stubPosts(
            testPosts,
            included: PostsSyncResponse.IncludedData(subscriptions: partialSubscriptions)
        )

        let partialNetworkResult = await postSync.sync()

        // Verify sync succeeds when the posts API is available
        XCTAssertTrue(partialNetworkResult, "Sync should succeed when posts API is available")

        // Verify posts were saved from the single posts request
        let partialPosts = await fetchAllPosts()
        XCTAssertEqual(partialPosts.count, 2, "Posts should be saved when posts API is available")

        // Verify embedded subscriptions were persisted alongside the posts
        let embeddedSubscriptions = await fetchAllSubscriptions()
        XCTAssertEqual(
            embeddedSubscriptions.count,
            1,
            "Embedded subscription should be saved with the posts"
        )
        XCTAssertEqual(
            embeddedSubscriptions.first?.id,
            partialSubscriptions.first?.id,
            "Embedded subscription should have the correct ID"
        )

        let partialNetworkCallLog = URLProtocolMock.getCallLog()
        assertPostSyncUsesPostsWithEmbeddedSubscriptions(partialNetworkCallLog)

        // Test network recovery scenario
        URLProtocolMock.reset()
        let recoverySubscriptions = createTestSubscriptions(count: 3)
        let recoveryPosts = createTestPosts(count: 4, subscriptionID: recoverySubscriptions.first?.id)

        configureMockForSuccess(subscriptions: recoverySubscriptions, posts: recoveryPosts)

        let recoveryResult = await postSync.sync()

        // Verify sync succeeds when network is restored
        XCTAssertTrue(recoveryResult, "Sync should succeed when network is restored")

        // Verify new data is properly synced after network recovery (accumulated with existing posts)
        let recoveryAllPosts = await fetchAllPosts()
        let recoveryAllSubs = await fetchAllSubscriptions()

        // Posts accumulate: 2 from partial network + 4 from recovery = 6 total
        XCTAssertEqual(
            recoveryAllPosts.count,
            6,
            "New posts should be saved after network recovery in addition to existing posts (2 partial + 4 recovery)"
        )
        XCTAssertEqual(
            recoveryAllSubs.count,
            3,
            "New subscriptions should be saved after network recovery from the embedded posts response"
        )
    }
}
