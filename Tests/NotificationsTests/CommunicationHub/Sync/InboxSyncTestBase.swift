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

/// Base class for all Hub sync tests
/// Provides common setup, teardown, and helper methods
class InboxSyncTestBase: XCTestCase {

  // MARK: - Test Infrastructure

  var testContainer: InboxPersistentContainer!
  var httpClient: HTTPClient!
  var inboxSync: InboxSync!

  // MARK: - Call Tracking
  private var capturedRequests: [String] {
    return URLProtocolMock.getCallLog().map { request in
      if let url = request.url {
        if url.path.contains("/subscriptions") {
          return "getSubscriptions"
        } else if url.path.contains("/posts") {
          let cursor = url.queryParameters?["cursor"]
          return "getPosts(cursor: \(cursor ?? "nil"))"
        }
      }
      return "unknown request"
    }
  }

  private var getSubscriptionsCallCount: Int {
    return capturedRequests.filter { $0 == "getSubscriptions" }.count
  }

  private var getPostsCallCount: Int {
    return capturedRequests.filter { $0.hasPrefix("getPosts") }.count
  }

  // MARK: - Setup & Teardown

  override func setUp() async throws {
    try await super.setUp()

    // Reset and register URLProtocolMock
    URLProtocolMock.reset()
    URLProtocol.registerClass(URLProtocolMock.self)

    // Create test container
    testContainer = InboxPersistentContainer(storage: .inMemory)

    // Create HTTPClient with mocked URLSession
    let session = MockURLSession.createConfiguredSession()
    let authContext = AuthenticationContext(userDefaults: UserDefaults())
    httpClient = HTTPClient(
      accountToken: "test-token",
      endpoint: URL(string: "https://api.test.com")!,
      engageEndpoint: URL(string: "https://engage.test.com")!,
      session: session,
      authContext: authContext
    )

    // Create InboxSync with test dependencies
    inboxSync = await MainActor.run {
      InboxSync(
        persistentContainer: testContainer,
        httpClient: httpClient
      )
    }
  }

  override func tearDown() async throws {
    // Unregister and reset URLProtocolMock
    URLProtocol.unregisterClass(URLProtocolMock.self)
    URLProtocolMock.reset()

    // Clean up references
    inboxSync = nil
    testContainer = nil
    httpClient = nil

    try await super.tearDown()
  }

  // MARK: - Helper Methods

  /// Configures URLProtocolMock for successful sync operations
  /// - Parameters:
  ///   - subscriptions: Subscriptions to return from getSubscriptions()
  ///   - posts: Posts to return from getPosts()
  func configureMockForSuccess(
    subscriptions: [SubscriptionItem],
    posts: [PostItem]
  ) {
    URLProtocolMock.stubSubscriptions(subscriptions)
    URLProtocolMock.stubPosts(posts)
  }

  /// Configures URLProtocolMock for failure scenarios
  /// - Parameters:
  ///   - subscriptionsError: Error to return from getSubscriptions()
  ///   - postsError: Error to return from getPosts()
  func configureMockForFailure(
    subscriptionsError: Error? = nil,
    postsError: Error? = nil
  ) {
    if let subscriptionsError = subscriptionsError {
      URLProtocolMock.stubSubscriptionsError(subscriptionsError, statusCode: 0)  // Use network error instead of HTTP error
    }
    if let postsError = postsError {
      URLProtocolMock.stubPostsError(postsError, statusCode: 0)  // Use network error instead of HTTP error
    }
  }

  /// Fetches all subscriptions from Core Data
  /// - Returns: Array of Subscription entities
  func fetchAllSubscriptions() async -> [Subscription] {
    return await MainActor.run {
      let context = testContainer.viewContext
      let request: NSFetchRequest<Subscription> = Subscription.fetchRequest()
      return (try? context.fetch(request)) ?? []
    }
  }

  /// Fetches all posts from Core Data
  /// - Returns: Array of Post entities
  func fetchAllPosts() async -> [Post] {
    return await MainActor.run {
      let context = testContainer.viewContext
      let request: NSFetchRequest<Post> = Post.fetchRequest()
      return (try? context.fetch(request)) ?? []
    }
  }

  /// Counts entities of a specific type in Core Data
  /// - Parameter entityType: The entity type to count
  /// - Returns: Number of entities
  func countEntities<T: NSManagedObject>(_ entityType: T.Type) async -> Int {
    return await MainActor.run {
      let context = testContainer.viewContext
      let request = NSFetchRequest<T>(entityName: String(describing: entityType))
      return (try? context.count(for: request)) ?? 0
    }
  }

  /// Clears all data from Core Data for test isolation
  /// Uses individual object deletion to avoid memory management issues with batch operations
  func clearAllData() async {
    await MainActor.run {
      let context = testContainer.viewContext

      // Fetch and delete all posts individually
      let postRequest: NSFetchRequest<Post> = Post.fetchRequest()
      if let posts = try? context.fetch(postRequest) {
        for post in posts {
          context.delete(post)
        }
      }

      // Fetch and delete all subscriptions individually
      let subscriptionRequest: NSFetchRequest<Subscription> = Subscription.fetchRequest()
      if let subscriptions = try? context.fetch(subscriptionRequest) {
        for subscription in subscriptions {
          context.delete(subscription)
        }
      }

      // Fetch and delete all cursors individually
      let cursorRequest: NSFetchRequest<Cursor> = Cursor.fetchRequest()
      if let cursors = try? context.fetch(cursorRequest) {
        for cursor in cursors {
          context.delete(cursor)
        }
      }

      // Save context and reset it to clear any cached objects
      do {
        try context.save()
        context.reset()
      } catch {
        print("Failed to clear test data: \(error)")
      }
    }
  }

  // MARK: - Test Data Helpers

  /// Creates test subscriptions using TestDataGenerator
  func createTestSubscriptions(count: Int) -> [SubscriptionItem] {
    return TestDataGenerator.createTestSubscriptions(count: count)
  }

  /// Creates test posts using TestDataGenerator
  func createTestPosts(count: Int, subscriptionID: String? = nil) -> [PostItem] {
    return TestDataGenerator.createTestPosts(count: count, subscriptionID: subscriptionID)
  }

  // MARK: - Assertion Helpers

  /// Asserts that the expected number of network calls were made
  /// - Parameters:
  ///   - expectedSubscriptionCalls: Expected calls to getSubscriptions()
  ///   - expectedPostCalls: Expected calls to getPosts()
  func assertNetworkCallCounts(
    expectedSubscriptionCalls: Int,
    expectedPostCalls: Int,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    XCTAssertEqual(
      getSubscriptionsCallCount,
      expectedSubscriptionCalls,
      "Unexpected number of subscription calls",
      file: file,
      line: line
    )
    XCTAssertEqual(
      getPostsCallCount,
      expectedPostCalls,
      "Unexpected number of post calls",
      file: file,
      line: line
    )
  }
}
