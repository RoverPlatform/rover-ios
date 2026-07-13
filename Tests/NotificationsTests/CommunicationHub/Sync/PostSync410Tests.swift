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

/// Covers the posts side of the unified 410 reset: syncing through `PostSync` routes through
/// `HubSyncCoordinator`, so a 410 anywhere drops the store and generation-guards the save.
final class PostSync410Tests: PostSyncTestBase {

    func testPosts410DuringSyncLeavesStoreEmptyAndResetsCursor() async throws {
        // Seed an existing post and cursor so we can prove they were dropped, not just absent.
        try await MainActor.run {
            let post = Post(context: testContainer.viewContext)
            post.id = UUID()
            post.receivedAt = Date()
            post.isRead = false
            post.subject = "Existing Post"
            post.previewText = "preview"
            post.url = URL(string: "https://example.com/post")!
            try testContainer.updatePostsSyncStatus(cursor: "existing-cursor")
            try testContainer.viewContext.save()
        }

        URLProtocolMock.stubPosts410()

        let result = await postSync.sync()
        XCTAssertFalse(result, "Sync should report failure on 410")

        // The reset triggered by the 410 is detached from call() (see HubSyncCoordinator);
        // await it explicitly before asserting on post-reset store state.
        await hubSyncCoordinator.awaitCurrentReset()

        let postCount = await countEntities(Post.self)
        XCTAssertEqual(postCount, 0, "410 during posts sync should drop all posts")

        let cursor = await MainActor.run { testContainer.getPostsCursor() }
        XCTAssertNil(cursor, "410 during posts sync should reset the posts cursor")
    }

    func testStaleGenerationDuringPostsSyncIsNotPersisted() async throws {
        let post = createTestPosts(count: 1).first!

        // Deterministic gate: the stub yields into this stream the moment the HTTP request
        // arrives, which proves performActualSync has already captured the generation and is
        // now suspended in the network await. The response is then held for 0.1s to give the
        // test body time to bump the generation before it is delivered. No fixed sleep is
        // needed to reach generation-capture (mirrors ConversationSyncTests'
        // testLateSuccessDoesNotRepopulateAfterDrop).
        let (requestStartedStream, requestStartedContinuation) = AsyncStream<Void>.makeStream()

        URLProtocolMock.stub { request in
            guard let url = request.url, url.path.contains("/posts") else { return nil }
            requestStartedContinuation.yield(())
            requestStartedContinuation.finish()
            let response = PostsSyncResponse(posts: [post], included: nil, nextCursor: nil, hasMore: false)
            return .success(object: response, delay: 0.1)
        }

        async let syncResult = postSync.sync()

        // Block until the request is received — guarantees the generation was already captured.
        for await _ in requestStartedStream { break }

        await MainActor.run { testContainer.bumpConversationStoreGeneration() }

        let result = await syncResult
        XCTAssertFalse(result, "Sync should report failure when the generation moved mid-flight")

        let posts = await fetchAllPosts()
        XCTAssertTrue(posts.isEmpty, "A stale (generation-bumped) response must not be persisted")
    }
}
