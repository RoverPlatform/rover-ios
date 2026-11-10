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

import RoverFoundation
import XCTest

@testable import RoverData
@testable import RoverNotifications

/// Minimal DI container/resolver double mirroring `Rover`'s conformance, so the
/// assembler wiring can be exercised without a full SDK assembly.
private final class TestContainer: Container, Resolver {
    private var services = [ServiceKey: Any]()

    func set<Service>(entry: ServiceEntry<Service>, for key: ServiceKey) {
        services[key] = entry
    }

    func entry<Service>(for key: ServiceKey) -> ServiceEntry<Service>? {
        services[key] as? ServiceEntry<Service>
    }
}

@MainActor
final class NotificationsAssemblerBadgeTests: XCTestCase {

    /// The Hub reads `RoverBadge` for its tab badge, so it must exist even when the host opts
    /// out of app-icon badging. Only the off case is tested: with it on, the badge calls
    /// `UNUserNotificationCenter.current()`, which raises in a test bundle with no host app.
    func testRoverBadgeIsRegisteredWhenAppBadgeUpdatesAreOff() {
        let container = TestContainer()
        NotificationsAssembler(updateAppBadge: false).assemble(container: container)

        // Replace the badge's dependencies with isolated ones, so the test touches neither the
        // persistent store nor the standard defaults.
        let suiteName = "io.rover.test.assembler.badge.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        container.register(InboxPersistentContainer.self, scope: .singleton) { _ in
            InboxPersistentContainer(storage: .inMemory)
        }
        container.register(InboxSeenWatermark.self, scope: .singleton) { _ in
            InboxSeenWatermark(userDefaults: userDefaults, storageKey: "\(suiteName).watermark")
        }
        container.register(ConfigManager.self, scope: .singleton) { _ in
            ConfigManager(userDefaults: userDefaults)
        }

        let badge = container.resolve(RoverBadge.self)
        XCTAssertNotNil(badge)
        XCTAssertEqual(badge?.updateAppBadge, false)
    }
}
