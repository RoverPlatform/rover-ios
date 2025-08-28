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

/// Tests for RCHSync triggers and SDK integration
final class RCHSyncTriggerTests: RCHSyncTestBase {

  // MARK: - Sync Trigger Tests

  /// Test sync initiation during app launch lifecycle
  func testAppLaunchSync() async {
    await clearAllData()

    // Configure mock for successful sync
    configureMockForSuccess(subscriptions: [], posts: [])

    // Simulate app launch by directly calling sync on RCHSync
    // In real app, this would be triggered by SyncCoordinator during app launch
    let syncResult = await rchSync.sync()

    // Verify sync completed (returns false when no new posts available)
    XCTAssertFalse(
      syncResult, "App launch sync should return false when no new posts are available")

    // Verify sync was called on both endpoints
    let callLog = URLProtocolMock.getCallLog()
    let subscriptionsRequests = callLog.filter { $0.url?.path.contains("/subscriptions") == true }
    let postsRequests = callLog.filter { $0.url?.path.contains("/posts") == true }

    XCTAssertTrue(subscriptionsRequests.count > 0, "App launch should trigger subscriptions sync")
    XCTAssertTrue(postsRequests.count > 0, "App launch should trigger posts sync")

    // Verify sync was called in correct order (subscriptions first)
    let subscriptionsIndex = callLog.firstIndex { $0.url?.path.contains("/subscriptions") == true }
    let postsIndex = callLog.firstIndex { $0.url?.path.contains("/posts") == true }

    XCTAssertNotNil(subscriptionsIndex, "Subscriptions should be called")
    XCTAssertNotNil(postsIndex, "Posts should be called")
    if let subIndex = subscriptionsIndex, let postIndex = postsIndex {
      XCTAssertLessThan(subIndex, postIndex, "Subscriptions should be called before posts")
    }

    // Test that persistence container is properly loaded before sync
    // This is handled internally by RCHSync.performActualSync()
    let isLoaded = await MainActor.run { testContainer.state == .loaded }
    XCTAssertTrue(isLoaded, "Persistence container should be loaded during app launch sync")
  }

  /// Test sync triggered by silent push notifications
  func testBackgroundPushSync() async {
    await clearAllData()

    // Configure mock for successful background sync
    let testSubscriptions = createTestSubscriptions(count: 2)
    let testPosts = createTestPosts(count: 3, subscriptionID: testSubscriptions.first?.id)

    configureMockForSuccess(subscriptions: testSubscriptions, posts: testPosts)

    // Simulate background push notification triggering sync
    // In real app, this would be triggered by SyncCoordinator.sync(completionHandler:)
    // when a silent push notification is received
    let syncResult = await rchSync.sync()

    // Verify background sync was successful
    XCTAssertTrue(syncResult, "Background push sync should succeed")

    // Verify data was synced from the "background" API call
    let savedSubscriptions = await fetchAllSubscriptions()
    let savedPosts = await fetchAllPosts()

    XCTAssertEqual(savedSubscriptions.count, 2, "Background sync should save subscriptions")
    XCTAssertEqual(savedPosts.count, 3, "Background sync should save posts")

    // Verify background sync respects the two-phase sequence
    let backgroundCallLog = URLProtocolMock.getCallLog()
    let backgroundSubsRequests = backgroundCallLog.filter {
      $0.url?.path.contains("/subscriptions") == true
    }
    let backgroundPostsRequests = backgroundCallLog.filter {
      $0.url?.path.contains("/posts") == true
    }

    XCTAssertTrue(backgroundSubsRequests.count > 0, "Background sync should call subscriptions API")
    XCTAssertTrue(backgroundPostsRequests.count > 0, "Background sync should call posts API")

    // Test that background sync can handle partial failures gracefully
    URLProtocolMock.reset()
    configureMockForFailure(subscriptionsError: URLError(.networkConnectionLost))
    URLProtocolMock.stubPosts([])  // Posts should still work

    let partialSyncResult = await rchSync.sync()
    XCTAssertFalse(
      partialSyncResult, "Background sync should return false when no new posts are retrieved")

    // Verify posts sync continued despite subscriptions failure
    let partialCallLog = URLProtocolMock.getCallLog()
    let partialSubsRequests = partialCallLog.filter {
      $0.url?.path.contains("/subscriptions") == true
    }
    let partialPostsRequests = partialCallLog.filter { $0.url?.path.contains("/posts") == true }

    XCTAssertTrue(partialSubsRequests.count > 0, "Background sync should attempt subscriptions")
    XCTAssertTrue(
      partialPostsRequests.count > 0,
      "Background sync should continue with posts despite subscriptions failure")
  }

  /// Test sync triggered by manual UI refresh actions
  func testManualRefreshSync() async {
    await clearAllData()

    // Set up initial data
    let initialSubscriptions = createTestSubscriptions(count: 1)
    let initialPosts = createTestPosts(count: 2, subscriptionID: initialSubscriptions.first?.id)

    configureMockForSuccess(subscriptions: initialSubscriptions, posts: initialPosts)

    // Perform initial sync
    _ = await rchSync.sync()
    URLProtocolMock.reset()

    // Verify initial data was saved
    let initialSavedPosts = await fetchAllPosts()
    XCTAssertEqual(initialSavedPosts.count, 2, "Initial sync should save posts")

    // Configure mock for manual refresh with new data
    let newSubscriptions = createTestSubscriptions(count: 2)
    let newPosts = createTestPosts(count: 3, subscriptionID: newSubscriptions.first?.id)

    configureMockForSuccess(subscriptions: newSubscriptions, posts: newPosts)

    // Simulate manual refresh by calling sync again
    // In real app, this would be triggered by CommunicationHubView.refreshPosts()
    // which calls SyncCoordinator.syncAsync()
    let refreshResult = await rchSync.sync()

    // Verify manual refresh was successful
    XCTAssertTrue(refreshResult, "Manual refresh sync should succeed with new data")

    // Verify new data was retrieved and saved (accumulated with existing posts)
    let allSavedPosts = await fetchAllPosts()
    XCTAssertEqual(
      allSavedPosts.count, 5,
      "Manual refresh should save new posts in addition to existing posts (2 initial + 3 new)")

    // Verify refresh triggered both API calls
    let refreshCallLog = URLProtocolMock.getCallLog()
    let refreshSubsRequests = refreshCallLog.filter {
      $0.url?.path.contains("/subscriptions") == true
    }
    let refreshPostsRequests = refreshCallLog.filter { $0.url?.path.contains("/posts") == true }

    XCTAssertTrue(refreshSubsRequests.count > 0, "Manual refresh should call subscriptions API")
    XCTAssertTrue(refreshPostsRequests.count > 0, "Manual refresh should call posts API")

    // Test manual refresh with no new data
    URLProtocolMock.reset()
    configureMockForSuccess(subscriptions: [], posts: [])  // No new data

    let noDataRefreshResult = await rchSync.sync()
    XCTAssertFalse(
      noDataRefreshResult, "Manual refresh should return false when no new data is available")

    // Verify APIs were still called even with no new data
    let noDataCallLog = URLProtocolMock.getCallLog()
    let noDataSubsRequests = noDataCallLog.filter {
      $0.url?.path.contains("/subscriptions") == true
    }
    let noDataPostsRequests = noDataCallLog.filter { $0.url?.path.contains("/posts") == true }

    XCTAssertTrue(noDataSubsRequests.count > 0, "Manual refresh should always check subscriptions")
    XCTAssertTrue(noDataPostsRequests.count > 0, "Manual refresh should always check posts")
  }

  /// Test sync behavior when network is unavailable (offline queueing)
  func testOfflineQueueing() async {
    await clearAllData()

    // Test sync failure when network is completely unavailable
    configureMockForFailure(
      subscriptionsError: URLError(.notConnectedToInternet),
      postsError: URLError(.notConnectedToInternet)
    )

    let offlineSyncResult = await rchSync.sync()

    // Verify sync fails gracefully when offline
    XCTAssertFalse(offlineSyncResult, "Sync should return false when network is unavailable")

    // Verify both API calls were attempted
    let offlineCallLog = URLProtocolMock.getCallLog()
    let offlineSubsRequests = offlineCallLog.filter {
      $0.url?.path.contains("/subscriptions") == true
    }
    let offlinePostsRequests = offlineCallLog.filter { $0.url?.path.contains("/posts") == true }

    XCTAssertTrue(
      offlineSubsRequests.count > 0, "Should attempt subscriptions sync even when offline")
    XCTAssertTrue(offlinePostsRequests.count > 0, "Should attempt posts sync even when offline")

    // Verify no data was saved due to network failure
    let offlinePosts = await fetchAllPosts()
    let offlineSubscriptions = await fetchAllSubscriptions()
    XCTAssertEqual(offlinePosts.count, 0, "No posts should be saved when network is unavailable")
    XCTAssertEqual(
      offlineSubscriptions.count, 0, "No subscriptions should be saved when network is unavailable")

    // Test partial network availability (subscriptions fail, posts succeed)
    URLProtocolMock.reset()
    let testPosts = createTestPosts(count: 2, subscriptionID: "placeholder-sub")
    configureMockForFailure(subscriptionsError: URLError(.timedOut))
    URLProtocolMock.stubPosts(testPosts)

    let partialNetworkResult = await rchSync.sync()

    // Verify sync succeeds when posts API is available (even if subscriptions fail)
    XCTAssertTrue(partialNetworkResult, "Sync should succeed when posts API is available")

    // Verify posts were saved despite subscriptions failure
    let partialPosts = await fetchAllPosts()
    XCTAssertEqual(partialPosts.count, 2, "Posts should be saved when posts API is available")

    // Verify placeholder subscription was created for orphaned posts
    let placeholderSubs = await fetchAllSubscriptions()
    XCTAssertEqual(
      placeholderSubs.count, 1, "Placeholder subscription should be created for orphaned posts")
    XCTAssertEqual(
      placeholderSubs.first?.id, "placeholder-sub",
      "Placeholder subscription should have correct ID")

    // Test network recovery scenario
    URLProtocolMock.reset()
    let recoverySubscriptions = createTestSubscriptions(count: 3)
    let recoveryPosts = createTestPosts(count: 4, subscriptionID: recoverySubscriptions.first?.id)

    configureMockForSuccess(subscriptions: recoverySubscriptions, posts: recoveryPosts)

    let recoveryResult = await rchSync.sync()

    // Verify sync succeeds when network is restored
    XCTAssertTrue(recoveryResult, "Sync should succeed when network is restored")

    // Verify new data is properly synced after network recovery (accumulated with existing posts)
    let recoveryAllPosts = await fetchAllPosts()
    let recoveryAllSubs = await fetchAllSubscriptions()

    // Posts accumulate: 2 from partial network + 4 from recovery = 6 total
    XCTAssertEqual(
      recoveryAllPosts.count, 6,
      "New posts should be saved after network recovery in addition to existing posts (2 partial + 4 recovery)"
    )
    XCTAssertEqual(
      recoveryAllSubs.count, 4,
      "New subscriptions should be saved after network recovery (3 new + 1 existing placeholder)")
  }
}
