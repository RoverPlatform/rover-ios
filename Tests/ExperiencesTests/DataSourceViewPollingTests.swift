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
import SwiftUI
import UIKit
import XCTest

@testable import RoverData
@testable import RoverExperiences

/// Drives the real `DataSourceView` in a key window, with `URLSession.shared` answered by a
/// registered `URLProtocol`, to check when the view fetches and when it stops.
private let pollingHost = "datasource-polling.example.com"

@MainActor
final class DataSourceViewPollingTests: XCTestCase {
    private var window: UIWindow!
    private var controls: HostControls!

    override func setUp() {
        super.setUp()
        PollingStubProtocol.reset()
        URLProtocol.registerClass(PollingStubProtocol.self)
    }

    override func tearDown() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        controls = nil
        URLProtocol.unregisterClass(PollingStubProtocol.self)
        PollingStubProtocol.reset()
        super.tearDown()
    }

    // MARK: - Cases

    func testAppearingFetchesOnceAndDoesNotPollWithoutInterval() async throws {
        show(makeDataSource(pollInterval: nil))

        try await waitForRequests(atLeast: 1, within: 5)
        try await Task.sleep(for: .seconds(2.5))

        XCTAssertEqual(PollingStubProtocol.requestCount, 1)
    }

    func testPollsAtTheInterval() async throws {
        show(makeDataSource(pollInterval: 1))

        try await waitForRequests(atLeast: 1, within: 5)
        let afterFirstFetch = PollingStubProtocol.requestCount
        try await waitForRequests(atLeast: afterFirstFetch + 2, within: 3.5)
    }

    func testRemovingTheViewStopsPolling() async throws {
        show(makeDataSource(pollInterval: 1))

        // Wait for one poll, so the loop is past its first fetch and sleeping.
        try await waitForRequests(atLeast: 2, within: 5)
        controls.isShown = false
        let atRemoval = PollingStubProtocol.requestCount

        try await Task.sleep(for: .seconds(2.5))

        XCTAssertEqual(PollingStubProtocol.requestCount, atRemoval)
    }

    func testRefreshFetchesImmediately() async throws {
        // An interval far longer than the test, so any second fetch can only be the refresh.
        let dataSource = makeDataSource(pollInterval: 30)
        show(dataSource)

        try await waitForRequests(atLeast: 1, within: 5)
        XCTAssertEqual(PollingStubProtocol.requestCount, 1)

        dataSource.objectWillChange.send()

        try await waitForRequests(atLeast: 2, within: 1)
    }

    func testRapidlyTogglingTheViewCancelsFetchesWithoutCrashing() async throws {
        PollingStubProtocol.responseTiming = .random
        show(makeDataSource(pollInterval: 1))

        for _ in 0..<300 {
            controls.isShown.toggle()
            try await Task.sleep(for: .milliseconds(Int.random(in: 1...6)))
        }

        controls.isShown = true
        let beforeSettling = PollingStubProtocol.requestCount
        try await waitForRequests(atLeast: beforeSettling + 1, within: 5)

        XCTAssertGreaterThan(PollingStubProtocol.requestCount, 1)
        XCTAssertGreaterThan(
            PollingStubProtocol.stoppedBeforeResponseCount,
            0,
            "No fetch was cancelled mid-flight, so the crash scenario was not exercised"
        )
    }

    func testParentDataChangingOnlyTheBodyRefetchesWithTheNewBody() async throws {
        // A long interval, so the second request can only come from the body changing.
        let dataSource = makeDataSource(
            pollInterval: 30,
            httpMethod: .post,
            httpBody: #"{"id":"{{data.id}}"}"#
        )
        show(dataSource, parentData: ["id": "1"])

        try await waitForRequests(atLeast: 1, within: 5)
        XCTAssertEqual(PollingStubProtocol.lastBody, #"{"id":"1"}"#)

        controls.parentData = ["id": "2"]

        try await waitForRequests(atLeast: 2, within: 2)
        XCTAssertEqual(PollingStubProtocol.lastBody, #"{"id":"2"}"#)
    }

    func testFetchesNeverOverlapWhenAResponseOutlastsTheInterval() async throws {
        PollingStubProtocol.responseTiming = .after(1.5)
        show(makeDataSource(pollInterval: 1))

        // Overlapping fetches would start the second request at about 1 s, while the first was
        // still in flight; waiting for it is enough.
        try await waitForRequests(atLeast: 2, within: 5)

        XCTAssertEqual(PollingStubProtocol.maxInFlightCount, 1)
        // Not overlapping by cancelling the slow request first: every response was waited for.
        XCTAssertEqual(PollingStubProtocol.stoppedBeforeResponseCount, 0)
    }

    // MARK: - Hosting

    private func makeDataSource(
        pollInterval: Int?,
        httpMethod: RoverExperiences.DataSource.HTTPMethod = .get,
        httpBody: String? = nil
    ) -> RoverExperiences.DataSource {
        RoverExperiences.DataSource(
            name: "Polling data source",
            children: [RoverExperiences.Spacer(name: "Spacer")],
            url: "https://\(pollingHost)/scores",
            httpMethod: httpMethod,
            httpBody: httpBody,
            headers: [],
            pollInterval: pollInterval
        )
    }

    private func show(_ dataSource: RoverExperiences.DataSource, parentData: Any? = nil) {
        let controls = HostControls()
        controls.parentData = parentData
        let host = DataSourceHost(
            controls: controls,
            dataSource: dataSource,
            experienceManager: makeExperienceManager()
        )

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(rootView: host)
        window.makeKeyAndVisible()

        self.window = window
        self.controls = controls
    }

    private func makeExperienceManager() -> ExperienceManager {
        ExperienceManager(
            eventQueue: EventQueue(
                client: UnusedEventsClient(),
                flushAt: 1,
                flushInterval: 60,
                maxBatchSize: 1,
                maxQueueSize: 1
            ),
            userInfoContextProvider: EmptyUserInfoContextProvider(),
            conversionsTracker: NoOpConversionsTracker(),
            authContext: AuthenticationContext(userDefaults: UserDefaults())
        )
    }

    /// Polls the request count, yielding the main actor so SwiftUI can render and run tasks.
    private func waitForRequests(
        atLeast expected: Int,
        within timeout: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while PollingStubProtocol.requestCount < expected {
            guard Date() < deadline else {
                XCTFail(
                    "Expected at least \(expected) requests within \(timeout)s, got \(PollingStubProtocol.requestCount)",
                    file: file,
                    line: line
                )
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}

// MARK: - Host view

@MainActor
private final class HostControls: ObservableObject {
    @Published var isShown = true
    @Published var parentData: Any?
}

/// Puts `DataSourceView` in and out of the hierarchy, so SwiftUI cancels its task, and supplies
/// the parent data its request interpolates.
private struct DataSourceHost: View {
    @ObservedObject var controls: HostControls
    let dataSource: RoverExperiences.DataSource
    let experienceManager: ExperienceManager

    var body: some View {
        if controls.isShown {
            DataSourceView(dataSource: dataSource)
                .environment(\.experienceManager, experienceManager)
                .environment(\.data, controls.parentData)
        } else {
            Color.clear
        }
    }
}

// MARK: - Doubles

private final class EmptyUserInfoContextProvider: UserInfoContextProvider {
    var userInfo: Attributes? { nil }
}

private final class NoOpConversionsTracker: ConversionsTrackerService {
    func track(_ tag: String) {}

    func track(_ tags: [String]) {}
}

/// Never reached: nothing in these tests adds an event.
private struct UnusedEventsClient: EventsClient {
    func sendEvents(with events: [Event]) async -> HTTPResult {
        .error(error: nil, isRetryable: false)
    }
}

/// Answers every request to the test host with 200 JSON, counting requests and how many are in
/// flight at once.
private final class PollingStubProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var requests = 0
    private static var stoppedBeforeResponse = 0
    private static var timing = ResponseTiming.immediate
    private static var inFlight = 0
    private static var maxInFlight = 0
    private static var body: String?

    static var requestCount: Int {
        lock.withLock { requests }
    }

    static var stoppedBeforeResponseCount: Int {
        lock.withLock { stoppedBeforeResponse }
    }

    static var maxInFlightCount: Int {
        lock.withLock { maxInFlight }
    }

    /// The body of the most recent request.
    static var lastBody: String? {
        lock.withLock { body }
    }

    enum ResponseTiming {
        case immediate
        /// After 0 to 5 ms on a background queue, so cancellation lands at random points.
        case random
        case after(TimeInterval)
    }

    static var responseTiming: ResponseTiming {
        get { lock.withLock { timing } }
        set { lock.withLock { timing = newValue } }
    }

    static func reset() {
        lock.withLock {
            requests = 0
            stoppedBeforeResponse = 0
            timing = .immediate
            inFlight = 0
            maxInFlight = 0
            body = nil
        }
    }

    private let instanceLock = NSLock()
    private var isFinished = false

    override static func canInit(with request: URLRequest) -> Bool {
        request.url?.host == pollingHost
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let requestBody = Self.readBody(of: request)
        Self.lock.withLock {
            Self.requests += 1
            Self.inFlight += 1
            Self.maxInFlight = max(Self.maxInFlight, Self.inFlight)
            Self.body = requestBody
        }

        let delay: DispatchTimeInterval
        switch Self.responseTiming {
        case .immediate:
            respond()
            return
        case .random:
            delay = .microseconds(Int.random(in: 0...5_000))
        case .after(let seconds):
            delay = .milliseconds(Int(seconds * 1_000))
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [self] in
            respond()
        }
    }

    override func stopLoading() {
        if finish() {
            Self.lock.withLock { Self.stoppedBeforeResponse += 1 }
        }
    }

    /// Marks the load finished, returning whether this call did so.
    private func finish() -> Bool {
        let finishedNow = instanceLock.withLock {
            defer { isFinished = true }
            return !isFinished
        }
        if finishedNow {
            Self.lock.withLock { Self.inFlight -= 1 }
        }
        return finishedNow
    }

    /// URL loading moves a request's body into `httpBodyStream` before a protocol sees it.
    private static func readBody(of request: URLRequest) -> String? {
        if let body = request.httpBody {
            return String(bytes: body, encoding: .utf8)
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while case let count = stream.read(&buffer, maxLength: buffer.count), count > 0 {
            data.append(buffer, count: count)
        }
        return String(bytes: data, encoding: .utf8)
    }

    private func respond() {
        guard finish(), let url = request.url else {
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json", "Cache-Control": "no-store"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"home":101}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
