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
import RoverData
import os.log

/// Extension methods for the Core Data persistent container for retrieving posts and posts-related operations.
extension InboxPersistentContainer {

  // MARK: - Posts Operations

  static func fetchPosts(
    forSubscriptionID subscriptionID: UUID? = nil,
    sortedBy sortDescriptors: [NSSortDescriptor] = [
      NSSortDescriptor(key: "receivedAt", ascending: false)
    ]
  ) -> NSFetchRequest<Post> {
    let request = Post.fetchRequest()

    // Prefetch subscription relationship to avoid faulting issues
    request.relationshipKeyPathsForPrefetching = ["subscription"]

    // If subscription ID is provided, filter by that subscription
    if let subscriptionID = subscriptionID {
      request.predicate = NSPredicate(format: "subscription.id == %@", subscriptionID as CVarArg)
    }

    request.sortDescriptors = sortDescriptors
    return request
  }

  /// Fast, synchronous fetch of a post by UUID from local storage
  func fetchPostByID(uuid: UUID) -> Post? {
    let request = Post.fetchRequest()
    request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
    request.fetchLimit = 1

    do {
      let results = try viewContext.fetch(request)
      return results.first
    } catch {
      os_log(
        "Failed to fetch post by UUID: %{public}@",
        log: .hub,
        type: .error,
        error.localizedDescription
      )
      return nil
    }
  }

  /// Fetch post by UUID string with validation
  func fetchPostByID(uuidString: String) -> Post? {
    guard let uuid = UUID(uuidString: uuidString) else {
      os_log(
        "Invalid UUID format: %{public}@",
        log: .hub,
        type: .error,
        uuidString
      )
      return nil
    }

    return fetchPostByID(uuid: uuid)
  }

  static func fetchAllSubscriptions() -> NSFetchRequest<Subscription> {
    let request = Subscription.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
    return request
  }

  // MARK: - Cursor Operations

  func getPostsCursor() -> String? {
    assert(Thread.isMainThread, "getPostsCursor must be called on main thread")

    let request = Cursor.fetchRequest()
    request.predicate = NSPredicate(format: "roverEntity == %@", "posts")
    request.fetchLimit = 1

    do {
      let results = try viewContext.fetch(request)
      return results.first?.cursor
    } catch {
      os_log(
        "Failed to fetch posts cursor: %{public}@",
        log: .hub,
        type: .error,
        error.localizedDescription)
      return nil
    }
  }

  func updatePostsCursor(_ cursor: String?) {
    assert(Thread.isMainThread, "getPostsCursor must be called on main thread")

    let request = Cursor.fetchRequest()
    request.predicate = NSPredicate(format: "roverEntity == %@", "posts")
    request.fetchLimit = 1

    do {
      let results = try self.viewContext.fetch(request)
      if let existingCursor = results.first {
        existingCursor.cursor = cursor
      } else {
        let newCursor = Cursor(context: self.viewContext)
        newCursor.roverEntity = "posts"
        newCursor.cursor = cursor
      }

      try self.viewContext.save()
    } catch {
      os_log(
        "Failed to update posts cursor: %{public}@",
        log: .hub,
        type: .error,
        error.localizedDescription
      )
    }
  }

  // MARK: - Read State Operations

  func markPostAsRead(_ post: Post) {
    assert(Thread.isMainThread, "markPostAsRead must be called on main thread")

    post.isRead = true
    
    do {
      try self.viewContext.save()
    } catch {
      os_log(
        "Failed to mark post as read: %{public}@",
        log: .hub,
        type: .error,
        error.localizedDescription
      )
    }
  }

  // MARK: - Post Creation and Updates

  /// Upsert a post into the managed object context. This does not save the context.
  ///
  /// Returns whether the post proved to be a new one or not.
  ///
  /// Note: assumes that you are already running on the view context (ie main thread).
  @discardableResult
  func createOrUpdatePost(from postItem: PostItem) -> Bool {
    // Push notification delegates are called on main thread, and viewContext uses main queue by default
    assert(Thread.isMainThread, "createOrUpdatePost must be called on main thread")

    // Check if post already exists
    let fetchRequest = Post.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "id == %@", postItem.id as CVarArg)
    fetchRequest.fetchLimit = 1

    do {
      let results = try viewContext.fetch(fetchRequest)

      let post: Post
      let isNewPost: Bool
      if let existingPost = results.first {
        // Update existing post
        post = existingPost
        isNewPost = false
      } else {
        // Create new post
        post = Post(context: viewContext)
        post.id = postItem.id
        isNewPost = true
      }

      // Update post properties
      post.subject = postItem.subject
      post.previewText = postItem.previewText
      post.receivedAt = postItem.receivedAt
      post.url = postItem.url
      post.coverImageURL = postItem.coverImageURL

      // accept an update to read state from server
      post.isRead = post.isRead || postItem.isRead

      // Handle subscription relationship
      if let subscriptionID = postItem.subscriptionID {
        let subscriptionFetchRequest = Subscription.fetchRequest()
        subscriptionFetchRequest.predicate = NSPredicate(
          format: "id == %@", subscriptionID as CVarArg)
        subscriptionFetchRequest.fetchLimit = 1

        let subscriptionResults = try viewContext.fetch(subscriptionFetchRequest)

        if let existingSubscription = subscriptionResults.first {
          post.subscription = existingSubscription
        } else {
            let newSubscription = Subscription(context: viewContext)
            newSubscription.id = subscriptionID
            newSubscription.name = nil
            newSubscription.optIn = true
            newSubscription.status = "published"
            newSubscription.subscriptionDescription = nil
            post.subscription = newSubscription
          os_log(
            "Post references subscription ID %@ that hasn't been synced locally yet, creating a placeholder",
            log: .hub,
            type: .debug,
            subscriptionID
          )
        }
      }

      return isNewPost
    } catch {
      os_log(
        "Failed to create/update post: %{public}@",
        log: .hub,
        type: .error,
        error.localizedDescription
      )
      return false
    }
  }

  // MARK: - Sample Data for Previews

  func loadSampleData() {
    assert(Thread.isMainThread, "loadSampleData must be called on main thread")

    // Create sample subscriptions
    let scoreUpdates = Subscription(context: self.viewContext)
    scoreUpdates.id = "score-updates-id"
    scoreUpdates.name = "Score Updates"

    let promotions = Subscription(context: self.viewContext)
    promotions.id = "promotions-subscription-id"
    promotions.name = "Promotions"

    let gameDayGuide = Subscription(context: self.viewContext)
    gameDayGuide.id = "game-day-guide-subscription-id"
    gameDayGuide.name = "Game Day Guide"

    // Calculate time intervals for sample data
    let fiveMinutesAgo = Date().addingTimeInterval(-300)  // 5 minutes ago
    let thirtyMinutesAgo = Date().addingTimeInterval(-1800)  // 30 minutes ago
    let threeHoursAgo = Date().addingTimeInterval(-10800)  // 3 hours ago
    let twelveHoursAgo = Date().addingTimeInterval(-43200)  // 12 hours ago
    let oneDayAgo = Date().addingTimeInterval(-86400)  // 1 day ago
    let threeDaysAgo = Date().addingTimeInterval(-259200)  // 3 days ago
    let fiveDaysAgo = Date().addingTimeInterval(-432000)  // 5 days ago
    let oneWeekAgo = Date().addingTimeInterval(-604800)  // 1 week ago
    let tenDaysAgo = Date().addingTimeInterval(-864000)  // 10 days ago
    let twoWeeksAgo = Date().addingTimeInterval(-1_209_600)  // 2 weeks ago
    let threeWeeksAgo = Date().addingTimeInterval(-1_814_400)  // 3 weeks ago

    // Create sample posts and store references to mark some as unread
    var createdPosts: [Post] = []

    // First post
    createdPosts.append(
      self.createSamplePost(
        subject: "Jets Gameday Tickets Now Available",
        previewText:
          "Season ticket holders can now purchase additional tickets for the upcoming game against the Patriots. Act fast - limited availability!",
        receivedAt: fiveMinutesAgo,
        url: URL(string: "https://engage.rover.io/posts/0196d5a9-926d-7077-a512-19f7d4f66d7e")!,
        coverImageURL: URL(
          string:
            "https://images.unsplash.com/photo-1608245449230-4ac19066d2d0?q=80&w=1200&auto=format&fit=crop"
        ),
        subscription: gameDayGuide
      ))

    // Second post
    createdPosts.append(
      self.createSamplePost(
        subject: "Test Post (Accent color, dark mode, etc.)",
        previewText:
          "This is a test post for demonstrating how to properly format an HTML engage post.",
        receivedAt: thirtyMinutesAgo,
        url: URL(
          string: "https://engage.staging.rover.io/posts/0196f844-77af-7b79-88b7-1f3fe9071e40")!,
        coverImageURL: nil,
        subscription: gameDayGuide
      ))

    // Third post
    createdPosts.append(
      self.createSamplePost(
        subject: "Stadium Maintenance Update",
        previewText:
          "North entrance construction completed ahead of schedule. All gates will be operational for Sunday's game.",
        receivedAt: thirtyMinutesAgo,
        url: URL(string: "https://orospakr.github.io/rover-engage-sdk-demo-post/demo-post.html")!,
        coverImageURL: nil,
        subscription: gameDayGuide
      ))

    // Fourth post
    createdPosts.append(
      self.createSamplePost(
        subject: "New Mobile Ticketing Features",
        previewText:
          "We've added new mobile ticketing features including instant ticket transfer and improved stadium maps with your seat location.",
        receivedAt: threeHoursAgo,
        url: URL(string: "https://example.com/mobile-ticketing")!,
        coverImageURL: URL(
          string:
            "https://images.unsplash.com/photo-1566150905458-1bf1fc113f0d?q=80&w=1200&auto=format&fit=crop"
        ),
        subscription: gameDayGuide
      ))

    // Fifth post
    createdPosts.append(
      self.createSamplePost(
        subject: "Enhanced Security Protocols",
        previewText:
          "New security screening procedures will be in place starting this weekend. Please arrive 30 minutes earlier than usual.",
        receivedAt: twelveHoursAgo,
        url: URL(string: "https://example.com/security")!,
        coverImageURL: nil,
        subscription: gameDayGuide
      ))

    // Sixth post
    createdPosts.append(
      self.createSamplePost(
        subject: "Fan Appreciation Day Coming Up",
        previewText:
          "Join us next Sunday for Fan Appreciation Day! Special activities, player meet-and-greets, and exclusive merchandise discounts.",
        receivedAt: oneDayAgo,
        url: URL(string: "https://example.com/fan-day")!,
        coverImageURL: URL(
          string:
            "https://images.unsplash.com/photo-1517466787929-bc90951d0974?q=80&w=1200&auto=format&fit=crop"
        ),
        subscription: promotions
      ))

    // Seventh post
    createdPosts.append(
      self.createSamplePost(
        subject: "Gameday Transportation Guide",
        previewText:
          "Beat the traffic with our comprehensive guide to gameday transportation options, including new shuttle services from midtown.",
        receivedAt: threeDaysAgo,
        url: URL(string: "https://example.com/transportation")!,
        coverImageURL: URL(
          string:
            "https://images.unsplash.com/photo-1494522855154-9297ac14b55f?q=80&w=1200&auto=format&fit=crop"
        ),
        subscription: gameDayGuide
      ))

    // Eighth post
    createdPosts.append(
      self.createSamplePost(
        subject: "Jets Mobile App Update",
        previewText:
          "Our latest app update includes live game stats, in-seat food ordering, and instant highlights. Update now!",
        receivedAt: fiveDaysAgo,
        url: URL(string: "https://example.com/app-update")!,
        coverImageURL: nil,
        subscription: promotions
      ))

    // Ninth post
    createdPosts.append(
      self.createSamplePost(
        subject: "2023 Season Survey",
        previewText:
          "Help us improve your gameday experience by completing our annual fan survey. Takes only 5 minutes!",
        receivedAt: oneWeekAgo,
        url: URL(string: "https://example.com/survey")!,
        coverImageURL: nil,
        subscription: promotions
      ))

    // Tenth post
    createdPosts.append(
      self.createSamplePost(
        subject: "Jets Calendar Integration",
        previewText:
          "Never miss a game again! Sync the complete Jets schedule directly to your favorite calendar app.",
        receivedAt: tenDaysAgo,
        url: URL(string: "https://example.com/calendar")!,
        coverImageURL: URL(
          string:
            "https://images.unsplash.com/photo-1531266752426-aad472b7bbf4?q=80&w=1200&auto=format&fit=crop"
        ),
        subscription: gameDayGuide
      ))

    // Eleventh post
    createdPosts.append(
      self.createSamplePost(
        subject: "Stadium WiFi Upgrades Complete",
        previewText:
          "We've upgraded our stadium WiFi network to deliver faster speeds and better coverage throughout the venue.",
        receivedAt: twoWeeksAgo,
        url: URL(string: "https://example.com/wifi")!,
        coverImageURL: nil,
        subscription: gameDayGuide
      ))

    // Twelfth post
    createdPosts.append(
      self.createSamplePost(
        subject: "New Stadium Food Options",
        previewText:
          "Check out our expanded food offerings featuring local NYC restaurants, craft beers, and vegetarian/vegan options.",
        receivedAt: twoWeeksAgo.addingTimeInterval(43200),  // 2 weeks ago + 12 hours (to add variety)
        url: URL(string: "https://example.com/food")!,
        coverImageURL: nil,
        subscription: promotions
      ))

    // Thirteenth post
    createdPosts.append(
      self.createSamplePost(
        subject: "Premium Season Ticket Packages",
        previewText:
          "Exclusive preview of our premium season ticket packages for next season. Early access for current ticket holders!",
        receivedAt: threeWeeksAgo,
        url: URL(string: "https://example.com/premium-tickets")!,
        coverImageURL: URL(
          string:
            "https://images.unsplash.com/photo-1546519638-68e109498ffc?q=80&w=1200&auto=format&fit=crop"
        ),
        subscription: promotions
      ))

    // Fourteenth post
    createdPosts.append(
      self.createSamplePost(
        subject: "Final Score: Jets 24 - Patriots 17",
        previewText: "What a game! Check out the highlights and postgame interviews in the app.",
        receivedAt: threeDaysAgo.addingTimeInterval(14400),  // 3 days ago + 4 hours (to add variety)
        url: URL(string: "https://example.com/game-highlights")!,
        coverImageURL: nil,
        subscription: scoreUpdates
      ))

    // Fifteenth post
    createdPosts.append(
      self.createSamplePost(
        subject: "Halftime Score: Jets 14 - Patriots 10",
        previewText: "Jets leading at the half. Strong defensive performance so far.",
        receivedAt: threeDaysAgo.addingTimeInterval(10800),  // 3 days ago + 3 hours (to add variety)
        url: URL(string: "https://example.com/halftime")!,
        coverImageURL: nil,
        subscription: scoreUpdates
      ))

    do {
      try self.viewContext.save()

      // Mark some posts as unread (indices 0, 3, 4, 5) to match the sample data pattern
      if createdPosts.count >= 6 {
        createdPosts[0].isRead = false  // First post
        createdPosts[3].isRead = false  // Fourth post
        createdPosts[4].isRead = false  // Fifth post
        createdPosts[5].isRead = false  // Sixth post

        try self.viewContext.save()
      }
    } catch {
      os_log(
        "Failed to load sample data: %{public}@",
        log: .hub,
        type: .error,
        error.localizedDescription
      )
    }

  }

  private func createSamplePost(
    subject: String, previewText: String, receivedAt: Date, url: URL, coverImageURL: URL?,
    subscription: Subscription
  ) -> Post {
    let post = Post(context: viewContext)
    post.id = UUID()
    post.subject = subject
    post.previewText = previewText
    post.receivedAt = receivedAt
    post.url = url
    post.coverImageURL = coverImageURL
    post.subscription = subscription
    return post
  }

  // Creates a sample post for preview purposes
  func createSamplePreviewPost() -> Post {
    let post = Post(context: viewContext)
    post.id = UUID()
    post.subject = "Sample Post Title"
    post.previewText = "This is a sample post for preview purposes."
    post.receivedAt = Date()
    post.coverImageURL = nil

    // CoreData posts are related to subscriptions via relationship, not via ID
    post.subscription = nil
    return post
  }
}
