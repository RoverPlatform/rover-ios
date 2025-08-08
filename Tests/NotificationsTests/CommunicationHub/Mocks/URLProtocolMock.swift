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

import Foundation

@testable import RoverNotifications

/// Mock URLProtocol for intercepting HTTP requests in tests
/// Provides thread-safe state management for parallel test execution
class URLProtocolMock: URLProtocol {

  // MARK: - Thread-Safe State Management

  private static let queue = DispatchQueue(label: "URLProtocolMock", attributes: .concurrent)
  private static var handlers: [(URLRequest) -> MockResponse?] = []
  private static var callLog: [URLRequest] = []
  private static var networkLatency: TimeInterval = 0

  // MARK: - Response Configuration

  /// Adds a request handler that will be checked for each intercepted request
  /// - Parameter handler: Closure that returns a MockResponse if it should handle the request
  static func stub(handler: @escaping (URLRequest) -> MockResponse?) {
    queue.async(flags: .barrier) {
      handlers.append(handler)
    }
  }

  /// Resets all configured handlers and call logs
  static func reset() {
    queue.async(flags: .barrier) {
      handlers.removeAll()
      callLog.removeAll()
      networkLatency = 0
    }
  }

  /// Returns a copy of all intercepted requests
  /// - Returns: Array of URLRequest objects that were intercepted
  static func getCallLog() -> [URLRequest] {
    return queue.sync {
      return Array(callLog)
    }
  }

  /// Sets network latency simulation for all responses
  /// - Parameter delay: Time interval to delay responses
  static func setNetworkLatency(_ delay: TimeInterval) {
    queue.async(flags: .barrier) {
      networkLatency = delay
    }
  }

  // MARK: - URLProtocol Implementation

  override class func canInit(with request: URLRequest) -> Bool {
    // Intercept all requests - handlers will determine if they should respond
    return true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  override func startLoading() {
    // Log the request
    URLProtocolMock.queue.async(flags: .barrier) {
      URLProtocolMock.callLog.append(self.request)
    }

    // Find a handler for this request
    let response: MockResponse? = URLProtocolMock.queue.sync {
      for handler in URLProtocolMock.handlers {
        if let mockResponse = handler(request) {
          return mockResponse
        }
      }
      return nil
    }

    // Get current network latency
    let delay = URLProtocolMock.queue.sync { URLProtocolMock.networkLatency }

    // Process the response
    if let mockResponse = response {
      // Simulate network latency if configured
      let totalDelay = delay + mockResponse.delay
      if totalDelay > 0 {
        DispatchQueue.global().asyncAfter(deadline: .now() + totalDelay) {
          self.sendResponse(mockResponse)
        }
      } else {
        sendResponse(mockResponse)
      }
    } else {
      // No handler found - return a default error
      let error = URLError(.notConnectedToInternet)
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {
    // Nothing to stop for our mock implementation
  }

  // MARK: - Response Handling

  private func sendResponse(_ mockResponse: MockResponse) {
    switch mockResponse {
    case .failure(let error, let statusCode, _):
      if statusCode >= 400 {
        // Send HTTP error response
        sendErrorResponse(statusCode: statusCode)
      } else {
        // Send network error
        client?.urlProtocol(self, didFailWithError: error)
      }

    case .success(let object, let statusCode, _):
      do {
        let encoder = JSONEncoder()
        // Use the same date encoding strategy as the real system
        let rfc3339Formatter = DateFormatter()
        rfc3339Formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        rfc3339Formatter.calendar = Calendar(identifier: .iso8601)
        rfc3339Formatter.timeZone = TimeZone(secondsFromGMT: 0)
        rfc3339Formatter.locale = Locale(identifier: "en_US_POSIX")
        encoder.dateEncodingStrategy = .formatted(rfc3339Formatter)
        let data = try encoder.encode(AnyEncodable(object as! Encodable))
        sendSuccessResponse(data: data, statusCode: statusCode)
      } catch {
        client?.urlProtocol(self, didFailWithError: error)
      }
    }
  }

  private func sendSuccessResponse(data: Data, statusCode: Int) {
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: statusCode,
      httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"]
    )!

    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }

  private func sendErrorResponse(statusCode: Int) {
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: statusCode,
      httpVersion: "HTTP/1.1",
      headerFields: [:]
    )!

    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocolDidFinishLoading(self)
  }
}

// MARK: - MockResponse Types

enum MockResponse {
  case failure(error: Error, statusCode: Int = 500, delay: TimeInterval = 0)
  case success(object: Any, statusCode: Int = 200, delay: TimeInterval = 0)

  var delay: TimeInterval {
    switch self {
    case .failure(_, _, let delay),
      .success(_, _, let delay):
      return delay
    }
  }
}

// MARK: - Builder API for Ergonomic Configuration

extension URLProtocolMock {

  /// Configures mock to return successful subscriptions response
  /// - Parameters:
  ///   - subscriptions: Array of SubscriptionItem to return
  ///   - delay: Optional network delay simulation
  static func stubSubscriptions(_ subscriptions: [SubscriptionItem], delay: TimeInterval = 0) {
    stub { request in
      guard let url = request.url,
        url.path.contains("/subscriptions")
      else { return nil }

      let response = SubscriptionsSyncResponse(subscriptions: subscriptions)
      return .success(object: response, delay: delay)
    }
  }

  /// Configures mock to return successful posts response
  /// - Parameters:
  ///   - posts: Array of PostItem to return
  ///   - hasMore: Whether there are more pages available
  ///   - nextCursor: Cursor for next page (if hasMore is true)
  ///   - delay: Optional network delay simulation
  static func stubPosts(
    _ posts: [PostItem], hasMore: Bool = false, nextCursor: String? = nil, delay: TimeInterval = 0
  ) {
    stub { request in
      guard let url = request.url,
        url.path.contains("/posts")
      else { return nil }

      let response = PostsSyncResponse(posts: posts, nextCursor: nextCursor, hasMore: hasMore)
      return .success(object: response, delay: delay)
    }
  }

  /// Configures mock to return posts response for a specific cursor
  /// - Parameters:
  ///   - cursor: The cursor value to match (nil for first page)
  ///   - posts: Array of PostItem to return
  ///   - hasMore: Whether there are more pages available
  ///   - nextCursor: Cursor for next page (if hasMore is true)
  ///   - delay: Optional network delay simulation
  static func stubPostsForCursor(
    _ cursor: String?, posts: [PostItem], hasMore: Bool = false, nextCursor: String? = nil,
    delay: TimeInterval = 0
  ) {
    stub { request in
      guard let url = request.url,
        url.path.contains("/posts")
      else { return nil }

      // Check if cursor matches
      let requestCursor = url.queryParameters?["cursor"]
      if requestCursor != cursor {
        return nil
      }

      let response = PostsSyncResponse(posts: posts, nextCursor: nextCursor, hasMore: hasMore)
      return .success(object: response, delay: delay)
    }
  }

  /// Configures mock to return error for subscriptions endpoint
  /// - Parameters:
  ///   - error: The error to return
  ///   - statusCode: HTTP status code for the error
  ///   - delay: Optional network delay simulation
  static func stubSubscriptionsError(_ error: Error, statusCode: Int = 500, delay: TimeInterval = 0)
  {
    stub { request in
      guard let url = request.url,
        url.path.contains("/subscriptions")
      else { return nil }

      return .failure(error: error, statusCode: statusCode, delay: delay)
    }
  }

  /// Configures mock to return error for posts endpoint
  /// - Parameters:
  ///   - error: The error to return
  ///   - statusCode: HTTP status code for the error
  ///   - delay: Optional network delay simulation
  static func stubPostsError(_ error: Error, statusCode: Int = 500, delay: TimeInterval = 0) {
    stub { request in
      guard let url = request.url,
        url.path.contains("/posts")
      else { return nil }

      return .failure(error: error, statusCode: statusCode, delay: delay)
    }
  }

  /// Configures complex pagination scenarios with closure-based logic
  /// - Parameter handler: Custom logic for handling paginated requests
  static func stubPaginationScenario(handler: @escaping (URLRequest) -> MockResponse?) {
    stub(handler: handler)
  }
}

// MARK: - Helper Types

/// Type-erased wrapper for encoding arbitrary objects to JSON
private struct AnyEncodable: Encodable {
  private let encodable: Encodable

  init(_ encodable: Encodable) {
    self.encodable = encodable
  }

  func encode(to encoder: Encoder) throws {
    try encodable.encode(to: encoder)
  }
}

// MARK: - URL Extension for Query Parameters

extension URL {
  var queryParameters: [String: String]? {
    guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
      let queryItems = components.queryItems
    else {
      return nil
    }

    var parameters: [String: String] = [:]
    for item in queryItems {
      parameters[item.name] = item.value
    }
    return parameters
  }
}
