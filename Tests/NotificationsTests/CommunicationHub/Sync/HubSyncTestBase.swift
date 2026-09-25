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

/// Base class for all Hub sync tests providing container, HTTP client, and URL mock setup.
class HubSyncTestBase: XCTestCase {

    /// Suite name for the seen-watermark defaults, so tests never touch the shared standard domain.
    private static let watermarkSuiteName = "io.rover.test.hubSync.seenWatermark"

    var testContainer: InboxPersistentContainer!
    var httpClient: HTTPClient!
    var hubSyncCoordinator: HubSyncCoordinator!
    var seenWatermark: InboxSeenWatermark!
    var mockUserInfoManager: MockUserInfoManager!

    /// Storage mode for `testContainer`. In-memory by default — it needs no files and no
    /// cleanup — but overridable, so a subclass can put the same fixtures on the SQLite store
    /// the SDK actually ships with.
    class var containerStorage: InboxPersistentContainer.Storage { .inMemory }

    override func setUp() async throws {
        try await super.setUp()
        URLProtocolMock.reset()
        URLProtocol.registerClass(URLProtocolMock.self)
        testContainer = InboxPersistentContainer(storage: Self.containerStorage)
        UserDefaults(suiteName: Self.watermarkSuiteName)?
            .removePersistentDomain(forName: Self.watermarkSuiteName)
        seenWatermark = InboxSeenWatermark(userDefaults: UserDefaults(suiteName: Self.watermarkSuiteName)!)
        mockUserInfoManager = MockUserInfoManager()
        let session = MockURLSession.createConfiguredSession()
        let authContext = AuthenticationContext(userDefaults: UserDefaults())
        httpClient = HTTPClient(
            accountToken: "test-token",
            endpoint: URL(string: "https://api.test.com")!,
            engageEndpoint: URL(string: "https://engage.test.com")!,
            session: session,
            authContext: authContext,
            userInfoManager: mockUserInfoManager
        )
        hubSyncCoordinator = await MainActor.run {
            HubSyncCoordinator(
                httpClient: httpClient,
                persistentContainer: testContainer,
                seenWatermark: seenWatermark,
                // Avoid touching UNUserNotificationCenter.current() from the test bundle: the
                // reset always queries delivered notifications now, and .live is unavailable
                // without a host app. Selection logic is covered by hubNotificationIdentifiers tests.
                notificationCenter: .empty
            )
        }
    }

    override func tearDown() async throws {
        URLProtocol.unregisterClass(URLProtocolMock.self)
        URLProtocolMock.reset()
        testContainer = nil
        httpClient = nil
        mockUserInfoManager = nil
        hubSyncCoordinator = nil
        seenWatermark = nil
        UserDefaults(suiteName: Self.watermarkSuiteName)?
            .removePersistentDomain(forName: Self.watermarkSuiteName)
        try await super.tearDown()
    }

    /// Fetches all subscriptions from Core Data.
    /// - Returns: Array of Subscription entities
    func fetchAllSubscriptions() async -> [Subscription] {
        await MainActor.run {
            let request: NSFetchRequest<Subscription> = Subscription.fetchRequest()
            return (try? testContainer.viewContext.fetch(request)) ?? []
        }
    }
}
