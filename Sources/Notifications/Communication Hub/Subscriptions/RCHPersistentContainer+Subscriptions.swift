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

extension RCHPersistentContainer {

  // MARK: - Subscription Operations

  func upsertSubscriptions(_ subscriptionItems: [SubscriptionItem]) {
    assert(Thread.isMainThread, "upsertSubscriptions must be called on main thread")

    do {
      // Process each subscription item individually
      for subscriptionItem in subscriptionItems {
        // Check if subscription already exists
        let fetchRequest = Subscription.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", subscriptionItem.id)
        fetchRequest.fetchLimit = 1

        let results = try viewContext.fetch(fetchRequest)

        let subscription: Subscription
        if let existingSubscription = results.first {
          // Update existing subscription
          subscription = existingSubscription
        } else {
          // Create new subscription
          subscription = Subscription(context: viewContext)
          subscription.id = subscriptionItem.id
        }

        // Update subscription properties
        subscription.name = subscriptionItem.name
        subscription.subscriptionDescription = subscriptionItem.description
        subscription.optIn = subscriptionItem.optIn
        subscription.status = subscriptionItem.status.rawValue
      }

      try viewContext.save()

      os_log(
        "Successfully upserted %d subscriptions", log: .communicationHub, type: .debug,
        subscriptionItems.count)
    } catch {
      os_log(
        "Failed to upsert subscriptions: %@", log: .communicationHub, type: .error,
        error.localizedDescription)
    }
  }

  func fetchSubscriptionByID(_ id: String) -> Subscription? {
    assert(Thread.isMainThread, "fetchSubscriptionByID must be called on main thread")

    let request = Subscription.fetchRequest()
    request.predicate = NSPredicate(format: "id == %@", id)
    request.fetchLimit = 1

    do {
      let results = try viewContext.fetch(request)
      return results.first
    } catch {
      os_log(
        "Failed to fetch subscription by ID: %@", log: .communicationHub, type: .error,
        error.localizedDescription)
      return nil
    }
  }
}
