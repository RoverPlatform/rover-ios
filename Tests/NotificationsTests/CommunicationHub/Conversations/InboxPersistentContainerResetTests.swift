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

@testable import RoverNotifications

/// What an on-demand reset leaves behind on the storage the SDK actually ships with, which is
/// the whole difference between "the inbox is empty" and "the process is about to abort".
///
/// The rest of the on-demand reset is covered against the in-memory container in
/// `HubSyncCoordinatorTests`; this class exists because the failure it guards against is
/// specific to SQLite. A reset that deletes the store instead of its rows does not merely make
/// the Hub look empty: the next generation-guarded save reaches a coordinator with no store and
/// Core Data raises `_coordinator_you_never_successfully_opened_the_database_corrupted:`, an
/// Objective-C exception that Swift cannot catch. That is invisible from the endpoint-change
/// path, which exits the process immediately afterwards — only a caller that keeps running sees
/// it, which is what the Bench Debug tab's "Reset Hub Data" row is.
final class InboxPersistentContainerResetTests: HubSyncTestBase {

    override static var containerStorage: InboxPersistentContainer.Storage { .persistent }

    /// The store here is a real file that outlives the test process, so it is emptied on the way
    /// out rather than left seeded for whatever runs next.
    override func tearDown() async throws {
        if let coordinator = hubSyncCoordinator {
            await MainActor.run { coordinator.resetHubDataOnDemand() }
            await coordinator.awaitCurrentReset()
        }
        try await super.tearDown()
    }

    func testResetOnDemandEmptiesTheStoreAndLeavesItWritable() async throws {
        try await MainActor.run {
            makeConversation()
            try testContainer.viewContext.save()
        }
        let seeded = try await MainActor.run { try conversationCount() }
        XCTAssertEqual(seeded, 1)

        await MainActor.run { hubSyncCoordinator.resetHubDataOnDemand() }
        await hubSyncCoordinator.awaitCurrentReset()

        try await MainActor.run {
            XCTAssertEqual(
                testContainer.persistentStoreCoordinator.persistentStores.count,
                1,
                "the reset must leave a store attached; without one the next save aborts the process"
            )
            XCTAssertEqual(try conversationCount(), 0, "the rows should be gone")

            // The save that used to abort.
            makeConversation()
            XCTAssertNoThrow(try testContainer.viewContext.save())
            XCTAssertEqual(try conversationCount(), 1, "and the store should be writable again")
        }
    }

    // MARK: - Helpers

    @MainActor
    @discardableResult
    private func makeConversation() -> Conversation {
        let conversation = Conversation(context: testContainer.viewContext)
        conversation.id = UUID()
        conversation.createdAt = Date()
        conversation.updatedAt = Date()
        conversation.subject = "Conversation \(UUID().uuidString)"
        return conversation
    }

    @MainActor
    private func conversationCount() throws -> Int {
        try testContainer.viewContext.count(for: Conversation.fetchRequest())
    }
}
