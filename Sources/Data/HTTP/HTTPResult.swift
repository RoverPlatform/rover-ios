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

public enum HTTPResult {
    case error(error: Error?, isRetryable: Bool)
    case success(data: Data, urlResponse: HTTPURLResponse)
}

extension HTTPResult {
    package init(data: Data?, urlResponse: URLResponse?, error: Error?) {
        if let error = error {
            self = .error(error: error, isRetryable: true)
            return
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            self = .error(error: error, isRetryable: true)
            return
        }

        switch httpResponse.statusCode {
        case 200:
            guard let data = data else {
                self = .error(error: HTTPError.emptyResponseData, isRetryable: true)
                return
            }
            self = .success(data: data, urlResponse: httpResponse)
        case 201...299:
            // Responses other than 200 may legitimately omit a body (e.g. 204 No Content).
            self = .success(data: data ?? Data(), urlResponse: httpResponse)
        case 304:
            // 304 (Not Modified) should always return empty Data().
            self = .success(data: Data(), urlResponse: httpResponse)
        case 408, 429, 500...599:
            let error = HTTPError.invalidStatusCode(statusCode: httpResponse.statusCode, responseBody: data)
            self = .error(error: error, isRetryable: true)
        default:
            let error = HTTPError.invalidStatusCode(statusCode: httpResponse.statusCode, responseBody: data)
            self = .error(error: error, isRetryable: false)
        }
    }
}
