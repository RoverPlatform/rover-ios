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

final class HomeViewServiceTests: XCTestCase {

    private var httpClient: HTTPClient!

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
    }

    override func tearDown() async throws {
        URLProtocolStub.requestHandler = nil
        httpClient = nil
        try await super.tearDown()
    }

    // MARK: - HTTPClient.getHomeView() Tests

    func testGetHomeViewSuccess() async {
        let json = """
            {
                "experienceURL": "https://testbench.rover.io/stm-hub"
            }
            """.data(using: .utf8)!

        URLProtocolStub.requestHandler = { request in
            XCTAssertTrue(request.url!.path.hasSuffix("/home"))
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json)
        }

        let result = await httpClient.getHomeView(identifier: .deviceIdentifier("test-device"))

        switch result {
        case .success(let response):
            XCTAssertEqual(response.experienceURL, URL(string: "https://testbench.rover.io/stm-hub"))
        case .failure(let error):
            XCTFail("Expected success, got failure: \(error)")
        }
    }

    func testGetHomeViewWithNullURL() async {
        let json = """
            {
                "experienceURL": null
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

        let result = await httpClient.getHomeView(identifier: .deviceIdentifier("test-device"))

        switch result {
        case .success(let response):
            XCTAssertNil(response.experienceURL)
        case .failure(let error):
            XCTFail("Expected success, got failure: \(error)")
        }
    }

    func testGetHomeViewNetworkError() async {
        URLProtocolStub.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let result = await httpClient.getHomeView(identifier: .deviceIdentifier("test-device"))

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure:
            break  // Expected
        }
    }

    func testGetHomeViewServerError() async {
        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let result = await httpClient.getHomeView(identifier: .deviceIdentifier("test-device"))

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure:
            break  // Expected
        }
    }

    func testGetHomeViewMalformedResponse() async {
        // experienceURL must be string or null; number causes decode failure
        let json = """
            { "experienceURL": 123 }
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

        let result = await httpClient.getHomeView(identifier: .deviceIdentifier("test-device"))

        switch result {
        case .success:
            XCTFail("Expected failure due to invalid type for experienceURL")
        case .failure:
            break  // Expected
        }
    }

    func testGetHomeViewRequestHitsCorrectEndpoint() async {
        var capturedURL: URL?

        let json = """
            {
                "experienceURL": "https://example.com"
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

        _ = await httpClient.getHomeView(identifier: .deviceIdentifier("test-device"))

        XCTAssertEqual(capturedURL?.absoluteString, "https://engage.test.com/home?deviceIdentifier=test-device")
    }

    func testGetHomeViewPassesUserIDAsQueryParam() async {
        var capturedURL: URL?

        let json = """
            { "experienceURL": "https://example.com" }
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

        _ = await httpClient.getHomeView(identifier: .userID("user-123"))

        let components = URLComponents(url: capturedURL!, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(components.queryItems?.count, 1)
        XCTAssertEqual(components.queryItems?.first?.name, "userID")
        XCTAssertEqual(components.queryItems?.first?.value, "user-123")
    }

    func testGetHomeViewPassesDeviceIdentifierAsQueryParam() async {
        var capturedURL: URL?

        let json = """
            { "experienceURL": "https://example.com" }
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

        _ = await httpClient.getHomeView(identifier: .deviceIdentifier("device-456"))

        let components = URLComponents(url: capturedURL!, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(components.queryItems?.count, 1)
        XCTAssertEqual(components.queryItems?.first?.name, "deviceIdentifier")
        XCTAssertEqual(components.queryItems?.first?.value, "device-456")
    }
}
