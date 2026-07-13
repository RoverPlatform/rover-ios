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

/// Base class for SubscriptionSync tests.
class SubscriptionSyncTestBase: HubSyncTestBase {

    var subscriptionSync: SubscriptionSync!

    override func setUp() async throws {
        try await super.setUp()
        subscriptionSync = SubscriptionSync(
            persistentContainer: testContainer,
            hubSyncCoordinator: hubSyncCoordinator
        )
    }

    override func tearDown() async throws {
        subscriptionSync = nil
        try await super.tearDown()
    }

    // MARK: - Test data helpers

    /// Creates test subscriptions using TestDataGenerator.
    func createTestSubscriptions(count: Int) -> [SubscriptionItem] {
        TestDataGenerator.createTestSubscriptions(count: count)
    }
}
