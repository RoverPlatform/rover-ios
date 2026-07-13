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
import Foundation
import os.log

extension InboxPersistentContainer {

    // MARK: - Subscription Operations

    @MainActor
    func upsertSubscriptions(_ subscriptionItems: [SubscriptionItem]) throws {
        try stageSubscriptions(subscriptionItems)
        try viewContext.save()
    }

    @MainActor
    func stageSubscriptions(_ subscriptionItems: [SubscriptionItem]) throws {
        for subscriptionItem in subscriptionItems {
            let fetchRequest = Subscription.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", subscriptionItem.id)
            fetchRequest.fetchLimit = 1

            let results = try viewContext.fetch(fetchRequest)

            let subscription: Subscription
            if let existingSubscription = results.first {
                subscription = existingSubscription
            } else {
                subscription = Subscription(context: viewContext)
                subscription.id = subscriptionItem.id
            }

            subscription.name = subscriptionItem.name
            subscription.logoURL = subscriptionItem.logoURL
            subscription.subscriptionDescription = subscriptionItem.description
            subscription.optIn = subscriptionItem.optIn
            subscription.status = subscriptionItem.status.rawValue
        }
    }

    // MARK: - Drop (410 Reset)

    /// Surgically drops all subscriptions data: `Subscription` entities. Subscriptions have no
    /// cursor / `SyncStatus` row — they are a single full-list fetch — so there is nothing else
    /// to clean up. Does not bump `conversationStoreGeneration` itself; the shared epoch is
    /// bumped once, first, by `bumpConversationStoreGeneration()`, which `HubSyncCoordinator`'s
    /// reset task always calls before this method as part of a unified hub-wide reset. Must be
    /// called on the main actor.
    @MainActor
    func dropAllSubscriptions() {
        let subscriptions = (try? viewContext.fetch(Subscription.fetchRequest())) ?? []
        subscriptions.forEach { viewContext.delete($0) }

        do {
            try viewContext.save()
        } catch {
            os_log(
                "Failed to drop all subscriptions: %{private}@",
                log: .hub,
                type: .error,
                error.localizedDescription
            )
            viewContext.rollback()
        }
    }

    @MainActor
    func fetchSubscriptionByID(_ id: String) -> Subscription? {

        let request = Subscription.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1

        do {
            let results = try viewContext.fetch(request)
            return results.first
        } catch {
            os_log(
                "Failed to fetch subscription by ID: %@",
                log: .hub,
                type: .error,
                error.localizedDescription
            )
            return nil
        }
    }
}
