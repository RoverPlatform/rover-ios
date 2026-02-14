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

final class HomeViewManagerTests: XCTestCase {

    private var httpClient: HTTPClient!
    private var userDefaults: UserDefaults!
    private var mockUserInfoManager: MockUserInfoManager!
    private let testSuiteName = "io.rover.test.homeViewManager"

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

        userDefaults = UserDefaults(suiteName: testSuiteName)!
        mockUserInfoManager = MockUserInfoManager()
    }

    override func tearDown() async throws {
        URLProtocolStub.requestHandler = nil
        UserDefaults(suiteName: testSuiteName)?.removePersistentDomain(forName: testSuiteName)
        httpClient = nil
        userDefaults = nil
        mockUserInfoManager = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitLoadsNilWhenNoCachedURL() async {
        let manager = await MainActor.run {
            HomeViewManager(httpClient: httpClient, userDefaults: userDefaults, userInfoManager: mockUserInfoManager)
        }

        let url = await MainActor.run { manager.experienceURL }
        XCTAssertNil(url)
    }

    func testInitLoadsCachedURLFromUserDefaults() async {
        let cachedURL = URL(string: "https://cached.rover.io/experience")!
        seedCache(experienceURL: cachedURL)

        let manager = await MainActor.run {
            HomeViewManager(httpClient: httpClient, userDefaults: userDefaults, userInfoManager: mockUserInfoManager)
        }

        let url = await MainActor.run { manager.experienceURL }
        XCTAssertEqual(url, cachedURL)
    }

    // MARK: - Fetch Tests

    func testFetchIfNeededFetchesOnFirstCall() async {
        var fetchCount = 0
        let json = """
            { "experienceURL": "https://new.rover.io/experience" }
            """.data(using: .utf8)!

        URLProtocolStub.requestHandler = { request in
            fetchCount += 1
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json)
        }

        let manager = await MainActor.run {
            HomeViewManager(httpClient: httpClient, userDefaults: userDefaults, userInfoManager: mockUserInfoManager)
        }

        await manager.fetch()

        XCTAssertEqual(fetchCount, 1)
        let url = await MainActor.run { manager.experienceURL }
        XCTAssertEqual(url, URL(string: "https://new.rover.io/experience"))
    }

    func testFetchSavesURLToUserDefaults() async {
        let json = """
            { "experienceURL": "https://saved.rover.io/experience" }
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

        let manager = await MainActor.run {
            HomeViewManager(httpClient: httpClient, userDefaults: userDefaults, userInfoManager: mockUserInfoManager)
        }

        await manager.fetch()

        let cached = loadCachedResponse()
        XCTAssertEqual(cached?.experienceURL, URL(string: "https://saved.rover.io/experience"))
    }

    func testFetchSavesNilURLToUserDefaults() async {
        seedCache(experienceURL: URL(string: "https://old.rover.io/experience"))

        let json = """
            { "experienceURL": null }
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

        let manager = await MainActor.run {
            HomeViewManager(httpClient: httpClient, userDefaults: userDefaults, userInfoManager: mockUserInfoManager)
        }

        await manager.fetch()

        let cached = loadCachedResponse()
        XCTAssertNotNil(cached, "Response should still be cached")
        XCTAssertNil(cached?.experienceURL)
    }

    // MARK: - Failure Handling Tests

    func testFetchFailureLeavesExperienceURLAsNil() async {
        URLProtocolStub.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let manager = await MainActor.run {
            HomeViewManager(httpClient: httpClient, userDefaults: userDefaults, userInfoManager: mockUserInfoManager)
        }

        await manager.fetch()

        let url = await MainActor.run { manager.experienceURL }
        XCTAssertNil(url)
    }

    func testFetchFailurePreservesCachedURL() async {
        // Pre-populate with a cached URL
        let cachedURL = URL(string: "https://cached.rover.io/experience")!
        seedCache(experienceURL: cachedURL)

        URLProtocolStub.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let manager = await MainActor.run {
            HomeViewManager(httpClient: httpClient, userDefaults: userDefaults, userInfoManager: mockUserInfoManager)
        }

        await manager.fetch()

        // URL should still be the cached value (failure doesn't clear cache)
        let url = await MainActor.run { manager.experienceURL }
        XCTAssertEqual(url, cachedURL)
    }

    // MARK: - Identifier Resolution Tests

    func testFetchPassesUserIDWhenAvailable() async {
        var capturedURL: URL?
        let json = """
            { "experienceURL": "https://example.com" }
            """.data(using: .utf8)!

        URLProtocolStub.requestHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        mockUserInfoManager.userInfo = ["userID": "user-abc"]

        let manager = await MainActor.run {
            HomeViewManager(
                httpClient: httpClient, userDefaults: userDefaults,
                userInfoManager: mockUserInfoManager)
        }

        await manager.fetch()

        let components = URLComponents(url: capturedURL!, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(components.queryItems?.first?.name, "userID")
        XCTAssertEqual(components.queryItems?.first?.value, "user-abc")
    }

    func testFetchPassesTicketmasterIDWhenNoDirectUserID() async {
        var capturedURL: URL?
        let json = """
            { "experienceURL": "https://example.com" }
            """.data(using: .utf8)!

        URLProtocolStub.requestHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        mockUserInfoManager.userInfo = ["ticketmaster.ticketmasterID": "tm-123"]

        let manager = await MainActor.run {
            HomeViewManager(
                httpClient: httpClient, userDefaults: userDefaults,
                userInfoManager: mockUserInfoManager)
        }

        await manager.fetch()

        let components = URLComponents(url: capturedURL!, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(components.queryItems?.first?.name, "userID")
        XCTAssertEqual(components.queryItems?.first?.value, "tm-123")
    }

    func testFetchPassesSeatGeekIDWhenNoOtherUserID() async {
        var capturedURL: URL?
        let json = """
            { "experienceURL": "https://example.com" }
            """.data(using: .utf8)!

        URLProtocolStub.requestHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        mockUserInfoManager.userInfo = ["seatGeek.seatGeekID": "sg-456"]

        let manager = await MainActor.run {
            HomeViewManager(
                httpClient: httpClient, userDefaults: userDefaults,
                userInfoManager: mockUserInfoManager)
        }

        await manager.fetch()

        let components = URLComponents(url: capturedURL!, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(components.queryItems?.first?.name, "userID")
        XCTAssertEqual(components.queryItems?.first?.value, "sg-456")
    }

    func testFetchPrefersDirectUserIDOverTicketmaster() async {
        var capturedURL: URL?
        let json = """
            { "experienceURL": "https://example.com" }
            """.data(using: .utf8)!

        URLProtocolStub.requestHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        mockUserInfoManager.userInfo = [
            "userID": "direct-user",
            "ticketmaster": ["ticketmasterID": "tm-123"],
        ]

        let manager = await MainActor.run {
            HomeViewManager(
                httpClient: httpClient, userDefaults: userDefaults,
                userInfoManager: mockUserInfoManager)
        }

        await manager.fetch()

        let components = URLComponents(url: capturedURL!, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(components.queryItems?.first?.name, "userID")
        XCTAssertEqual(components.queryItems?.first?.value, "direct-user")
    }

    func testFetchPassesDeviceIdentifierWhenNoUserID() async {
        var capturedURL: URL?
        let json = """
            { "experienceURL": "https://example.com" }
            """.data(using: .utf8)!

        URLProtocolStub.requestHandler = { request in
            capturedURL = request.url
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        // Empty userInfo — no user ID sources
        mockUserInfoManager.userInfo = [:]

        let manager = await MainActor.run {
            HomeViewManager(
                httpClient: httpClient, userDefaults: userDefaults,
                userInfoManager: mockUserInfoManager)
        }

        await manager.fetch()

        let components = URLComponents(url: capturedURL!, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(components.queryItems?.first?.name, "deviceIdentifier")
        // Value comes from UIDevice.current.identifierForVendor in simulator
        XCTAssertNotNil(components.queryItems?.first?.value)
    }

    // MARK: - Helpers

    /// Encodes a HomeViewResponse and stores it in the test UserDefaults using the production cache key.
    private func seedCache(experienceURL: URL?) {
        let response = HomeViewResponse(experienceURL: experienceURL)
        let data = try! JSONEncoder().encode(response)
        userDefaults.set(data, forKey: "io.rover.homeView.response")
    }

    /// Decodes the cached HomeViewResponse from the test UserDefaults using the production cache key.
    private func loadCachedResponse() -> HomeViewResponse? {
        guard let data = userDefaults.data(forKey: "io.rover.homeView.response") else { return nil }
        return try? JSONDecoder().decode(HomeViewResponse.self, from: data)
    }
}
