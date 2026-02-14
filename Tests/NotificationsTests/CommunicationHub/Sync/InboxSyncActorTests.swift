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

/// Tests for InboxSync actor concurrency and request coalescing behavior
final class InboxSyncActorTests: InboxSyncTestBase {

  // MARK: - Actor Concurrency Tests

  /// Verify multiple simultaneous sync() calls result in only one actual sync operation
  func testConcurrentSyncRequestsCoalesce() async {
    // Configure mock to simulate slow network response with successful results
    URLProtocolMock.setNetworkLatency(0.2)  // Increased to ensure overlap

    // Create test posts to ensure sync returns true
    let testPosts = createTestPosts(count: 2)
    configureMockForSuccess(subscriptions: [], posts: testPosts)

    // Track how many times the network calls are made
    let initialCallLog = URLProtocolMock.getCallLog()
    let initialSubscriptionCallCount = initialCallLog.filter {
      $0.url?.path.contains("/subscriptions") == true
    }.count
    let initialPostsCallCount = initialCallLog.filter { $0.url?.path.contains("/posts") == true }
      .count

    // Launch multiple concurrent sync requests using withTaskGroup to ensure they start simultaneously
    let results = await withTaskGroup(of: Bool.self) { group in
      group.addTask { await self.inboxSync.sync() }
      group.addTask { await self.inboxSync.sync() }
      group.addTask { await self.inboxSync.sync() }

      var allResults: [Bool] = []
      for await result in group {
        allResults.append(result)
      }
      return allResults
    }

    // All should return the same result (successful sync with new posts)
    XCTAssertTrue(
      results.allSatisfy { $0 == results[0] },
      "All concurrent sync calls should return the same result")
    XCTAssertTrue(results[0], "Sync with new posts should return true")

    // Verify only ONE set of network calls was made despite 3 sync requests
    let finalCallLog = URLProtocolMock.getCallLog()
    let finalSubscriptionCallCount = finalCallLog.filter {
      $0.url?.path.contains("/subscriptions") == true
    }.count
    let finalPostsCallCount = finalCallLog.filter { $0.url?.path.contains("/posts") == true }.count

    XCTAssertEqual(
      finalSubscriptionCallCount - initialSubscriptionCallCount, 1,
      "Only one subscriptions network call should be made despite multiple sync requests")
    XCTAssertEqual(
      finalPostsCallCount - initialPostsCallCount, 1,
      "Only one posts network call should be made despite multiple sync requests")
  }

  /// Verify sync operations can be cancelled and activeSyncTask is cleared
  func testSyncTaskCancellationHandling() async {
    // Configure mock to simulate very slow network response with successful results
    URLProtocolMock.setNetworkLatency(1.0)

    // Create test posts to ensure sync returns true
    let testPosts = createTestPosts(count: 1)
    configureMockForSuccess(subscriptions: [], posts: testPosts)

    // Start a sync operation in a Task so we can cancel it
    let syncTask = Task {
      await inboxSync.sync()
    }

    // Cancel the sync task
    syncTask.cancel()

    // Reset to faster response for the new sync
    URLProtocolMock.setNetworkLatency(0.0)

    // Now start a new sync - it should proceed normally if activeSyncTask was cleared
    let newSyncTask = Task {
      await inboxSync.sync()
    }

    // This should complete relatively quickly (no long delay) if the previous task was properly cancelled
    let startTime = Date()
    let result = await newSyncTask.value
    let elapsed = Date().timeIntervalSince(startTime)

    // The new sync should complete in reasonable time (much less than the 2+ second delay we set)
    XCTAssertLessThan(
      elapsed, 0.5,
      "New sync after cancellation should complete quickly, indicating activeSyncTask was properly cleared"
    )

    // The new sync should succeed
    XCTAssertTrue(result, "New sync after cancellation should succeed")
  }

  /// Verify actor isolation prevents concurrent modification of internal state
  func testActorIsolationPreventsConcurrentModification() async {
    // This test verifies that Swift's actor isolation prevents data races
    // by ensuring that multiple concurrent operations are serialized

    // Configure mock with delays to ensure operations overlap in time with successful results
    URLProtocolMock.setNetworkLatency(0.1)

    // Create test posts to ensure sync returns true
    let testPosts = createTestPosts(count: 1)
    configureMockForSuccess(subscriptions: [], posts: testPosts)

    // Track the initial call counts
    let initialCallLog = URLProtocolMock.getCallLog()
    let initialSubscriptionCallCount = initialCallLog.filter {
      $0.url?.path.contains("/subscriptions") == true
    }.count
    let initialPostsCallCount = initialCallLog.filter { $0.url?.path.contains("/posts") == true }
      .count

    // Create multiple tasks that access the actor
    let tasks = (1...5).map { _ in
      Task {
        // Call sync (which accesses actor's internal state)
        return await inboxSync.sync()
      }
    }

    // Wait for all tasks to complete
    let results = await withTaskGroup(of: Bool.self) { group in
      for task in tasks {
        group.addTask { await task.value }
      }

      var allResults: [Bool] = []
      for await result in group {
        allResults.append(result)
      }
      return allResults
    }

    // All operations should succeed
    XCTAssertTrue(results.allSatisfy { $0 }, "All sync operations should succeed")

    // Due to actor isolation and request coalescing, we should see only ONE actual sync
    let finalCallLog = URLProtocolMock.getCallLog()
    let finalSubscriptionCallCount = finalCallLog.filter {
      $0.url?.path.contains("/subscriptions") == true
    }.count
    let finalPostsCallCount = finalCallLog.filter { $0.url?.path.contains("/posts") == true }.count

    XCTAssertEqual(
      finalSubscriptionCallCount - initialSubscriptionCallCount, 1,
      "Actor isolation should ensure only one sync operation executes")
    XCTAssertEqual(
      finalPostsCallCount - initialPostsCallCount, 1,
      "Actor isolation should ensure only one sync operation executes")
  }

  /// Verify activeSyncTask is cleared after both successful and failed syncs
  func testSyncCompletionClearsActiveSyncTask() async {
    // Test 1: Successful sync should clear activeSyncTask
    let testPosts = createTestPosts(count: 1)
    configureMockForSuccess(subscriptions: [], posts: testPosts)

    let successResult = await inboxSync.sync()
    XCTAssertTrue(successResult, "Sync with posts should return true")

    // Start another sync immediately - if activeSyncTask was cleared, this should start a new sync
    let startTime1 = Date()
    let secondResult = await inboxSync.sync()
    let elapsed1 = Date().timeIntervalSince(startTime1)

    XCTAssertTrue(secondResult, "Second sync with posts should also return true")
    // If activeSyncTask was properly cleared, this should be a new sync operation, not waiting for a previous one

    // Test 2: Failed sync should also clear activeSyncTask
    URLProtocolMock.reset()
    URLProtocolMock.stubSubscriptions([])  // Let subscriptions succeed with empty array
    URLProtocolMock.stubPostsError(URLError(.notConnectedToInternet), statusCode: 0)  // Make posts fail

    let failureResult = await inboxSync.sync()
    XCTAssertFalse(failureResult, "Sync should fail when posts fail")

    // Reset to success for the next test
    URLProtocolMock.reset()  // Clear all previous stubs
    configureMockForSuccess(subscriptions: [], posts: testPosts)

    // Start another sync - if activeSyncTask was cleared after failure, this should work
    let startTime2 = Date()
    let recoveryResult = await inboxSync.sync()
    let elapsed2 = Date().timeIntervalSince(startTime2)

    XCTAssertTrue(recoveryResult, "Recovery sync with posts should return true")

    // Both subsequent syncs should complete in reasonable time, indicating activeSyncTask was cleared
    XCTAssertLessThan(
      elapsed1, 1.0, "Second sync should complete quickly if activeSyncTask was cleared")
    XCTAssertLessThan(
      elapsed2, 1.0, "Recovery sync should complete quickly if activeSyncTask was cleared")
  }
}
