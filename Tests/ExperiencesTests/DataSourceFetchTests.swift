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

@testable import RoverExperiences

/// `URLSession.fetchJSON(for:)`: decoding, the single retry, and cancellation.
final class DataSourceFetchTests: XCTestCase {
    private let url = URL(string: "https://datasource.example.com/scores")!
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DataSourceStubProtocol.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        DataSourceStubProtocol.reset()
        super.tearDown()
    }

    func testOKResponseDecodesJSON() async throws {
        DataSourceStubProtocol.responses = [.json(status: 200, #"{"home":101}"#)]

        let result = await session.fetchJSON(for: URLRequest(url: url))

        let body = try XCTUnwrap(try result.get() as? [String: Int])
        XCTAssertEqual(body, ["home": 101])
        XCTAssertEqual(DataSourceStubProtocol.requestCount, 1)
    }

    func testNonOKResponseIsFailureWithoutRetry() async {
        DataSourceStubProtocol.responses = [.json(status: 500, "{}")]

        let result = await session.fetchJSON(for: URLRequest(url: url))

        XCTAssertEqual((result.error as? URLError)?.code, .badServerResponse)
        XCTAssertEqual(DataSourceStubProtocol.requestCount, 1)
    }

    func testInvalidJSONIsFailure() async {
        DataSourceStubProtocol.responses = [.json(status: 200, "not json")]

        let result = await session.fetchJSON(for: URLRequest(url: url))

        XCTAssertNotNil(result.error)
    }

    func testTransportFailureRetriesOnce() async throws {
        DataSourceStubProtocol.responses = [.failure(.networkConnectionLost), .json(status: 200, #"{"home":101}"#)]

        let result = await session.fetchJSON(for: URLRequest(url: url))

        XCTAssertNotNil(try result.get())
        XCTAssertEqual(DataSourceStubProtocol.requestCount, 2)
    }

    func testSecondTransportFailureIsFailure() async {
        DataSourceStubProtocol.responses = [
            .failure(.networkConnectionLost), .failure(.networkConnectionLost), .json(status: 200, "{}")
        ]

        let result = await session.fetchJSON(for: URLRequest(url: url))

        XCTAssertEqual((result.error as? URLError)?.code, .networkConnectionLost)
        XCTAssertEqual(DataSourceStubProtocol.requestCount, 2)
    }

    func testCancelledFetchFailsWithoutRetry() async {
        DataSourceStubProtocol.responses = [.hang, .json(status: 200, "{}")]
        let session = session!
        let request = URLRequest(url: url)

        let fetch = Task { await session.fetchJSON(for: request) }
        let started = await DataSourceStubProtocol.waitForRequests(1, within: 5)
        XCTAssertTrue(started, "The request never reached the stub")
        fetch.cancel()
        let result = await fetch.value

        XCTAssertNotNil(result.error)
        XCTAssertEqual(DataSourceStubProtocol.requestCount, 1)
    }

    /// URLSession reports `.cancelled` when the session itself cancels the load, without the task
    /// being cancelled; retrying would send a request nobody wants.
    func testCancelledURLErrorIsNotRetried() async {
        DataSourceStubProtocol.responses = [.failure(.cancelled), .json(status: 200, "{}")]

        let result = await session.fetchJSON(for: URLRequest(url: url))

        XCTAssertEqual((result.error as? URLError)?.code, .cancelled)
        XCTAssertEqual(DataSourceStubProtocol.requestCount, 1)
    }

    /// The crash was a race, so this is a regression guard rather than proof: cancel fetches at
    /// every point of their lifetime, completion included, and require the process to survive.
    func testCancellingFetchesAtRandomPointsDoesNotCrash() async throws {
        DataSourceStubProtocol.responses = []
        let session = session!
        let request = URLRequest(url: url)

        for _ in 0..<2_000 {
            let fetch = Task { await session.fetchJSON(for: request) }
            try await Task.sleep(for: .microseconds(Int.random(in: 0...2_000)))
            fetch.cancel()
            _ = await fetch.value
        }

        XCTAssertGreaterThan(DataSourceStubProtocol.requestCount, 0, "No fetch reached the stub")
    }
}

private extension Result {
    var error: Failure? {
        guard case .failure(let error) = self else {
            return nil
        }

        return error
    }
}

/// Answers queued responses in order; with the queue empty it answers 200 `{}`.
private final class DataSourceStubProtocol: URLProtocol {
    enum Response {
        case json(status: Int, String)
        case failure(URLError.Code)
        case hang
    }

    private static let lock = NSLock()
    private static var queued: [Response] = []
    private static var requests = 0

    static var responses: [Response] {
        get { lock.withLock { queued } }
        set { lock.withLock { queued = newValue } }
    }

    static var requestCount: Int {
        lock.withLock { requests }
    }

    static func reset() {
        lock.withLock {
            queued = []
            requests = 0
        }
    }

    /// Returns whether `count` requests arrived before the deadline.
    static func waitForRequests(_ count: Int, within timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while requestCount < count {
            guard Date() < deadline else {
                return false
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return true
    }

    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = Self.lock.withLock {
            Self.requests += 1
            return Self.queued.isEmpty ? Response.json(status: 200, "{}") : Self.queued.removeFirst()
        }

        switch response {
        case .json(let status, let body):
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .hang:
            break
        }
    }

    override func stopLoading() {}
}
