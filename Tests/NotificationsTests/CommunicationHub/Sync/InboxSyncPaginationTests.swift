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

/// Tests for InboxSync cursor-based pagination logic
final class InboxSyncPaginationTests: InboxSyncTestBase {

  // MARK: - Pagination Tests

  /// Verify sync works correctly for single page responses
  func testSinglePageSync() async {
    // Given: Single page of posts with no pagination
    let testSubscriptions = createTestSubscriptions(count: 1)
    let testPosts = createTestPosts(count: 5, subscriptionID: testSubscriptions[0].id)

    URLProtocolMock.stubSubscriptions(testSubscriptions)
    URLProtocolMock.stubPosts(testPosts, hasMore: false, nextCursor: nil)

    // When: Sync is performed
    let result = await inboxSync.sync()

    // Then: Sync should succeed
    XCTAssertTrue(result, "Single page sync should succeed")

    // Verify only one posts API call was made
    assertNetworkCallCounts(expectedSubscriptionCalls: 1, expectedPostCalls: 1)

    // Verify all posts were saved
    let savedPosts = await fetchAllPosts()
    XCTAssertEqual(savedPosts.count, 5, "Should save all 5 posts from single page")

    // Verify no cursor was saved (since hasMore = false)
    let cursor = await MainActor.run { testContainer.getPostsCursor() }
    XCTAssertNil(cursor, "Should not save cursor when hasMore is false")
  }

  /// Verify all pages are fetched recursively for multi-page responses
  func testMultiPageRecursiveSync() async {
    // Given: Multiple pages of posts (3 pages, 4 posts each)
    let testSubscriptions = createTestSubscriptions(count: 1)
    let paginatedResponses = TestDataGenerator.createPaginatedPostResponses(
      totalPosts: 12, pageSize: 4)

    URLProtocolMock.stubSubscriptions(testSubscriptions)

    // Configure paginated responses using URLProtocolMock.stubPaginationScenario
    URLProtocolMock.stubPaginationScenario { request in
      guard let url = request.url,
        url.path.contains("/posts")
      else { return nil }

      let cursor = url.queryParameters?["cursor"]

      if cursor == nil {
        // First page
        let response = PostsSyncResponse(
          posts: paginatedResponses[0].posts, nextCursor: "cursor-page-1", hasMore: true)
        return .success(object: response)
      } else if cursor == "cursor-page-1" {
        // Second page
        let response = PostsSyncResponse(
          posts: paginatedResponses[1].posts, nextCursor: "cursor-page-2", hasMore: true)
        return .success(object: response)
      } else if cursor == "cursor-page-2" {
        // Third page (final)
        let response = PostsSyncResponse(
          posts: paginatedResponses[2].posts, nextCursor: nil, hasMore: false)
        return .success(object: response)
      }

      return nil
    }

    // When: Sync is performed
    let result = await inboxSync.sync()

    // Then: Sync should succeed
    XCTAssertTrue(result, "Multi-page sync should succeed")

    // Verify correct number of posts API calls (3 pages)
    assertNetworkCallCounts(expectedSubscriptionCalls: 1, expectedPostCalls: 3)

    // Verify all posts from all pages are accumulated and saved
    let savedPosts = await fetchAllPosts()
    XCTAssertEqual(
      savedPosts.count, 12, "Should save all 12 posts from all 3 pages (4 posts × 3 pages)")

    // Verify correct pagination sequence in captured requests
    let callLog = URLProtocolMock.getCallLog()
    let postsCalls = callLog.filter { $0.url?.path.contains("/posts") == true }
    XCTAssertEqual(postsCalls.count, 3, "Should have 3 getPosts calls")

    // Verify pagination sequence
    XCTAssertNil(postsCalls[0].url?.queryParameters?["cursor"], "First call should have no cursor")
    XCTAssertEqual(
      postsCalls[1].url?.queryParameters?["cursor"], "cursor-page-1",
      "Second call should have cursor from page 1")
    XCTAssertEqual(
      postsCalls[2].url?.queryParameters?["cursor"], "cursor-page-2",
      "Third call should have cursor from page 2")

    // Verify final cursor state (should be nil since last page has hasMore = false)
    let cursor = await MainActor.run { testContainer.getPostsCursor() }
    XCTAssertNil(cursor, "Should not save cursor after final page")
  }

  /// Verify graceful handling of network failures during pagination
  func testPaginationWithNetworkFailure() async {
    // Given: First page succeeds, second page fails
    let testSubscriptions = createTestSubscriptions(count: 1)
    let firstPagePosts = createTestPosts(count: 5, subscriptionID: testSubscriptions[0].id)

    URLProtocolMock.stubSubscriptions(testSubscriptions)

    // Configure first page to succeed with hasMore = true
    URLProtocolMock.stubPostsForCursor(
      nil, posts: firstPagePosts, hasMore: true, nextCursor: "cursor-page-1")

    // Configure second page to fail
    URLProtocolMock.stubPaginationScenario { request in
      guard let url = request.url,
        url.path.contains("/posts"),
        let cursor = url.queryParameters?["cursor"],
        cursor == "cursor-page-1"
      else { return Optional<MockResponse>.none }

      return .failure(error: URLError(.networkConnectionLost))
    }

    // When: Sync is performed
    let result = await inboxSync.sync()

    // Then: Sync should fail due to network error on second page
    XCTAssertFalse(result, "Sync should fail when pagination encounters network error")

    // Verify both API calls were attempted
    assertNetworkCallCounts(expectedSubscriptionCalls: 1, expectedPostCalls: 2)

    // Verify pagination sequence was attempted
    let callLog = URLProtocolMock.getCallLog()
    let postsCalls = callLog.filter { $0.url?.path.contains("/posts") == true }
    XCTAssertEqual(postsCalls.count, 2, "Should have attempted 2 getPosts calls")
    XCTAssertNil(postsCalls[0].url?.queryParameters?["cursor"], "First call should have no cursor")
    XCTAssertEqual(
      postsCalls[1].url?.queryParameters?["cursor"], "cursor-page-1",
      "Second call should have cursor from page 1")

    // Verify no posts were saved due to pagination failure
    // The implementation correctly uses transactional behavior - all pages must succeed before any data is persisted
    let savedPosts = await fetchAllPosts()
    XCTAssertEqual(savedPosts.count, 0, "Should not save any posts when pagination fails")
  }

  /// Verify pagination doesn't cause stack overflow with many pages
  func testPaginationStackOverflowPrevention() async {
    // Given: Large number of pages (100 pages, 10 posts each = 1000 total posts)
    // This tests recursive pagination limits and may identify need for iterative refactoring
    let testSubscriptions = createTestSubscriptions(count: 1)
    let paginatedResponses = TestDataGenerator.createPaginatedPostResponses(
      totalPosts: 1000, pageSize: 10)

    URLProtocolMock.stubSubscriptions(testSubscriptions)

    // Configure all 100 pages using URLProtocolMock.stubPaginationScenario
    URLProtocolMock.stubPaginationScenario { request in
      guard let url = request.url,
        url.path.contains("/posts")
      else { return nil }

      let cursor = url.queryParameters?["cursor"]

      if cursor == nil {
        // First page
        let response = PostsSyncResponse(
          posts: paginatedResponses[0].posts, nextCursor: "cursor-page-1", hasMore: true)
        return .success(object: response)
      } else if let cursorValue = cursor, cursorValue.hasPrefix("cursor-page-") {
        // Extract page number from cursor
        let pageNumberString = String(cursorValue.dropFirst("cursor-page-".count))
        if let pageNumber = Int(pageNumberString), pageNumber < paginatedResponses.count {
          let isLastPage = pageNumber == paginatedResponses.count - 1
          let nextCursor = isLastPage ? nil : "cursor-page-\(pageNumber + 1)"
          let response = PostsSyncResponse(
            posts: paginatedResponses[pageNumber].posts, nextCursor: nextCursor,
            hasMore: !isLastPage)
          return .success(object: response)
        }
      }

      return nil
    }

    // When: Sync is performed with large dataset
    let result = await inboxSync.sync()

    // Then: Sync should succeed without stack overflow
    XCTAssertTrue(result, "Large dataset sync should succeed without stack overflow")

    // Verify correct number of API calls (100 pages)
    assertNetworkCallCounts(expectedSubscriptionCalls: 1, expectedPostCalls: 100)

    // Verify all posts from all pages are accumulated and saved
    let savedPosts = await fetchAllPosts()
    XCTAssertEqual(
      savedPosts.count, 1000, "Should save all 1000 posts from all 100 pages (10 posts × 100 pages)"
    )

    // Verify pagination sequence integrity (spot check first, middle, and last calls)
    let callLog = URLProtocolMock.getCallLog()
    let postsCalls = callLog.filter { $0.url?.path.contains("/posts") == true }
    XCTAssertEqual(postsCalls.count, 100, "Should have exactly 100 getPosts calls")
    XCTAssertNil(postsCalls[0].url?.queryParameters?["cursor"], "First call should have no cursor")
    XCTAssertEqual(
      postsCalls[50].url?.queryParameters?["cursor"], "cursor-page-50",
      "Middle call should have correct cursor")
    XCTAssertEqual(
      postsCalls[99].url?.queryParameters?["cursor"], "cursor-page-99",
      "Last call should have correct cursor")

    // Verify final state
    let cursor = await MainActor.run { testContainer.getPostsCursor() }
    XCTAssertNil(cursor, "Should not save cursor after final page")

    // Note: If this test fails with stack overflow, it indicates the need to refactor
    // recursive pagination to use iterative approach instead
  }

  /// Verify correct behavior when API returns empty pages
  func testEmptyPageHandling() async {
    // Given: API returns empty pages in various scenarios
    let testSubscriptions = createTestSubscriptions(count: 1)

    URLProtocolMock.stubSubscriptions(testSubscriptions)

    // Test 1: Completely empty response (no posts, hasMore = false)
    URLProtocolMock.stubPosts([], hasMore: false, nextCursor: nil)

    // When: Sync is performed
    let result = await inboxSync.sync()

    // Then: Sync should succeed but return false (no new posts)
    XCTAssertFalse(result, "Sync should return false when no posts are retrieved")

    // Verify API calls were made
    assertNetworkCallCounts(expectedSubscriptionCalls: 1, expectedPostCalls: 1)

    // Verify no posts were saved
    let savedPosts = await fetchAllPosts()
    XCTAssertEqual(savedPosts.count, 0, "Should save no posts when response is empty")

    // Reset for second test
    URLProtocolMock.reset()
    await clearAllData()

    // Test 2: Empty first page with more pages available
    URLProtocolMock.stubSubscriptions(testSubscriptions)

    // Configure empty first page with hasMore = true
    URLProtocolMock.stubPostsForCursor(nil, posts: [], hasMore: true, nextCursor: "cursor-page-1")

    // Configure second page with actual posts
    let secondPagePosts = createTestPosts(count: 3, subscriptionID: testSubscriptions[0].id)
    URLProtocolMock.stubPostsForCursor(
      "cursor-page-1", posts: secondPagePosts, hasMore: false, nextCursor: nil)

    // When: Sync is performed
    let result2 = await inboxSync.sync()

    // Then: Should continue to next page and succeed
    XCTAssertTrue(result2, "Sync should succeed when later pages have posts")

    // Verify both pages were called
    assertNetworkCallCounts(expectedSubscriptionCalls: 1, expectedPostCalls: 2)

    // Verify posts from second page were saved
    let savedPosts2 = await fetchAllPosts()
    XCTAssertEqual(savedPosts2.count, 3, "Should save posts from non-empty page")
  }
}
