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

import XCTest

@testable import RoverData
@testable import RoverLiveActivities

class MockContextProvider: ContextProvider {
    var context: Context {
        return Context(
            trackingMode: nil,
            isDarkModeEnabled: nil,
            localeLanguage: nil,
            localeRegion: nil,
            localeScript: nil,
            isLocationServicesEnabled: nil,
            location: nil,
            locationAuthorization: nil,
            notificationAuthorization: nil,
            pushToken: nil,
            liveActivityTokens: nil,
            isCellularEnabled: nil,
            isWifiEnabled: nil,
            appBadgeNumber: nil,
            appBuild: "1",
            appIdentifier: "com.test.app",
            appVersion: "1.0.0",
            buildEnvironment: .development,
            deviceIdentifier: "test-device-id",
            deviceManufacturer: "Apple",
            deviceModel: "iPhone",
            deviceName: nil,
            operatingSystemName: "iOS",
            operatingSystemVersion: "17.0",
            screenHeight: nil,
            screenWidth: nil,
            sdkVersion: "1.0.0",
            carrierName: nil,
            radio: nil,
            isTestDevice: nil,
            timeZone: "America/New_York",
            userInfo: nil,
            conversions: nil,
            lastSeen: nil
        )
    }
}

class LiveActivityManagerTests: XCTestCase {
    var manager: LiveActivityManager!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "io.rover.RoverLiveActivity.tokens")
        manager = LiveActivityManager()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "io.rover.RoverLiveActivity.tokens")
        manager = nil
        super.tearDown()
    }

    func testRegisterToken_addsNewToken() {
        // Given
        let pushToStartToken = Context.PushToken(value: "abc123", timestamp: Date())

        // When
        manager.registerToken(
            name: "TestActivity",
            pushToStartToken: pushToStartToken
        )

        // Then
        let tokens = manager.liveActivityTokens
        XCTAssertNotNil(tokens)
        XCTAssertEqual(tokens?.count, 1)
        XCTAssertEqual(tokens?.first?.name, "TestActivity")
        XCTAssertEqual(tokens?.first?.pushToStartToken?.value, "abc123")
    }

    func testRegisterToken_updatesExistingToken() {
        // Given
        let pushToStartToken1 = Context.PushToken(value: "abc123", timestamp: Date())
        manager.registerToken(
            name: "TestActivity",
            pushToStartToken: pushToStartToken1
        )

        // When
        let pushToStartToken2 = Context.PushToken(value: "def456", timestamp: Date())
        manager.registerToken(
            name: "TestActivity",
            pushToStartToken: pushToStartToken2
        )

        // Then
        let tokens = manager.liveActivityTokens
        XCTAssertEqual(tokens?.count, 1)
        XCTAssertEqual(tokens?.first?.pushToStartToken?.value, "def456")
    }

    func testRegisterToken_addsMultipleActivities() {
        // Given
        let token1 = Context.PushToken(value: "token1", timestamp: Date())
        let token2 = Context.PushToken(value: "token2", timestamp: Date())

        // When
        manager.registerToken(name: "Activity1", pushToStartToken: token1)
        manager.registerToken(name: "Activity2", pushToStartToken: token2)

        // Then
        let tokens = manager.liveActivityTokens
        XCTAssertEqual(tokens?.count, 2)
        XCTAssertTrue(tokens?.contains { $0.name == "Activity1" } ?? false)
        XCTAssertTrue(tokens?.contains { $0.name == "Activity2" } ?? false)
    }

    func testRemoveToken_removesExistingToken() {
        // Given
        let pushToStartToken = Context.PushToken(value: "abc123", timestamp: Date())
        manager.registerToken(
            name: "TestActivity",
            pushToStartToken: pushToStartToken
        )

        // When
        manager.removeToken(name: "TestActivity")

        // Then
        XCTAssertNil(manager.liveActivityTokens)
    }

    func testRemoveToken_onlyRemovesSpecifiedToken() {
        // Given
        let token1 = Context.PushToken(value: "token1", timestamp: Date())
        let token2 = Context.PushToken(value: "token2", timestamp: Date())
        manager.registerToken(name: "Activity1", pushToStartToken: token1)
        manager.registerToken(name: "Activity2", pushToStartToken: token2)

        // When
        manager.removeToken(name: "Activity1")

        // Then
        let tokens = manager.liveActivityTokens
        XCTAssertEqual(tokens?.count, 1)
        XCTAssertEqual(tokens?.first?.name, "Activity2")
    }

    func testLiveActivityTokensContextProvider_returnsPersistedTokens() {
        // Given
        let token1 = Context.PushToken(value: "token1", timestamp: Date())
        let token2 = Context.PushToken(value: "token2", timestamp: Date())
        manager.registerToken(name: "Activity1", pushToStartToken: token1)
        manager.registerToken(name: "Activity2", pushToStartToken: token2)

        // When
        let contextTokens = manager.liveActivityTokens

        // Then
        XCTAssertEqual(contextTokens?.count, 2)
    }

    func testTokensPersistAcrossInstances() {
        // Given
        let pushToStartToken = Context.PushToken(value: "persistent_token", timestamp: Date())
        manager.registerToken(
            name: "PersistentActivity",
            pushToStartToken: pushToStartToken
        )

        // When - Create new manager instance
        let newManager = LiveActivityManager()

        // Then
        let tokens = newManager.liveActivityTokens
        XCTAssertNotNil(tokens)
        XCTAssertEqual(tokens?.count, 1)
        XCTAssertEqual(tokens?.first?.name, "PersistentActivity")
        XCTAssertEqual(tokens?.first?.pushToStartToken?.value, "persistent_token")
    }

}
