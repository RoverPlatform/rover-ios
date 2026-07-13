import CoreData
import XCTest

@testable import RoverNotifications

final class InboxPersistentContainerSaveGuardTests: XCTestCase {
    var container: InboxPersistentContainer!

    override func setUp() async throws {
        container = InboxPersistentContainer(storage: .inMemory)
        let loaded = await container.waitUntilLoaded()
        XCTAssertTrue(loaded, "Expected in-memory container to load before running tests")
    }

    override func tearDown() async throws {
        container = nil
    }

    func testSaveSucceedsWhenGenerationMatchesAndNotCancelled() async throws {
        let generation = await MainActor.run { container.conversationStoreGeneration }
        try await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = UUID()
            conv.createdAt = Date()
            conv.updatedAt = Date()
            try container.saveIfGenerationUnchanged(generation)
        }
        let count = await MainActor.run {
            (try? container.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(count, 1)
    }

    func testSaveThrowsAndRollsBackOnGenerationMismatch() async throws {
        let staleGeneration = await MainActor.run { container.conversationStoreGeneration }
        await MainActor.run { container.bumpConversationStoreGeneration() }

        await MainActor.run {
            let conv = Conversation(context: container.viewContext)
            conv.id = UUID()
            conv.createdAt = Date()
            conv.updatedAt = Date()
        }

        do {
            try await MainActor.run { try container.saveIfGenerationUnchanged(staleGeneration) }
            XCTFail("Expected StaleGenerationError")
        } catch is StaleGenerationError { /* expected */  }

        let count = await MainActor.run {
            (try? container.viewContext.count(for: Conversation.fetchRequest())) ?? -1
        }
        XCTAssertEqual(count, 0, "Context should be rolled back")
    }

    func testPostsSaveThrowsAndRollsBackOnGenerationMismatch() async throws {
        let staleGeneration = await MainActor.run { container.conversationStoreGeneration }
        // bumpConversationStoreGeneration() bumps the single shared epoch that also governs posts saves.
        await MainActor.run { container.bumpConversationStoreGeneration() }

        await MainActor.run {
            let post = Post(context: container.viewContext)
            post.id = UUID()
            post.receivedAt = Date()
            post.isRead = false
            post.subject = "Test Post"
            post.previewText = "Test preview"
            post.url = URL(string: "https://example.com/post")!
        }

        do {
            try await MainActor.run { try container.saveIfGenerationUnchanged(staleGeneration) }
            XCTFail("Expected StaleGenerationError")
        } catch is StaleGenerationError { /* expected */  }

        let count = await MainActor.run {
            (try? container.viewContext.count(for: Post.fetchRequest())) ?? -1
        }
        XCTAssertEqual(count, 0, "Context should be rolled back")
    }

    func testSubscriptionsSaveThrowsAndRollsBackOnGenerationMismatch() async throws {
        let staleGeneration = await MainActor.run { container.conversationStoreGeneration }
        // bumpConversationStoreGeneration() bumps the single shared epoch that also governs subscriptions saves.
        await MainActor.run { container.bumpConversationStoreGeneration() }

        await MainActor.run {
            let subscription = Subscription(context: container.viewContext)
            subscription.id = "sub-1"
            subscription.name = "Test Subscription"
            subscription.status = "published"
            subscription.optIn = true
        }

        do {
            try await MainActor.run { try container.saveIfGenerationUnchanged(staleGeneration) }
            XCTFail("Expected StaleGenerationError")
        } catch is StaleGenerationError { /* expected */  }

        let count = await MainActor.run {
            (try? container.viewContext.count(for: Subscription.fetchRequest())) ?? -1
        }
        XCTAssertEqual(count, 0, "Context should be rolled back")
    }

    func testSaveThrowsCancellationErrorWhenTaskCancelled() async {
        let generation = await MainActor.run { container.conversationStoreGeneration }
        let task = Task {
            do {
                // Yield to allow the cancel() call below to take effect before we proceed
                await Task.yield()
                try await MainActor.run {
                    let conv = Conversation(context: container.viewContext)
                    conv.id = UUID()
                    conv.createdAt = Date()
                    conv.updatedAt = Date()
                    try container.saveIfGenerationUnchanged(generation)
                }
                XCTFail("Expected CancellationError")
            } catch is CancellationError {
                // expected
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
        task.cancel()
        await task.value
    }

    func testFetchAllConversationIDsReturnsInsertedIDs() async throws {
        let id1 = UUID()
        let id2 = UUID()
        try await MainActor.run {
            let c1 = Conversation(context: container.viewContext)
            c1.id = id1
            c1.createdAt = Date()
            c1.updatedAt = Date()
            let c2 = Conversation(context: container.viewContext)
            c2.id = id2
            c2.createdAt = Date()
            c2.updatedAt = Date()
            try container.viewContext.save()
        }
        let ids = await MainActor.run { container.fetchAllConversationIDs() }
        XCTAssertEqual(Set(ids), Set([id1, id2]))
    }

    func testFetchAllConversationIDsReturnsEmptyWhenNoneExist() async {
        let ids = await MainActor.run { container.fetchAllConversationIDs() }
        XCTAssertTrue(ids.isEmpty)
    }
}
