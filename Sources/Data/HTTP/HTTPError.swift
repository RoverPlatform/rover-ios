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

package enum HTTPError: Error {
    case emptyResponseData
    case failedToUnzipResponseData
    case invalidStatusCode(statusCode: Int, responseBody: Data?)
    case decodingFailed(Error)
    case invalidURL
}

extension HTTPError: LocalizedError {
    package var errorDescription: String? {
        switch self {
        case .emptyResponseData:
            return "Empty response data"
        case .failedToUnzipResponseData:
            return "Failed to unzip response data"
        case .invalidStatusCode(let statusCode, let responseBody):
            let bodyString = responseBody.flatMap { String(data: $0, encoding: .utf8) } ?? "<binary or empty>"
            return "Invalid status code: \(statusCode), response body: \(bodyString)"
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid or malformed URL"
        }
    }
}

/// Returns `true` if `error` is an HTTP 410 Gone response.
public func isHTTP410(_ error: Error) -> Bool {
    guard case .invalidStatusCode(statusCode: 410, _) = error as? HTTPError
    else { return false }
    return true
}

/// Creates an opaque `Error` representing an HTTP status-code failure.
/// Use this from modules that import `RoverData` but cannot access the internal
/// `HTTPError` type directly.
public func makeHTTPStatusCodeError(statusCode: Int, responseBody: Data?) -> Error {
    HTTPError.invalidStatusCode(statusCode: statusCode, responseBody: responseBody)
}
