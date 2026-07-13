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

/// Tests for PostSync subscription sideloading via the posts `included` field
final class PostSyncIncludedSubscriptionsTests: PostSyncTestBase {

    /// Subscriptions returned in `included` are persisted to Core Data
    func testSubscriptionsFromIncludedArePersisted() async {
        let testSubscriptions = createTestSubscriptions(count: 2)
        let testPosts = createTestPosts(count: 1, subscriptionID: testSubscriptions[0].id)
        configureMockForSuccess(subscriptions: testSubscriptions, posts: testPosts)

        _ = await postSync.sync()

        let savedSubscriptions = await fetchAllSubscriptions()
        XCTAssertEqual(savedSubscriptions.count, 2, "Subscriptions from included should be persisted")
    }

    /// Sync succeeds even when the posts response has no `included` field
    func testSyncSucceedsWithNoIncludedSubscriptions() async {
        let testPosts = createTestPosts(count: 3)
        URLProtocolMock.stubPosts(testPosts)

        let result = await postSync.sync()

        XCTAssertTrue(result, "Sync should succeed with no included subscriptions")
        let savedPosts = await fetchAllPosts()
        XCTAssertEqual(savedPosts.count, 3, "Posts should be saved even with no included subscriptions")
    }

    /// Posts are linked to their subscriptions when subscriptions arrive in `included`
    func testSubscriptionsLinkedToPostsAfterSync() async {
        let testSubscriptions = createTestSubscriptions(count: 2)
        let subscription1ID = testSubscriptions[0].id
        let subscription2ID = testSubscriptions[1].id
        let postsForSub1 = createTestPosts(count: 2, subscriptionID: subscription1ID)
        let postsForSub2 = createTestPosts(count: 2, subscriptionID: subscription2ID)
        configureMockForSuccess(
            subscriptions: testSubscriptions,
            posts: postsForSub1 + postsForSub2
        )

        _ = await postSync.sync()

        let savedPosts = await fetchAllPosts()
        XCTAssertEqual(savedPosts.count, 4)
        let postsWithSub1 = savedPosts.filter { $0.subscription?.id == subscription1ID }
        let postsWithSub2 = savedPosts.filter { $0.subscription?.id == subscription2ID }
        XCTAssertEqual(postsWithSub1.count, 2, "2 posts should link to subscription 1")
        XCTAssertEqual(postsWithSub2.count, 2, "2 posts should link to subscription 2")
    }

    /// Exactly one network call is made (the posts request — subscriptions are no longer fetched separately)
    func testOnlyOneNetworkCallIsMade() async {
        let testSubscriptions = createTestSubscriptions(count: 1)
        let testPosts = createTestPosts(count: 2, subscriptionID: testSubscriptions[0].id)
        configureMockForSuccess(subscriptions: testSubscriptions, posts: testPosts)

        _ = await postSync.sync()

        let callLog = URLProtocolMock.getCallLog()
        XCTAssertEqual(callLog.count, 1, "Only one network call should be made")
        XCTAssertTrue(
            callLog.first?.url?.path.contains("/posts") == true,
            "The single call should be to /posts"
        )
    }

    /// Sync returns false when the posts API fails
    func testSyncFailsWhenPostsApiFails() async {
        configureMockForFailure(postsError: URLError(.networkConnectionLost))

        let result = await postSync.sync()

        XCTAssertFalse(result, "Sync should fail when posts API fails")
        let savedPosts = await fetchAllPosts()
        let savedSubscriptions = await fetchAllSubscriptions()
        XCTAssertEqual(savedPosts.count, 0, "No posts should be saved on failure")
        XCTAssertEqual(savedSubscriptions.count, 0, "No subscriptions should be saved on failure")
    }
}
