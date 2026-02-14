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

final class ConfigSyncTests: XCTestCase {

    private var httpClient: HTTPClient!
    private var configManager: ConfigManager!

    override func setUp() async throws {
        try await super.setUp()

        URLProtocolStub.requestHandler = nil

        let session = MockURLSessionFactory.create()
        let authContext = AuthenticationContext(userDefaults: UserDefaults())
        httpClient = HTTPClient(
            accountToken: "test-token",
            endpoint: URL(string: "https://api.test.com")!,
            engageEndpoint: URL(string: "https://engage.test.com")!,
            session: session,
            authContext: authContext
        )

        configManager = await MainActor.run {
            ConfigManager(userDefaults: UserDefaults(suiteName: "io.rover.test.configSync")!)
        }
    }

    override func tearDown() async throws {
        URLProtocolStub.requestHandler = nil

        // Clean up UserDefaults test suite
        UserDefaults(suiteName: "io.rover.test.configSync")?.removePersistentDomain(forName: "io.rover.test.configSync")

        httpClient = nil
        configManager = nil

        try await super.tearDown()
    }

    // MARK: - HTTPClient.getConfig() Tests

    func testGetConfigSuccess() async {
        let json = """
            {
                "hub": {
                    "isHomeEnabled": true,
                    "isInboxEnabled": true,
                    "isSettingsViewEnabled": true,
                    "deeplink": "testbench-deep-link://tab/inbox"
                },
                "colorScheme": "auto",
                "accentColor": "#4F2683"
            }
            """.data(using: .utf8)!

        URLProtocolStub.requestHandler = { request in
            XCTAssertTrue(request.url!.path.hasSuffix("/config"))
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json)
        }

        let result = await httpClient.getConfig()

        switch result {
        case .success(let config):
            XCTAssertTrue(config.hub.isHomeEnabled)
            XCTAssertTrue(config.hub.isInboxEnabled)
            XCTAssertTrue(config.hub.isSettingsViewEnabled)
            XCTAssertEqual(config.colorScheme, .auto)
            XCTAssertEqual(config.accentColor, "#4F2683")
            XCTAssertEqual(config.hub.deeplink, URL(string: "testbench-deep-link://tab/inbox"))
        case .failure(let error):
            XCTFail("Expected success, got failure: \(error)")
        }
    }

    func testGetConfigPartialResponse() async {
        let json = """
            {
                "hub": {
                    "isHomeEnabled": false,
                    "isInboxEnabled": true,
                    "isSettingsViewEnabled": false
                }
            }
            """.data(using: .utf8)!

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json)
        }

        let result = await httpClient.getConfig()

        switch result {
        case .success(let config):
            XCTAssertFalse(config.hub.isHomeEnabled)
            XCTAssertTrue(config.hub.isInboxEnabled)
            XCTAssertFalse(config.hub.isSettingsViewEnabled)
            XCTAssertNil(config.colorScheme)
            XCTAssertNil(config.accentColor)
            XCTAssertNil(config.hub.deeplink)
        case .failure(let error):
            XCTFail("Expected success, got failure: \(error)")
        }
    }

    func testGetConfigNetworkError() async {
        URLProtocolStub.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let result = await httpClient.getConfig()

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure:
            break  // Expected
        }
    }

    func testGetConfigServerError() async {
        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let result = await httpClient.getConfig()

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure:
            break  // Expected
        }
    }

    // MARK: - ConfigSync Tests

    func testConfigSyncSuccess() async {
        let json = """
            {
                "hub": {
                    "isHomeEnabled": true,
                    "isInboxEnabled": true,
                    "isSettingsViewEnabled": true
                },
                "colorScheme": "dark",
                "accentColor": "#FF0000"
            }
            """.data(using: .utf8)!

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json)
        }

        let configSync = ConfigSync(httpClient: httpClient, configManager: configManager)
        let result = await configSync.sync()

        XCTAssertTrue(result)

        let activeConfig = await MainActor.run { configManager.config }
        XCTAssertTrue(activeConfig.hub.isHomeEnabled)
        XCTAssertEqual(activeConfig.colorScheme, .dark)
        XCTAssertEqual(activeConfig.accentColor, "#FF0000")
    }

    func testConfigSyncFailureReturnsFalse() async {
        URLProtocolStub.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let defaultConfig = await MainActor.run { configManager.config }

        let configSync = ConfigSync(httpClient: httpClient, configManager: configManager)
        let result = await configSync.sync()

        XCTAssertFalse(result)

        // Config should remain unchanged (default values)
        let activeConfig = await MainActor.run { configManager.config }
        XCTAssertEqual(activeConfig, defaultConfig)
    }

    func testConfigSyncRequestHitsCorrectEndpoint() async {
        var capturedURL: URL?

        let json = """
            {
                "hub": {
                    "isHomeEnabled": false,
                    "isInboxEnabled": true,
                    "isSettingsViewEnabled": false
                }
            }
            """.data(using: .utf8)!

        URLProtocolStub.requestHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json)
        }

        let configSync = ConfigSync(httpClient: httpClient, configManager: configManager)
        _ = await configSync.sync()

        XCTAssertEqual(capturedURL?.absoluteString, "https://engage.test.com/config")
    }
}
