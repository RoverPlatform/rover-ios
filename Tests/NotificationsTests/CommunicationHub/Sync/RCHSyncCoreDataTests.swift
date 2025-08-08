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

/// Tests for RCHSync Core Data integration and persistence
final class RCHSyncCoreDataTests: RCHSyncTestBase {

  // MARK: - Core Data Integration Tests

  /// Test post create vs update logic in Core Data persistence
  func testPostUpsertBehavior() async {
    await clearAllData()

    // Create initial test post data
    let postID = UUID()
    let initialPostItem = PostItem(
      id: postID,
      subject: "Initial Subject",
      previewText: "Initial preview text",
      receivedAt: Date(),
      url: URL(string: "https://example.com/initial"),
      coverImageURL: URL(string: "https://example.com/initial.jpg"),
      subscriptionID: "sub-123",
      isRead: false
    )

    // Test CREATE: First time creating a post
    let createResult = await MainActor.run {
      testContainer.createOrUpdatePost(from: initialPostItem)
    }
    XCTAssertTrue(createResult, "Should successfully create new post")

    // Verify post was created
    let createdPost = await MainActor.run {
      testContainer.fetchPostByID(uuid: postID)
    }
    XCTAssertNotNil(createdPost, "Post should exist after creation")
    XCTAssertEqual(createdPost?.subject, "Initial Subject", "Post subject should match")
    XCTAssertEqual(createdPost?.previewText, "Initial preview text", "Post preview should match")
    XCTAssertEqual(createdPost?.isRead, false, "Post should initially be unread")

    // Test UPDATE: Modify existing post
    let updatedPostItem = PostItem(
      id: postID,  // Same ID
      subject: "Updated Subject",
      previewText: "Updated preview text",
      receivedAt: Date().addingTimeInterval(3600),  // 1 hour later
      url: URL(string: "https://example.com/updated"),
      coverImageURL: URL(string: "https://example.com/updated.jpg"),
      subscriptionID: "sub-456",  // Different subscription
      isRead: true
    )

    let updateResult = await MainActor.run {
      testContainer.createOrUpdatePost(from: updatedPostItem)
    }
    XCTAssertFalse(updateResult, "Should return false for UPDATE operation (not a new post)")

    // Verify post was updated, not duplicated
    let allPosts = await fetchAllPosts()
    XCTAssertEqual(allPosts.count, 1, "Should still have only one post (updated, not duplicated)")

    let updatedPost = await MainActor.run {
      testContainer.fetchPostByID(uuid: postID)
    }
    XCTAssertNotNil(updatedPost, "Post should still exist after update")
    XCTAssertEqual(updatedPost?.subject, "Updated Subject", "Post subject should be updated")
    XCTAssertEqual(
      updatedPost?.previewText, "Updated preview text", "Post preview should be updated")
    XCTAssertEqual(
      updatedPost?.url?.absoluteString, "https://example.com/updated", "Post URL should be updated")

    // Test READ STATE PRESERVATION: isRead should use OR logic (once read, stays read)
    XCTAssertEqual(updatedPost?.isRead, true, "Post should remain read after update")

    // Test READ STATE OR LOGIC: Try to set back to false
    let revertReadPostItem = PostItem(
      id: postID,
      subject: "Final Subject",
      previewText: "Final preview text",
      receivedAt: Date().addingTimeInterval(7200),
      url: URL(string: "https://example.com/final"),
      coverImageURL: nil,
      subscriptionID: nil,
      isRead: false  // Try to set back to unread
    )

    let revertResult = await MainActor.run {
      testContainer.createOrUpdatePost(from: revertReadPostItem)
    }
    XCTAssertFalse(revertResult, "Should return false for UPDATE operation (not a new post)")

    let finalPost = await MainActor.run {
      testContainer.fetchPostByID(uuid: postID)
    }
    XCTAssertEqual(
      finalPost?.isRead, true,
      "Post should remain read due to OR logic (post.isRead || postItem.isRead)")
    XCTAssertEqual(finalPost?.subject, "Final Subject", "Other properties should still update")
  }

  /// Test foreign key relationships between posts and subscriptions
  func testSubscriptionRelationshipCreation() async {
    await clearAllData()

    // Create test subscription data
    let subscriptionItems = [
      SubscriptionItem(
        id: "sub-123",
        name: "Test Subscription",
        description: "A test subscription for relationships",
        optIn: true,
        status: .published
      )
    ]

    // Create subscription first
    await MainActor.run {
      testContainer.upsertSubscriptions(subscriptionItems)
    }

    // Verify subscription was created
    let createdSubscription = await MainActor.run {
      testContainer.fetchSubscriptionByID("sub-123")
    }
    XCTAssertNotNil(createdSubscription, "Subscription should be created")
    XCTAssertEqual(createdSubscription?.name, "Test Subscription", "Subscription name should match")
    XCTAssertEqual(createdSubscription?.status, "published", "Subscription status should match")

    // Create post with subscription relationship
    let postItem = PostItem(
      id: UUID(),
      subject: "Test Post",
      previewText: "Post with subscription relationship",
      receivedAt: Date(),
      url: URL(string: "https://example.com/post"),
      coverImageURL: nil,
      subscriptionID: "sub-123",  // Link to existing subscription
      isRead: false
    )

    let createResult = await MainActor.run {
      testContainer.createOrUpdatePost(from: postItem)
    }
    XCTAssertTrue(createResult, "Should successfully create post with subscription relationship")

    // Verify relationship was established
    let createdPost = await MainActor.run {
      testContainer.fetchPostByID(uuid: postItem.id)
    }
    XCTAssertNotNil(createdPost, "Post should be created")
    XCTAssertNotNil(createdPost?.subscription, "Post should have subscription relationship")
    XCTAssertEqual(
      createdPost?.subscription?.id, "sub-123", "Post should link to correct subscription")
    XCTAssertEqual(
      createdPost?.subscription?.name, "Test Subscription",
      "Related subscription should have correct name")

    // Test bidirectional relationship
    let fetchedSubscription = await MainActor.run {
      testContainer.fetchSubscriptionByID("sub-123")
    }
    XCTAssertNotNil(fetchedSubscription?.posts, "Subscription should have posts relationship")
    XCTAssertEqual(
      fetchedSubscription?.posts?.count, 1, "Subscription should have one related post")

    // Test relationship update when post subscription changes
    let updatedPostItem = PostItem(
      id: postItem.id,  // Same post
      subject: "Updated Post",
      previewText: "Post with updated subscription",
      receivedAt: Date(),
      url: URL(string: "https://example.com/updated"),
      coverImageURL: nil,
      subscriptionID: "sub-456",  // Different subscription (doesn't exist yet)
      isRead: false
    )

    _ = await MainActor.run {
      testContainer.createOrUpdatePost(from: updatedPostItem)
    }

    // Verify relationship was updated and placeholder subscription created
    let updatedPost = await MainActor.run {
      testContainer.fetchPostByID(uuid: postItem.id)
    }
    XCTAssertNotNil(updatedPost?.subscription, "Post should still have subscription relationship")
    XCTAssertEqual(updatedPost?.subscription?.id, "sub-456", "Post should link to new subscription")

    // Verify placeholder subscription was created
    let placeholderSubscription = await MainActor.run {
      testContainer.fetchSubscriptionByID("sub-456")
    }
    XCTAssertNotNil(placeholderSubscription, "Placeholder subscription should be created")
    XCTAssertNil(placeholderSubscription?.name, "Placeholder subscription should have nil name")
    XCTAssertEqual(
      placeholderSubscription?.status, "published",
      "Placeholder subscription should have default status")
    XCTAssertEqual(
      placeholderSubscription?.optIn, true, "Placeholder subscription should have default optIn")

    // Verify original subscription no longer has this post
    let originalSubscription = await MainActor.run {
      testContainer.fetchSubscriptionByID("sub-123")
    }
    XCTAssertEqual(
      originalSubscription?.posts?.count, 0, "Original subscription should no longer have the post")
  }

  /// Test cursor state management and persistence
  func testCursorPersistenceAndRetrieval() async {
    await clearAllData()

    // Test initial state - no cursor should exist
    let initialCursor = await MainActor.run {
      testContainer.getPostsCursor()
    }
    XCTAssertNil(initialCursor, "Initial cursor should be nil")

    // Test creating first cursor
    let firstCursor = "cursor-page-1"
    await MainActor.run {
      testContainer.updatePostsCursor(firstCursor)
    }

    // Verify cursor was saved
    let retrievedFirstCursor = await MainActor.run {
      testContainer.getPostsCursor()
    }
    XCTAssertEqual(
      retrievedFirstCursor, firstCursor, "Should retrieve the same cursor that was saved")

    // Test updating existing cursor
    let secondCursor = "cursor-page-2"
    await MainActor.run {
      testContainer.updatePostsCursor(secondCursor)
    }

    // Verify cursor was updated, not duplicated
    let retrievedSecondCursor = await MainActor.run {
      testContainer.getPostsCursor()
    }
    XCTAssertEqual(retrievedSecondCursor, secondCursor, "Should retrieve the updated cursor")

    // Verify only one cursor entity exists
    let allCursors = await MainActor.run {
      let request = Cursor.fetchRequest()
      request.predicate = NSPredicate(format: "roverEntity == %@", "posts")
      return try? testContainer.viewContext.fetch(request)
    }
    XCTAssertEqual(allCursors?.count, 1, "Should have exactly one cursor entity")
    XCTAssertEqual(
      allCursors?.first?.cursor, secondCursor, "The single cursor should have the latest value")
    XCTAssertEqual(
      allCursors?.first?.roverEntity, "posts", "Cursor should be tagged for posts entity")

    // Test setting cursor to nil (clearing it)
    await MainActor.run {
      testContainer.updatePostsCursor(nil)
    }

    let nilCursor = await MainActor.run {
      testContainer.getPostsCursor()
    }
    XCTAssertNil(nilCursor, "Cursor should be nil after clearing")

    // Verify cursor entity still exists but with nil value
    let clearedCursors = await MainActor.run {
      let request = Cursor.fetchRequest()
      request.predicate = NSPredicate(format: "roverEntity == %@", "posts")
      return try? testContainer.viewContext.fetch(request)
    }
    XCTAssertEqual(clearedCursors?.count, 1, "Cursor entity should still exist")
    XCTAssertNil(clearedCursors?.first?.cursor, "Cursor value should be nil")

    // Test setting cursor again after clearing
    let thirdCursor = "cursor-page-3"
    await MainActor.run {
      testContainer.updatePostsCursor(thirdCursor)
    }

    let retrievedThirdCursor = await MainActor.run {
      testContainer.getPostsCursor()
    }
    XCTAssertEqual(
      retrievedThirdCursor, thirdCursor, "Should be able to set cursor again after clearing")

    // Test persistence across context operations
    // Save context explicitly and fetch again
    await MainActor.run {
      try? testContainer.viewContext.save()
    }

    let persistedCursor = await MainActor.run {
      testContainer.getPostsCursor()
    }
    XCTAssertEqual(persistedCursor, thirdCursor, "Cursor should persist across context saves")
  }

  /// Test Core Data transaction ACID properties
  func testCoreDataTransactionIntegrity() async {
    await clearAllData()

    // Test ATOMICITY: All operations in a transaction succeed or all fail
    let subscriptionItems = [
      SubscriptionItem(
        id: "sub-1", name: "Sub 1", description: "First", optIn: true, status: .published),
      SubscriptionItem(
        id: "sub-2", name: "Sub 2", description: "Second", optIn: false, status: .archived),
      SubscriptionItem(
        id: "sub-3", name: "Sub 3", description: "Third", optIn: true, status: .unpublished),
    ]

    // This should succeed atomically
    await MainActor.run {
      testContainer.upsertSubscriptions(subscriptionItems)
    }

    // Verify all subscriptions were created (atomicity)
    let allSubscriptions = await fetchAllSubscriptions()
    XCTAssertEqual(allSubscriptions.count, 3, "All subscriptions should be created atomically")

    // Test CONSISTENCY: Data constraints are maintained
    let postItem = PostItem(
      id: UUID(),
      subject: "Test Post",
      previewText: "Testing consistency",
      receivedAt: Date(),
      url: URL(string: "https://example.com"),
      coverImageURL: nil,
      subscriptionID: "sub-1",  // Valid subscription ID
      isRead: false
    )

    let createResult = await MainActor.run {
      testContainer.createOrUpdatePost(from: postItem)
    }
    XCTAssertTrue(createResult, "Post creation should succeed with valid subscription ID")

    // Verify relationship consistency
    let createdPost = await MainActor.run {
      testContainer.fetchPostByID(uuid: postItem.id)
    }
    XCTAssertNotNil(createdPost?.subscription, "Post should have valid subscription relationship")
    XCTAssertEqual(createdPost?.subscription?.id, "sub-1", "Relationship should be consistent")

    // Test ISOLATION: Concurrent operations don't interfere
    // Create multiple posts concurrently
    let concurrentPostItems = (1...5).map { index in
      PostItem(
        id: UUID(),
        subject: "Concurrent Post \(index)",
        previewText: "Testing isolation \(index)",
        receivedAt: Date().addingTimeInterval(TimeInterval(index)),
        url: URL(string: "https://example.com/\(index)"),
        coverImageURL: nil,
        subscriptionID: "sub-\(index % 3 + 1)",  // Rotate through sub-1, sub-2, sub-3
        isRead: false
      )
    }

    // Execute concurrent post creations
    await withTaskGroup(of: Bool.self) { group in
      for postItem in concurrentPostItems {
        group.addTask {
          await MainActor.run {
            self.testContainer.createOrUpdatePost(from: postItem)
          }
        }
      }

      // Wait for all to complete
      var results: [Bool] = []
      for await result in group {
        results.append(result)
      }

      // All should succeed (isolation maintained)
      XCTAssertTrue(results.allSatisfy { $0 }, "All concurrent operations should succeed")
    }

    // Verify all posts were created correctly (isolation didn't cause corruption)
    let allPosts = await fetchAllPosts()
    XCTAssertEqual(allPosts.count, 6, "Should have original post + 5 concurrent posts")

    // Test DURABILITY: Changes persist after save
    let preCommitPostCount = allPosts.count

    // Force save
    await MainActor.run {
      try? testContainer.viewContext.save()
    }

    // Verify data persists after save
    let postCommitPosts = await fetchAllPosts()
    XCTAssertEqual(
      postCommitPosts.count, preCommitPostCount, "Post count should persist after save")

    // Test transaction rollback scenario
    // Create a post with an invalid scenario that should maintain consistency
    let invalidPost = PostItem(
      id: UUID(),
      subject: "",  // Empty subject might be invalid depending on constraints
      previewText: "Testing rollback",
      receivedAt: Date(),
      url: nil,
      coverImageURL: nil,
      subscriptionID: "nonexistent-sub",  // This will create a placeholder, so it's actually valid
      isRead: false
    )

    // This should still succeed because the implementation creates placeholder subscriptions
    let invalidResult = await MainActor.run {
      testContainer.createOrUpdatePost(from: invalidPost)
    }
    XCTAssertTrue(
      invalidResult,
      "Post creation should succeed even with nonexistent subscription (placeholder created)")

    // Verify placeholder subscription was created (consistency maintained)
    let placeholderSub = await MainActor.run {
      testContainer.fetchSubscriptionByID("nonexistent-sub")
    }
    XCTAssertNotNil(
      placeholderSub, "Placeholder subscription should be created to maintain consistency")

    // Test data integrity after multiple operations
    let finalPosts = await fetchAllPosts()
    let finalSubscriptions = await fetchAllSubscriptions()

    XCTAssertEqual(finalPosts.count, 7, "Should have 7 posts total")
    XCTAssertEqual(
      finalSubscriptions.count, 4, "Should have 4 subscriptions (3 original + 1 placeholder)")

    // Verify all posts have valid subscription relationships
    for post in finalPosts {
      XCTAssertNotNil(post.subscription, "Every post should have a subscription relationship")
      XCTAssertNotNil(post.subscription?.id, "Every subscription should have an ID")
    }
  }

  /// Test placeholder subscription creation for orphaned posts
  func testPlaceholderSubscriptionCreation() async {
    await clearAllData()

    // Test creating post with nonexistent subscription ID
    let orphanedPostItem = PostItem(
      id: UUID(),
      subject: "Orphaned Post",
      previewText: "Post without existing subscription",
      receivedAt: Date(),
      url: URL(string: "https://example.com/orphaned"),
      coverImageURL: nil,
      subscriptionID: "nonexistent-subscription-id",
      isRead: false
    )

    // Create the orphaned post
    let createResult = await MainActor.run {
      testContainer.createOrUpdatePost(from: orphanedPostItem)
    }
    XCTAssertTrue(
      createResult, "Should successfully create post even with nonexistent subscription")

    // Verify post was created
    let createdPost = await MainActor.run {
      testContainer.fetchPostByID(uuid: orphanedPostItem.id)
    }
    XCTAssertNotNil(createdPost, "Orphaned post should be created")
    XCTAssertEqual(createdPost?.subject, "Orphaned Post", "Post properties should be correct")

    // Verify placeholder subscription was automatically created
    let placeholderSub = await MainActor.run {
      testContainer.fetchSubscriptionByID("nonexistent-subscription-id")
    }
    XCTAssertNotNil(placeholderSub, "Placeholder subscription should be automatically created")

    // Verify placeholder subscription has default values
    XCTAssertEqual(
      placeholderSub?.id, "nonexistent-subscription-id", "Placeholder should have correct ID")
    XCTAssertNil(placeholderSub?.name, "Placeholder should have nil name")
    XCTAssertNil(placeholderSub?.subscriptionDescription, "Placeholder should have nil description")
    XCTAssertEqual(placeholderSub?.optIn, true, "Placeholder should have default optIn = true")
    XCTAssertEqual(
      placeholderSub?.status, "published", "Placeholder should have default status = PUBLISHED")

    // Verify relationship is established
    XCTAssertEqual(
      createdPost?.subscription?.id, "nonexistent-subscription-id",
      "Post should link to placeholder subscription")
    XCTAssertEqual(placeholderSub?.posts?.count, 1, "Placeholder subscription should have one post")

    // Test multiple orphaned posts with same nonexistent subscription
    let secondOrphanedPost = PostItem(
      id: UUID(),
      subject: "Second Orphaned Post",
      previewText: "Another post with same nonexistent subscription",
      receivedAt: Date().addingTimeInterval(3600),
      url: URL(string: "https://example.com/orphaned2"),
      coverImageURL: nil,
      subscriptionID: "nonexistent-subscription-id",  // Same nonexistent ID
      isRead: true
    )

    _ = await MainActor.run {
      testContainer.createOrUpdatePost(from: secondOrphanedPost)
    }

    // Verify no duplicate placeholder subscription was created
    let allSubscriptions = await fetchAllSubscriptions()
    let placeholderSubscriptions = allSubscriptions.filter {
      $0.id == "nonexistent-subscription-id"
    }
    XCTAssertEqual(
      placeholderSubscriptions.count, 1, "Should have only one placeholder subscription")

    // Verify both posts link to the same placeholder
    let updatedPlaceholder = await MainActor.run {
      testContainer.fetchSubscriptionByID("nonexistent-subscription-id")
    }
    XCTAssertEqual(
      updatedPlaceholder?.posts?.count, 2, "Placeholder subscription should now have two posts")

    // Test placeholder gets replaced when real subscription data arrives
    let realSubscriptionItem = SubscriptionItem(
      id: "nonexistent-subscription-id",  // Same ID as placeholder
      name: "Real Subscription Name",
      description: "Real subscription description",
      optIn: false,
      status: .archived
    )

    await MainActor.run {
      testContainer.upsertSubscriptions([realSubscriptionItem])
    }

    // Verify placeholder was updated with real data
    let updatedSubscription = await MainActor.run {
      testContainer.fetchSubscriptionByID("nonexistent-subscription-id")
    }
    XCTAssertNotNil(updatedSubscription, "Subscription should still exist")
    XCTAssertEqual(
      updatedSubscription?.name, "Real Subscription Name",
      "Placeholder should be updated with real name")
    XCTAssertEqual(
      updatedSubscription?.subscriptionDescription, "Real subscription description",
      "Description should be updated")
    XCTAssertEqual(updatedSubscription?.optIn, false, "OptIn should be updated")
    XCTAssertEqual(updatedSubscription?.status, "archived", "Status should be updated")

    // Verify posts still link to the updated subscription
    XCTAssertEqual(
      updatedSubscription?.posts?.count, 2, "Updated subscription should still have both posts")

    let firstPost = await MainActor.run {
      testContainer.fetchPostByID(uuid: orphanedPostItem.id)
    }
    let secondPost = await MainActor.run {
      testContainer.fetchPostByID(uuid: secondOrphanedPost.id)
    }

    XCTAssertEqual(
      firstPost?.subscription?.name, "Real Subscription Name",
      "First post should link to updated subscription")
    XCTAssertEqual(
      secondPost?.subscription?.name, "Real Subscription Name",
      "Second post should link to updated subscription")

    // Test orphaned post with nil subscription ID
    let nilSubscriptionPost = PostItem(
      id: UUID(),
      subject: "Post with nil subscription",
      previewText: "Post without any subscription",
      receivedAt: Date(),
      url: URL(string: "https://example.com/nil-sub"),
      coverImageURL: nil,
      subscriptionID: nil,  // No subscription
      isRead: false
    )

    let nilSubResult = await MainActor.run {
      testContainer.createOrUpdatePost(from: nilSubscriptionPost)
    }
    XCTAssertTrue(nilSubResult, "Should successfully create post with nil subscription")

    let nilSubPost = await MainActor.run {
      testContainer.fetchPostByID(uuid: nilSubscriptionPost.id)
    }
    XCTAssertNil(
      nilSubPost?.subscription,
      "Post with nil subscriptionID should have nil subscription relationship")
  }
}
