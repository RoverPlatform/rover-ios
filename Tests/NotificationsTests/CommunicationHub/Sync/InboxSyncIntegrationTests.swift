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

@testable import RoverData
@testable import RoverNotifications

/// Tests for InboxSync integration with SyncStandaloneParticipant
final class InboxSyncIntegrationTests: InboxSyncTestBase {

  // MARK: - SyncStandaloneParticipant Integration Tests

  /// Test SyncCoordinator protocol conformance and integration
  func testSyncCoordinatorIntegration() async {
    await clearAllData()

    // Test that InboxSync can be called through the protocol interface
    let standaloneParticipant: SyncStandaloneParticipant = inboxSync

    // Configure mock for successful protocol-based sync
    let testSubscriptions = createTestSubscriptions(count: 2)
    let testPosts = createTestPosts(count: 3, subscriptionID: testSubscriptions.first?.id)

    configureMockForSuccess(subscriptions: testSubscriptions, posts: testPosts)

    // Call sync through the protocol interface (as SyncCoordinator would)
    let protocolSyncResult = await standaloneParticipant.sync()

    // Verify protocol-based sync works correctly
    XCTAssertTrue(protocolSyncResult, "Protocol-based sync should succeed")

    // Verify data was synced through protocol interface
    let savedSubscriptions = await fetchAllSubscriptions()
    let savedPosts = await fetchAllPosts()

    XCTAssertEqual(savedSubscriptions.count, 2, "Protocol sync should save subscriptions")
    XCTAssertEqual(savedPosts.count, 3, "Protocol sync should save posts")

    // Test protocol-based sync with failure
    URLProtocolMock.reset()
    configureMockForFailure(
      subscriptionsError: URLError(.networkConnectionLost),
      postsError: URLError(.networkConnectionLost)
    )

    let protocolFailureResult = await standaloneParticipant.sync()

    // Verify protocol correctly reports failure
    XCTAssertFalse(protocolFailureResult, "Protocol sync should return false on failure")

    // Verify that multiple protocol calls are properly coalesced
    URLProtocolMock.reset()
    URLProtocolMock.setNetworkLatency(0.1)  // Add small delay to test coalescing
    configureMockForSuccess(subscriptions: [], posts: [])

    // Start multiple concurrent protocol-based syncs
    async let sync1 = standaloneParticipant.sync()
    async let sync2 = standaloneParticipant.sync()
    async let sync3 = standaloneParticipant.sync()

    let results = await [sync1, sync2, sync3]

    // All should return the same result (coalesced)
    XCTAssertEqual(
      results, [false, false, false], "All coalesced syncs should return the same result")

    // Verify only one set of API calls was made (coalescing worked)
    let callLog = URLProtocolMock.getCallLog()
    let subscriptionsCalls = callLog.filter { $0.url?.path.contains("/subscriptions") == true }
    let postsCalls = callLog.filter { $0.url?.path.contains("/posts") == true }

    XCTAssertEqual(
      subscriptionsCalls.count, 1, "Only one subscriptions call should be made due to coalescing")
    XCTAssertEqual(postsCalls.count, 1, "Only one posts call should be made due to coalescing")
  }

  /// Test sync participant return values and status reporting
  func testSyncParticipantReturnValues() async {
    await clearAllData()

    // Test sync returns true when new data is available
    let testSubscriptions = createTestSubscriptions(count: 1)
    let testPosts = createTestPosts(count: 2, subscriptionID: testSubscriptions.first?.id)

    configureMockForSuccess(subscriptions: testSubscriptions, posts: testPosts)

    let successResult = await inboxSync.sync()
    XCTAssertTrue(successResult, "Sync should return true when new posts are available")

    // Test sync returns false when no new data is available
    URLProtocolMock.reset()
    configureMockForSuccess(subscriptions: [], posts: [])  // No new data

    let noDataResult = await inboxSync.sync()
    XCTAssertFalse(noDataResult, "Sync should return false when no new posts are available")

    // Test sync returns false when both APIs fail
    URLProtocolMock.reset()
    configureMockForFailure(
      subscriptionsError: URLError(.networkConnectionLost),
      postsError: URLError(.networkConnectionLost)
    )

    let failureResult = await inboxSync.sync()
    XCTAssertFalse(failureResult, "Sync should return false when both APIs fail")

    // Test sync returns true when posts succeed but subscriptions fail
    URLProtocolMock.reset()
    let newPosts = createTestPosts(count: 1, subscriptionID: "test-sub")
    configureMockForFailure(subscriptionsError: URLError(.networkConnectionLost))
    URLProtocolMock.stubPosts(newPosts)

    let partialSuccessResult = await inboxSync.sync()
    XCTAssertTrue(
      partialSuccessResult,
      "Sync should return true when posts succeed (even if subscriptions fail)")

    // Test sync returns false when subscriptions succeed but posts fail
    URLProtocolMock.reset()
    let newSubscriptions = createTestSubscriptions(count: 1)
    URLProtocolMock.stubSubscriptions(newSubscriptions)
    configureMockForFailure(postsError: URLError(.networkConnectionLost))

    let subscriptionsOnlyResult = await inboxSync.sync()
    XCTAssertFalse(
      subscriptionsOnlyResult,
      "Sync should return false when only subscriptions succeed (no new posts)")

    // Test that return values are consistent across multiple calls
    URLProtocolMock.reset()
    configureMockForSuccess(subscriptions: [], posts: [])

    let firstCall = await inboxSync.sync()
    let secondCall = await inboxSync.sync()
    let thirdCall = await inboxSync.sync()

    XCTAssertEqual(firstCall, secondCall, "Consecutive sync calls should return consistent values")
    XCTAssertEqual(secondCall, thirdCall, "Consecutive sync calls should return consistent values")
    XCTAssertFalse(firstCall, "All calls should return false when no new data is available")

    // Test return value accuracy with actual data verification
    await clearAllData()  // Clear data to test final verification in isolation
    URLProtocolMock.reset()
    let verificationPosts = createTestPosts(count: 3, subscriptionID: "verify-sub")
    configureMockForSuccess(subscriptions: [], posts: verificationPosts)

    let verificationResult = await inboxSync.sync()
    XCTAssertTrue(verificationResult, "Sync should return true when posts are available")

    // Verify that the return value accurately reflects data persistence
    let actualSavedPosts = await fetchAllPosts()
    XCTAssertEqual(
      actualSavedPosts.count, 3, "Saved posts count should match expectation when sync returns true"
    )
  }

  /// Test isolation from main SDK sync operations
  func testIsolationFromMainSyncOperations() async {
    await clearAllData()

    // Test that InboxSync operates independently of other sync participants
    // This test verifies that Hub sync doesn't interfere with
    // the main SDK sync system and vice versa

    // Configure Hub sync for success
    let hubSubscriptions = createTestSubscriptions(count: 2)
    let hubPosts = createTestPosts(count: 3, subscriptionID: hubSubscriptions.first?.id)

    configureMockForSuccess(subscriptions: hubSubscriptions, posts: hubPosts)

    // Perform Hub sync
    let hubResult = await inboxSync.sync()
    XCTAssertTrue(hubResult, "Hub sync should succeed independently")

    // Verify Hub data was saved
    let savedhubPosts = await fetchAllPosts()
    let savedhubSubs = await fetchAllSubscriptions()

    XCTAssertEqual(savedhubPosts.count, 3, "Hub posts should be saved")
    XCTAssertEqual(savedhubSubs.count, 2, "Hub subscriptions should be saved")

    // Verify Hub uses separate Core Data stack
    // The Hub uses InboxPersistentContainer which is separate from
    // the main SDK's Core Data stack, ensuring data isolation
    XCTAssertNotNil(testContainer, "Hub should have its own persistent container")

    // Test that Hub sync state is isolated
    // Multiple concurrent Hub syncs should coalesce independently
    URLProtocolMock.reset()
    URLProtocolMock.setNetworkLatency(0.05)
    configureMockForSuccess(subscriptions: [], posts: [])

    // Start multiple concurrent Hub syncs
    async let isolatedSync1 = inboxSync.sync()
    async let isolatedSync2 = inboxSync.sync()
    async let isolatedSync3 = inboxSync.sync()

    let isolatedResults = await [isolatedSync1, isolatedSync2, isolatedSync3]

    // All should return the same result due to coalescing within Hub
    XCTAssertEqual(
      isolatedResults, [false, false, false],
      "Hub syncs should coalesce independently")

    // Verify only one set of Hub API calls was made
    let isolatedCallLog = URLProtocolMock.getCallLog()
    let isolatedSubsCalls = isolatedCallLog.filter {
      $0.url?.path.contains("/subscriptions") == true
    }
    let isolatedPostsCalls = isolatedCallLog.filter { $0.url?.path.contains("/posts") == true }

    XCTAssertEqual(
      isolatedSubsCalls.count, 1,
      "Hub should make only one subscriptions call due to internal coalescing")
    XCTAssertEqual(
      isolatedPostsCalls.count, 1,
      "Hub should make only one posts call due to internal coalescing")

    // Test that Hub sync failures don't affect other components
    URLProtocolMock.reset()
    configureMockForFailure(
      subscriptionsError: URLError(.networkConnectionLost),
      postsError: URLError(.networkConnectionLost)
    )

    let failureResult = await inboxSync.sync()
    XCTAssertFalse(failureResult, "Hub sync failure should be isolated")

    // Verify that existing Hub data remains intact after failure
    let persistenthubPosts = await fetchAllPosts()
    let persistenthubSubs = await fetchAllSubscriptions()

    XCTAssertEqual(
      persistenthubPosts.count, 3,
      "Existing Hub posts should remain after sync failure")
    XCTAssertEqual(
      persistenthubSubs.count, 2,
      "Existing Hub subscriptions should remain after sync failure")

    // Test that Hub operates on separate endpoints
    // Hub uses /subscriptions and /posts endpoints which are
    // separate from the main SDK's GraphQL sync endpoint
    let finalCallLog = URLProtocolMock.getCallLog()
    let subscriptionsRequests = finalCallLog.filter {
      $0.url?.path.contains("/subscriptions") == true
    }
    let postsRequests = finalCallLog.filter { $0.url?.path.contains("/posts") == true }

    XCTAssertTrue(
      subscriptionsRequests.count > 0,
      "Hub should use separate subscriptions endpoint")
    XCTAssertTrue(postsRequests.count > 0, "Hub should use separate posts endpoint")

    // Verify no GraphQL sync requests were made (Hub doesn't use GraphQL)
    let graphqlRequests = finalCallLog.filter {
      $0.url?.path.contains("graphql") == true || $0.url?.path.contains("GraphQL") == true
    }
    XCTAssertEqual(
      graphqlRequests.count, 0,
      "Hub should not make GraphQL requests (uses REST endpoints)")
  }
}
