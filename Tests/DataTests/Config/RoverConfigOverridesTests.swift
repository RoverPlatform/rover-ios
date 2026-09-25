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

@_spi(BenchSupport) @testable import RoverData

final class RoverConfigOverridesTests: XCTestCase {

    private var httpClient: HTTPClient!
    private var userDefaults: UserDefaults!
    private var mockUserInfoManager: MockUserInfoManager!
    private let testSuiteName = "io.rover.test.configOverrides"

    private let backendConfig = RoverConfig(
        hub: RoverConfig.Hub(
            isHomeEnabled: true,
            isInboxEnabled: true,
            isSettingsViewEnabled: true,
            deeplink: URL(string: "backend-deep-link://tab/hub")
        ),
        colorScheme: .dark,
        accentColor: "#4F2683"
    )

    override func setUp() async throws {
        try await super.setUp()

        URLProtocolStub.requestHandler = nil
        mockUserInfoManager = MockUserInfoManager()

        let session = MockURLSessionFactory.create()
        let authContext = AuthenticationContext(userDefaults: UserDefaults())
        httpClient = HTTPClient(
            accountToken: "test-token",
            endpoint: URL(string: "https://api.test.com")!,
            engageEndpoint: URL(string: "https://engage.test.com")!,
            session: session,
            authContext: authContext,
            userInfoManager: mockUserInfoManager
        )

        userDefaults = UserDefaults(suiteName: testSuiteName)!
    }

    override func tearDown() async throws {
        URLProtocolStub.requestHandler = nil
        UserDefaults(suiteName: testSuiteName)?.removePersistentDomain(forName: testSuiteName)
        httpClient = nil
        userDefaults = nil
        mockUserInfoManager = nil
        try await super.tearDown()
    }

    // MARK: - Override Resolution Tests

    func testNoOverridePassesBackendValueThrough() {
        let overrides = RoverConfigOverrides()

        XCTAssertEqual(overrides.applied(to: backendConfig), backendConfig)
    }

    func testValueOverridesBackendValue() {
        let overrides = RoverConfigOverrides(
            isHomeEnabled: .value(false),
            deeplink: .value(URL(string: "testbench-deep-link://tab/hub")!),
            colorScheme: .value(.light),
            accentColor: .value("#FF0000")
        )

        let config = overrides.applied(to: backendConfig)

        XCTAssertFalse(config.hub.isHomeEnabled)
        XCTAssertEqual(config.hub.deeplink, URL(string: "testbench-deep-link://tab/hub"))
        XCTAssertEqual(config.colorScheme, .light)
        XCTAssertEqual(config.accentColor, "#FF0000")
    }

    func testUnsetClearsOptionalFields() {
        let overrides = RoverConfigOverrides(
            deeplink: .unset,
            colorScheme: .unset,
            accentColor: .unset
        )

        let config = overrides.applied(to: backendConfig)

        XCTAssertNil(config.hub.deeplink)
        XCTAssertNil(config.colorScheme)
        XCTAssertNil(config.accentColor)
    }

    func testUnsetRestoresDefaultsForNonOptionalFields() {
        let overrides = RoverConfigOverrides(isHomeEnabled: .unset, isInboxEnabled: .unset)

        let config = overrides.applied(to: backendConfig)

        XCTAssertEqual(config.hub.isHomeEnabled, RoverConfig.Hub().isHomeEnabled)
        XCTAssertEqual(config.hub.isInboxEnabled, RoverConfig.Hub().isInboxEnabled)
    }

    func testFieldsWithoutOverridesAreUntouched() {
        let overrides = RoverConfigOverrides(isHomeEnabled: .value(false))

        let config = overrides.applied(to: backendConfig)

        XCTAssertTrue(config.hub.isInboxEnabled)
        XCTAssertTrue(config.hub.isSettingsViewEnabled)
        XCTAssertEqual(config.colorScheme, .dark)
        XCTAssertEqual(config.accentColor, "#4F2683")
    }

    // MARK: - ConfigManager Layering Tests

    @MainActor
    func testOverridesApplyImmediately() {
        let manager = ConfigManager(userDefaults: userDefaults)
        manager.updateFromBackend(backendConfig)

        manager.overrides = RoverConfigOverrides(isInboxEnabled: .value(false))

        XCTAssertFalse(manager.config.hub.isInboxEnabled)
    }

    @MainActor
    func testOverridesSurviveBackendRefresh() {
        let manager = ConfigManager(userDefaults: userDefaults)
        manager.overrides = RoverConfigOverrides(accentColor: .value("#00FF00"))

        manager.updateFromBackend(backendConfig)

        XCTAssertEqual(manager.config.accentColor, "#00FF00")
        XCTAssertEqual(manager.config.colorScheme, .dark, "Un-overridden fields still come from the backend")
    }

    @MainActor
    func testOverridesAreNotPersisted() {
        let manager = ConfigManager(userDefaults: userDefaults)
        manager.updateFromBackend(backendConfig)
        manager.overrides = RoverConfigOverrides(accentColor: .value("#00FF00"))

        // A fresh manager reads the cache the first one wrote.
        let relaunched = ConfigManager(userDefaults: userDefaults)

        XCTAssertEqual(relaunched.config, backendConfig)
    }

    // MARK: - Home View Application Tests

    @MainActor
    func testEnablingHomeViewFetchesTheHomeView() async {
        let requested = expectation(description: "/home requested")
        stubHomeView(fulfilling: requested)

        let configManager = ConfigManager(userDefaults: userDefaults)
        let homeViewManager = HomeViewManager(
            httpClient: httpClient,
            userDefaults: userDefaults,
            userInfoManager: mockUserInfoManager
        )

        applyConfigOverrides(
            RoverConfigOverrides(isHomeEnabled: .value(true)),
            configManager: configManager,
            homeViewManager: homeViewManager
        )

        await fulfillment(of: [requested], timeout: 2)
    }

    @MainActor
    func testOverridesThatLeaveHomeViewDisabledDoNotFetch() async {
        let requested = expectation(description: "/home requested")
        requested.isInverted = true
        stubHomeView(fulfilling: requested)

        let configManager = ConfigManager(userDefaults: userDefaults)
        let homeViewManager = HomeViewManager(
            httpClient: httpClient,
            userDefaults: userDefaults,
            userInfoManager: mockUserInfoManager
        )

        applyConfigOverrides(
            RoverConfigOverrides(isInboxEnabled: .value(false)),
            configManager: configManager,
            homeViewManager: homeViewManager
        )

        await fulfillment(of: [requested], timeout: 0.5)
    }

    @MainActor
    func testClearingOverridesRestoresBackendValues() {
        let manager = ConfigManager(userDefaults: userDefaults)
        manager.updateFromBackend(backendConfig)
        manager.overrides = RoverConfigOverrides(isHomeEnabled: .value(false), accentColor: .unset)

        manager.overrides = RoverConfigOverrides()

        XCTAssertEqual(manager.config, backendConfig)
    }

    // MARK: - Helpers

    /// Answers any request with a home view response, fulfilling the expectation as it goes.
    private func stubHomeView(fulfilling expectation: XCTestExpectation) {
        let json = """
            { "experienceURL": "https://fetched.rover.io/experience" }
            """.data(using: .utf8)!

        URLProtocolStub.requestHandler = { request in
            expectation.fulfill()
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json)
        }
    }
}
