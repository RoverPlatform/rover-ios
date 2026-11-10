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

extension URLSession {
    /// Fetches the request and decodes its body as JSON, retrying once on a transport failure.
    ///
    /// Async rather than a Combine `dataTaskPublisher` pipeline: cancelling that pipeline on the main
    /// thread while URLSession completed it on its delegate queue over-released an object and crashed.
    func fetchJSON(for request: URLRequest) async -> Result<Any?, Error> {
        do {
            let (data, response) = try await dataRetryingOnce(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            return .success(try JSONSerialization.jsonObject(with: data))
        } catch {
            return .failure(error)
        }
    }

    private func dataRetryingOnce(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw error
        } catch {
            try Task.checkCancellation()
            return try await data(for: request)
        }
    }
}
