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

final class PostSyncMigrationTests: XCTestCase {
    private enum MigrationTestError: Error {
        case legacyModelURLNotFound
        case legacyModelLoadFailed(path: String)
        case legacyCursorEntityNotFound
        case legacySubscriptionEntityNotFound
    }

    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PostSyncMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        try super.tearDownWithError()
    }

    func testLegacyCursorStoreLoadsAndSupportsSyncStatus() async throws {
        let storeURL = tempDirectory.appendingPathComponent("RoverCommHubModel.sqlite")
        try createLegacyStore(at: storeURL, cursor: "legacy-forward-cursor")

        let context = try migrateStoreAndGetContext(at: storeURL)
        let request = NSFetchRequest<NSManagedObject>(entityName: "SyncStatus")
        request.fetchLimit = 1

        let existing = try context.fetch(request).first
        if let existing {
            XCTAssertEqual(existing.value(forKey: "roverEntity") as? String, "posts")
            XCTAssertEqual(existing.value(forKey: "cursor") as? String, "legacy-forward-cursor")
        } else {
            guard let entity = NSEntityDescription.entity(forEntityName: "SyncStatus", in: context) else {
                XCTFail("SyncStatus entity not found after migration")
                return
            }

            let inserted = NSManagedObject(entity: entity, insertInto: context)
            inserted.setValue("posts", forKey: "roverEntity")
            inserted.setValue("post-migration-cursor", forKey: "cursor")
            inserted.setValue(false, forKey: "historyComplete")
            try context.save()

            let verify = NSFetchRequest<NSManagedObject>(entityName: "SyncStatus")
            verify.predicate = NSPredicate(format: "roverEntity == %@", "posts")
            verify.fetchLimit = 1

            let fetched = try context.fetch(verify).first
            XCTAssertEqual(fetched?.value(forKey: "cursor") as? String, "post-migration-cursor")
            XCTAssertEqual(fetched?.value(forKey: "historyComplete") as? Bool, false)
        }

        // Verify new entities added in this migration are present in the schema.
        for entityName in ["Conversation", "Participant", "Reply", "ReplyContentBlock"] {
            XCTAssertNotNil(
                NSEntityDescription.entity(forEntityName: entityName, in: context),
                "\(entityName) entity missing from migrated schema"
            )
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            XCTAssertNoThrow(
                try context.fetch(fetchRequest),
                "Fetching \(entityName) after migration should not throw"
            )
        }
    }

    func testLegacySubscriptionStoreLoadsAndSupportsLogoURL() async throws {
        let storeURL = tempDirectory.appendingPathComponent("RoverCommHubModel-subscriptions.sqlite")
        let expectedLogoURL = URL(string: "https://example.com/logo.png")!
        try createLegacyStore(
            at: storeURL,
            cursor: "legacy-forward-cursor",
            subscription: LegacySubscriptionSeed(
                id: "sub-v1",
                name: "Legacy Subscription",
                description: "Seeded from model v1",
                optIn: true,
                status: "published"
            )
        )

        let context = try migrateStoreAndGetContext(at: storeURL)
        let request = NSFetchRequest<NSManagedObject>(entityName: "Subscription")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", "sub-v1")

        guard let subscription = try context.fetch(request).first else {
            XCTFail("Subscription did not migrate from model v1")
            return
        }

        XCTAssertEqual(subscription.value(forKey: "name") as? String, "Legacy Subscription")
        XCTAssertEqual(
            subscription.value(forKey: "subscriptionDescription") as? String,
            "Seeded from model v1"
        )
        XCTAssertEqual(subscription.value(forKey: "optIn") as? Bool, true)
        XCTAssertEqual(subscription.value(forKey: "status") as? String, "published")
        XCTAssertNil(subscription.value(forKey: "logoURL") as? URL)

        subscription.setValue(expectedLogoURL, forKey: "logoURL")
        try context.save()
        context.reset()

        let verify = NSFetchRequest<NSManagedObject>(entityName: "Subscription")
        verify.fetchLimit = 1
        verify.predicate = NSPredicate(format: "id == %@", "sub-v1")
        let reloadedSubscription = try context.fetch(verify).first

        XCTAssertEqual(reloadedSubscription?.value(forKey: "logoURL") as? URL, expectedLogoURL)
    }

    private func createLegacyStore(
        at storeURL: URL,
        cursor: String,
        subscription: LegacySubscriptionSeed? = nil
    ) throws {
        guard let legacyModelURL = InboxPersistentContainer.compiledModelURL(named: "RoverCommHubModel") else {
            XCTFail("Unable to resolve legacy Core Data model URL from RoverNotifications bundle")
            throw MigrationTestError.legacyModelURLNotFound
        }

        guard let legacyModel = NSManagedObjectModel(contentsOf: legacyModelURL) else {
            XCTFail("Unable to load legacy Core Data model from \(legacyModelURL.path)")
            throw MigrationTestError.legacyModelLoadFailed(path: legacyModelURL.path)
        }

        let container = NSPersistentContainer(name: "LegacyRoverCommHubModel", managedObjectModel: legacyModel)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.type = NSSQLiteStoreType
        container.persistentStoreDescriptions = [description]

        let loaded = XCTestExpectation(description: "Legacy store loaded")
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 5)
        if let loadError { throw loadError }

        let context = container.viewContext
        guard let entity = NSEntityDescription.entity(forEntityName: "Cursor", in: context) else {
            XCTFail("Cursor entity not found in legacy model")
            throw MigrationTestError.legacyCursorEntityNotFound
        }
        let cursorObject = NSManagedObject(entity: entity, insertInto: context)
        cursorObject.setValue("posts", forKey: "roverEntity")
        cursorObject.setValue(cursor, forKey: "cursor")

        if let subscription {
            guard let subscriptionEntity = NSEntityDescription.entity(forEntityName: "Subscription", in: context) else {
                XCTFail("Subscription entity not found in legacy model")
                throw MigrationTestError.legacySubscriptionEntityNotFound
            }

            let subscriptionObject = NSManagedObject(entity: subscriptionEntity, insertInto: context)
            subscriptionObject.setValue(subscription.id, forKey: "id")
            subscriptionObject.setValue(subscription.name, forKey: "name")
            subscriptionObject.setValue(subscription.description, forKey: "subscriptionDescription")
            subscriptionObject.setValue(subscription.optIn, forKey: "optIn")
            subscriptionObject.setValue(subscription.status, forKey: "status")
        }

        try context.save()
    }

    private func migrateStoreAndGetContext(at storeURL: URL) throws -> NSManagedObjectContext {
        guard let momdURL = InboxPersistentContainer.versionedModelBundleURL(),
            let currentModel = NSManagedObjectModel(contentsOf: momdURL)
        else {
            XCTFail("Unable to load current model from RoverNotifications bundle")
            throw NSError(domain: "PostSyncMigrationTests", code: 1)
        }

        let container = NSPersistentContainer(name: "MigratedRoverCommHubModel", managedObjectModel: currentModel)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.type = NSSQLiteStoreType
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        let loaded = XCTestExpectation(description: "Migrated store loaded")
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 5)
        if let loadError { throw loadError }
        return container.viewContext
    }

    private struct LegacySubscriptionSeed {
        let id: String
        let name: String
        let description: String
        let optIn: Bool
        let status: String
    }
}
