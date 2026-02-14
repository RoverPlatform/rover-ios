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

import Foundation

@testable import RoverNotifications

/// Utility for generating test data for the Hub sync tests
class TestDataGenerator {

  // MARK: - Subscription Generation

  /// Creates test subscription items with predictable data
  /// - Parameter count: Number of subscriptions to create
  /// - Returns: Array of SubscriptionItem objects
  static func createTestSubscriptions(count: Int) -> [SubscriptionItem] {
    return (0..<count).map { index in
      SubscriptionItem(
        id: "subscription-\(index)",
        name: "Test Subscription \(index)",
        description: "Description for Test Subscription \(index)",
        optIn: index % 2 == 0,  // Alternate opt-in/opt-out
        status: index % 3 == 0 ? .published : .unpublished  // Vary status
      )
    }
  }

  // MARK: - Post Generation

  /// Creates test post items with predictable data
  /// - Parameters:
  ///   - count: Number of posts to create
  ///   - subscriptionID: Optional subscription ID to associate posts with
  /// - Returns: Array of PostItem objects
  static func createTestPosts(count: Int, subscriptionID: String? = nil) -> [PostItem] {
    return (0..<count).map { index in
      createTestPost(
        id: UUID(),
        subject: "Test Post \(index)",
        subscriptionID: subscriptionID ?? "subscription-\(index % 3)"  // Distribute across 3 subscriptions
      )
    }
  }

  /// Creates a single test post with custom properties
  /// - Parameters:
  ///   - id: Custom post ID
  ///   - subject: Custom post subject
  ///   - subscriptionID: Subscription ID to associate with
  /// - Returns: PostItem with specified properties
  static func createTestPost(
    id: UUID = UUID(),
    subject: String = "Test Post",
    subscriptionID: String = "test-subscription"
  ) -> PostItem {
    return PostItem(
      id: id,
      subject: subject,
      previewText: "This is the preview text for \(subject)",
      receivedAt: Date().addingTimeInterval(-TimeInterval.random(in: 0...86400)),  // Random time in last day
      url: URL(string: "https://example.com/post/\(id.uuidString)"),
      coverImageURL: URL(string: "https://example.com/images/\(id.uuidString).jpg"),
      subscriptionID: subscriptionID,
      isRead: false
    )
  }

  // MARK: - Pagination Test Data

  /// Creates paginated post responses for testing cursor-based pagination
  /// - Parameters:
  ///   - totalPosts: Total number of posts across all pages
  ///   - pageSize: Number of posts per page
  /// - Returns: Array of PostsSyncResponse objects representing pages
  static func createPaginatedPostResponses(totalPosts: Int, pageSize: Int) -> [PostsSyncResponse] {
    let posts = createTestPosts(count: totalPosts)
    var responses: [PostsSyncResponse] = []

    for pageIndex in 0..<((totalPosts + pageSize - 1) / pageSize) {
      let startIndex = pageIndex * pageSize
      let endIndex = min(startIndex + pageSize, totalPosts)
      let pagePosts = Array(posts[startIndex..<endIndex])

      let hasMore = endIndex < totalPosts
      let nextCursor = hasMore ? "cursor-page-\(pageIndex + 1)" : nil

      responses.append(
        PostsSyncResponse(
          posts: pagePosts,
          nextCursor: nextCursor,
          hasMore: hasMore
        ))
    }

    return responses
  }

  // MARK: - Error Generation

  /// Creates test errors for failure scenarios
  static func createNetworkError() -> Error {
    return NSError(
      domain: "TestNetworkError",
      code: -1001,
      userInfo: [NSLocalizedDescriptionKey: "Test network failure"]
    )
  }

  static func createParsingError() -> Error {
    return NSError(
      domain: "TestParsingError",
      code: -1002,
      userInfo: [NSLocalizedDescriptionKey: "Test JSON parsing failure"]
    )
  }
}
