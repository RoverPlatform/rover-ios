import XCTest

@testable import RoverData

final class HTTPResultTests: XCTestCase {
    private func makeHTTPURLResponse(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
    }

    func testStatus200WithDataIsSuccess() {
        let data = "{}".data(using: .utf8)
        let response = makeHTTPURLResponse(statusCode: 200)
        let result = HTTPResult(data: data, urlResponse: response, error: nil)

        guard case .success(let resultData, let resultResponse) = result else {
            XCTFail("Expected success for 200")
            return
        }

        XCTAssertEqual(resultData, data)
        XCTAssertEqual(resultResponse.statusCode, 200)
    }

    func testStatus200WithNilDataIsError() {
        let response = makeHTTPURLResponse(statusCode: 200)
        let result = HTTPResult(data: nil, urlResponse: response, error: nil)

        guard case .error = result else {
            XCTFail("Expected error for 200 with nil data")
            return
        }
    }

    func testStatus202WithBodyDataIsSuccess() {
        let data = #"{"jobId":"abc"}"#.data(using: .utf8)
        let response = makeHTTPURLResponse(statusCode: 202)
        let result = HTTPResult(data: data, urlResponse: response, error: nil)

        guard case .success(let resultData, let resultResponse) = result else {
            XCTFail("Expected success for 202 with body")
            return
        }

        XCTAssertEqual(resultData, data)
        XCTAssertEqual(resultResponse.statusCode, 202)
    }

    func testStatus202WithEmptyDataIsSuccess() {
        let response = makeHTTPURLResponse(statusCode: 202)
        let result = HTTPResult(data: nil, urlResponse: response, error: nil)

        guard case .success(let data, let resultResponse) = result else {
            XCTFail("Expected success for 202")
            return
        }

        XCTAssertTrue(data.isEmpty)
        XCTAssertEqual(resultResponse.statusCode, 202)
    }

    func testStatus304WithEmptyDataIsSuccess() {
        let response = makeHTTPURLResponse(statusCode: 304)
        let result = HTTPResult(data: nil, urlResponse: response, error: nil)

        guard case .success(let data, let resultResponse) = result else {
            XCTFail("Expected success for 304")
            return
        }

        XCTAssertTrue(data.isEmpty)
        XCTAssertEqual(resultResponse.statusCode, 304)
    }

    func testStatus304WithBodyIgnoresResponseBody() {
        let body = #"{"ignored":true}"#.data(using: .utf8)
        let response = makeHTTPURLResponse(statusCode: 304)
        let result = HTTPResult(data: body, urlResponse: response, error: nil)

        guard case .success(let data, let resultResponse) = result else {
            XCTFail("Expected success for 304")
            return
        }

        XCTAssertTrue(data.isEmpty)
        XCTAssertEqual(resultResponse.statusCode, 304)
    }

    func testStatus400IsError() {
        let response = makeHTTPURLResponse(statusCode: 400)
        let result = HTTPResult(data: nil, urlResponse: response, error: nil)

        guard case .error(_, let isRetryable) = result else {
            XCTFail("Expected error for 400")
            return
        }

        XCTAssertFalse(isRetryable)
    }

    func testStatus400WithBodyDataPreservesResponseBody() {
        let body = #"{"error":"bad request"}"#.data(using: .utf8)
        let response = makeHTTPURLResponse(statusCode: 400)
        let result = HTTPResult(data: body, urlResponse: response, error: nil)

        guard case .error(let error, let isRetryable) = result else {
            XCTFail("Expected error for 400 with body")
            return
        }

        XCTAssertFalse(isRetryable)
        guard case .invalidStatusCode(let statusCode, let responseBody) = error as? HTTPError else {
            XCTFail("Expected HTTPError.invalidStatusCode")
            return
        }

        XCTAssertEqual(statusCode, 400)
        XCTAssertEqual(responseBody, body)
    }

    func testStatus500IsRetryableError() {
        let response = makeHTTPURLResponse(statusCode: 500)
        let result = HTTPResult(data: nil, urlResponse: response, error: nil)

        guard case .error(_, let isRetryable) = result else {
            XCTFail("Expected retryable error for 500")
            return
        }

        XCTAssertTrue(isRetryable)
    }

    func testNetworkErrorIsRetryableError() {
        let error = URLError(.notConnectedToInternet)
        let result = HTTPResult(data: nil, urlResponse: nil, error: error)

        guard case .error(_, let isRetryable) = result else {
            XCTFail("Expected retryable error")
            return
        }

        XCTAssertTrue(isRetryable)
    }

    func testStatus408IsRetryableError() {
        let response = makeHTTPURLResponse(statusCode: 408)
        let result = HTTPResult(data: nil, urlResponse: response, error: nil)

        guard case .error(_, let isRetryable) = result else {
            XCTFail("Expected retryable error for 408")
            return
        }

        XCTAssertTrue(isRetryable)
    }

    func testStatus429IsRetryableError() {
        let response = makeHTTPURLResponse(statusCode: 429)
        let result = HTTPResult(data: nil, urlResponse: response, error: nil)

        guard case .error(_, let isRetryable) = result else {
            XCTFail("Expected retryable error for 429")
            return
        }

        XCTAssertTrue(isRetryable)
    }
}
