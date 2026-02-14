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

/// Tests for InboxSync two-phase sync sequence (subscriptions then posts)
final class InboxSyncPhaseTests: InboxSyncTestBase {

  // MARK: - Two-Phase Sync Tests

  /// Verify subscriptions are synced before posts in the correct order
  func testSubscriptionsSyncBeforePosts() async {
    // Given: Mock responses for both phases
    let testSubscriptions = createTestSubscriptions(count: 2)
    let testPosts = createTestPosts(count: 3, subscriptionID: testSubscriptions[0].id)

    configureMockForSuccess(subscriptions: testSubscriptions, posts: testPosts)

    // When: Sync is performed
    let result = await inboxSync.sync()

    // Then: Both API calls were made in correct order
    XCTAssertTrue(result, "Sync should succeed")

    // Verify execution order by checking captured requests
    let callLog = URLProtocolMock.getCallLog()
    XCTAssertEqual(callLog.count, 2, "Should have exactly 2 API calls")
    XCTAssertTrue(
      callLog[0].url?.path.contains("/subscriptions") == true,
      "First call should be getSubscriptions")
    XCTAssertTrue(callLog[1].url?.path.contains("/posts") == true, "Second call should be getPosts")

    // Verify data was persisted correctly
    let savedSubscriptions = await fetchAllSubscriptions()
    let savedPosts = await fetchAllPosts()

    XCTAssertEqual(savedSubscriptions.count, 2, "Should save 2 subscriptions")
    XCTAssertEqual(savedPosts.count, 3, "Should save 3 posts")
  }

  /// Verify posts sync continues even if subscriptions sync fails
  func testPostsSyncContinuesAfterSubscriptionFailure() async {
    // Given: Subscriptions API fails, but posts API succeeds
    let testPosts = createTestPosts(count: 2, subscriptionID: "sub1")

    configureMockForFailure(subscriptionsError: URLError(.networkConnectionLost))
    URLProtocolMock.stubPosts(testPosts)

    // When: Sync is performed
    let result = await inboxSync.sync()

    // Then: Sync should still succeed because posts phase completed
    XCTAssertTrue(result, "Sync should succeed even if subscriptions fail")

    // Verify both API calls were attempted and execution order
    let callLog = URLProtocolMock.getCallLog()
    XCTAssertEqual(callLog.count, 2, "Should have exactly 2 API calls")
    XCTAssertTrue(
      callLog[0].url?.path.contains("/subscriptions") == true,
      "First call should be getSubscriptions")
    XCTAssertTrue(callLog[1].url?.path.contains("/posts") == true, "Second call should be getPosts")

    // Verify posts were saved and placeholder subscriptions were created
    let savedSubscriptions = await fetchAllSubscriptions()
    let savedPosts = await fetchAllPosts()

    XCTAssertEqual(
      savedSubscriptions.count, 1,
      "Should create placeholder subscription for posts when subscriptions API fails")
    XCTAssertEqual(savedPosts.count, 2, "Should save posts even when subscriptions fail")

    // Verify the placeholder subscription was created correctly
    let placeholderSubscription = savedSubscriptions.first
    XCTAssertNotNil(placeholderSubscription, "Placeholder subscription should exist")
    XCTAssertEqual(placeholderSubscription?.id, "sub1", "Placeholder should have the correct ID")
    XCTAssertEqual(
      placeholderSubscription?.status, "published", "Placeholder should have default status")
  }

  /// Verify graceful handling when both subscription and posts APIs fail
  func testBothPhasesFailureHandling() async {
    // Given: Both APIs fail
    configureMockForFailure(
      subscriptionsError: URLError(.networkConnectionLost),
      postsError: URLError(.badServerResponse)
    )

    // When: Sync is performed
    let result = await inboxSync.sync()

    // Then: Sync should fail when both phases fail
    XCTAssertFalse(result, "Sync should fail when both phases fail")

    // Verify both API calls were attempted and execution order was maintained
    let callLog = URLProtocolMock.getCallLog()
    XCTAssertEqual(callLog.count, 2, "Should have exactly 2 API calls")
    XCTAssertTrue(
      callLog[0].url?.path.contains("/subscriptions") == true,
      "First call should be getSubscriptions")
    XCTAssertTrue(callLog[1].url?.path.contains("/posts") == true, "Second call should be getPosts")

    // Verify no data was saved due to failures
    let savedSubscriptions = await fetchAllSubscriptions()
    let savedPosts = await fetchAllPosts()

    XCTAssertEqual(savedSubscriptions.count, 0, "Should not save subscriptions when API fails")
    XCTAssertEqual(savedPosts.count, 0, "Should not save posts when API fails")
  }

  /// Verify subscription data from phase 1 is accessible during posts processing
  func testSubscriptionDataAvailableForPostsPhase() async {
    // Given: Subscriptions with specific IDs and posts that reference them
    let testSubscriptions = createTestSubscriptions(count: 3)
    let subscription1ID = testSubscriptions[0].id
    let subscription2ID = testSubscriptions[1].id

    // Create posts that reference the subscriptions
    let postsForSub1 = createTestPosts(count: 2, subscriptionID: subscription1ID)
    let postsForSub2 = createTestPosts(count: 2, subscriptionID: subscription2ID)
    let allTestPosts = postsForSub1 + postsForSub2

    configureMockForSuccess(subscriptions: testSubscriptions, posts: allTestPosts)

    // When: Sync is performed
    let result = await inboxSync.sync()

    // Then: Sync should succeed and data should be properly linked
    XCTAssertTrue(result, "Sync should succeed")

    // Verify all data was saved
    let savedSubscriptions = await fetchAllSubscriptions()
    let savedPosts = await fetchAllPosts()

    XCTAssertEqual(savedSubscriptions.count, 3, "Should save all 3 subscriptions")
    XCTAssertEqual(savedPosts.count, 4, "Should save all 4 posts")

    // Verify posts can find their subscription relationships
    // This tests that subscription data from phase 1 is available during posts processing
    let postsWithSubscription1 = savedPosts.filter { $0.subscription?.id == subscription1ID }
    let postsWithSubscription2 = savedPosts.filter { $0.subscription?.id == subscription2ID }

    XCTAssertEqual(postsWithSubscription1.count, 2, "Should have 2 posts linked to subscription 1")
    XCTAssertEqual(postsWithSubscription2.count, 2, "Should have 2 posts linked to subscription 2")

    // Verify subscription entities exist and can be accessed
    let subscription1 = savedSubscriptions.first { $0.id == subscription1ID }
    let subscription2 = savedSubscriptions.first { $0.id == subscription2ID }

    XCTAssertNotNil(subscription1, "Subscription 1 should exist in Core Data")
    XCTAssertNotNil(subscription2, "Subscription 2 should exist in Core Data")
  }
}
