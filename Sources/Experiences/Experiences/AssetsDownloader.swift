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
import os.log

enum AssetDownloadError: Error, LocalizedError {
    case invalidStatusCode(Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidStatusCode(let statusCode):
            return "Invalid status code: \(statusCode)"
        case .emptyResponse:
            return "Empty response."
        }
    }
}

final class AssetsDownloader {

    private let session: URLSession

    init(cache: URLCache? = nil) {
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldUsePipelining = true
        configuration.networkServiceType = .responsiveData
        configuration.waitsForConnectivity = true
        configuration.urlCache = cache
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)
    }

    func download(url: URL) {
        download(url: url, completion: { _ in })
    }

    func download(url: URL, completion: @escaping (Result<Data, Swift.Error>) -> Void) {
        let request = URLRequest.assetRequest(url: url)
        let urlTask = session.dataTask(with: request) { [session] data, response, error in
            let result = Self.result(data: data, response: response, error: error)

            // An error response cached under `.returnCacheDataElseLoad` would be
            // replayed on every future attempt; drop it so the next attempt goes
            // back to the network.
            if case .failure(let failure) = result, case AssetDownloadError.invalidStatusCode = failure {
                session.configuration.urlCache?.removeCachedResponse(for: request)
            }

            completion(result)
        }

        urlTask.resume()
    }

    /// Maps a `URLSession` data-task callback into a result, treating a non-2xx
    /// response as a failure rather than handing an error page's body to the
    /// caller as asset data. Always produces a value, so callers always hear back.
    static func result(data: Data?, response: URLResponse?, error: Swift.Error?) -> Result<Data, Swift.Error> {
        if let error = error {
            return .failure(error)
        }

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            return .failure(AssetDownloadError.invalidStatusCode(httpResponse.statusCode))
        }

        guard let data = data, !data.isEmpty else {
            return .failure(AssetDownloadError.emptyResponse)
        }

        return .success(data)
    }
}
