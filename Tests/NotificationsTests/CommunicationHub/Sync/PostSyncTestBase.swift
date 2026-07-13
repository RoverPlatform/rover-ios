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

/// Base class for PostSync tests.
class PostSyncTestBase: HubSyncTestBase {

    var postSync: PostSync!

    override func setUp() async throws {
        try await super.setUp()
        postSync = await MainActor.run {
            PostSync(
                persistentContainer: testContainer,
                hubSyncCoordinator: hubSyncCoordinator
            )
        }
    }

    override func tearDown() async throws {
        postSync = nil
        try await super.tearDown()
    }

    // MARK: - Mock helpers

    /// Configures URLProtocolMock for successful sync operations.
    /// - Parameters:
    ///   - subscriptions: Subscriptions to embed in the posts response
    ///   - posts: Posts to return from the posts response
    func configureMockForSuccess(
        subscriptions: [SubscriptionItem] = [],
        posts: [PostItem]
    ) {
        let included: PostsSyncResponse.IncludedData? =
            subscriptions.isEmpty ? nil : PostsSyncResponse.IncludedData(subscriptions: subscriptions)
        URLProtocolMock.stubPosts(posts, included: included)
    }

    /// Configures URLProtocolMock for failure scenarios.
    /// - Parameter postsError: Error to return from the posts response
    func configureMockForFailure(postsError: Error? = nil) {
        if let postsError {
            URLProtocolMock.stubPostsError(postsError, statusCode: 0)
        }
    }

    // MARK: - Fetch helpers

    /// Fetches all posts from Core Data.
    /// - Returns: Array of Post entities
    func fetchAllPosts() async -> [Post] {
        await MainActor.run {
            let context = testContainer.viewContext
            let request: NSFetchRequest<Post> = Post.fetchRequest()
            return (try? context.fetch(request)) ?? []
        }
    }

    /// Counts entities of a specific type in Core Data.
    /// - Parameter entityType: The entity type to count
    /// - Returns: Number of entities
    func countEntities<T: NSManagedObject>(_ entityType: T.Type) async -> Int {
        await MainActor.run {
            let context = testContainer.viewContext
            let request = NSFetchRequest<T>(entityName: String(describing: entityType))
            return (try? context.count(for: request)) ?? 0
        }
    }

    /// Clears all data from Core Data for test isolation.
    /// Uses individual object deletion to avoid memory management issues with batch operations.
    func clearAllData() async throws {
        try await MainActor.run {
            let context = testContainer.viewContext

            let postRequest: NSFetchRequest<Post> = Post.fetchRequest()
            if let posts = try? context.fetch(postRequest) {
                for post in posts { context.delete(post) }
            }

            let subscriptionRequest: NSFetchRequest<Subscription> = Subscription.fetchRequest()
            if let subscriptions = try? context.fetch(subscriptionRequest) {
                for subscription in subscriptions { context.delete(subscription) }
            }

            let syncStatusRequest: NSFetchRequest<SyncStatus> = SyncStatus.fetchRequest()
            if let syncStatuses = try? context.fetch(syncStatusRequest) {
                for syncStatus in syncStatuses { context.delete(syncStatus) }
            }

            let conversationRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
            if let conversations = try? context.fetch(conversationRequest) {
                for conversation in conversations { context.delete(conversation) }
            }

            let replyRequest: NSFetchRequest<Reply> = Reply.fetchRequest()
            if let replies = try? context.fetch(replyRequest) {
                for reply in replies { context.delete(reply) }
            }

            let participantRequest: NSFetchRequest<Participant> = Participant.fetchRequest()
            if let participants = try? context.fetch(participantRequest) {
                for participant in participants { context.delete(participant) }
            }

            do {
                try context.save()
                context.reset()
            } catch {
                XCTFail("Failed to clear test data: \(error)")
                throw error
            }
        }
    }

    // MARK: - Test data helpers

    /// Creates test subscriptions using TestDataGenerator.
    func createTestSubscriptions(count: Int) -> [SubscriptionItem] {
        TestDataGenerator.createTestSubscriptions(count: count)
    }

    /// Creates test posts using TestDataGenerator.
    func createTestPosts(count: Int, subscriptionID: String? = nil) -> [PostItem] {
        TestDataGenerator.createTestPosts(count: count, subscriptionID: subscriptionID)
    }

    // MARK: - Assertion helpers

    /// Asserts that the expected number of post network calls were made.
    func assertPostCallCount(
        _ expectedPostCalls: Int,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let postCallCount = URLProtocolMock.getCallLog()
            .filter { $0.url?.path.contains("/posts") == true }
            .count
        XCTAssertEqual(
            postCallCount,
            expectedPostCalls,
            "Unexpected number of post calls",
            file: file,
            line: line
        )
    }

    /// Asserts that every posts request carries `include=subscriptions` in its query parameters.
    func assertPostsRequestsIncludeSubscriptions(
        _ callLog: [URLRequest],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let postsRequests = callLog.filter { $0.url?.path.contains("/posts") == true }
        XCTAssertFalse(
            postsRequests.isEmpty,
            "Sync should make at least one posts request",
            file: file,
            line: line
        )
        for request in postsRequests {
            XCTAssertEqual(
                request.url?.queryParameters?["include"],
                PostsSyncResponse.IncludedData.includeKey,
                "Every posts request must include embedded subscriptions",
                file: file,
                line: line
            )
        }
    }

    /// Asserts that sync uses only the posts endpoint (with embedded subscriptions) and makes no
    /// separate /subscriptions requests.
    func assertPostSyncUsesPostsWithEmbeddedSubscriptions(
        _ callLog: [URLRequest],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertPostsRequestsIncludeSubscriptions(callLog, file: file, line: line)
        let subscriptionsRequests = callLog.filter { $0.url?.path.contains("/subscriptions") == true }
        XCTAssertTrue(
            subscriptionsRequests.isEmpty,
            "Sync should not make any /subscriptions requests",
            file: file,
            line: line
        )
    }
}
