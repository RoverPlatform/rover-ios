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

/// Identifier used to scope `/home` requests.
///
/// Use a `userID` when available; fall back to a device identifier otherwise.
enum HomeViewIdentifier {
    /// A user identifier for targeted home view requests.
    case userID(String)
    /// A device identifier used when no user ID is available.
    case deviceIdentifier(String)
}

extension HTTPClient {
    /// Retrieves the home view response from the `/home` endpoint.
    ///
    /// Builds a request scoped by `identifier`, then downloads and decodes the response.
    /// Returns a failure if the request cannot be built, the network call fails, or
    /// the response cannot be decoded.
    func getHomeView(identifier: HomeViewIdentifier) async -> Result<HomeViewResponse, Error> {
        let endpoint = engageEndpoint.appendingPathComponent("home")

        guard var urlComponents = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            return .failure(HomeViewServiceError(message: "Invalid home endpoint URL"))
        }
        switch identifier {
        case .userID(let value):
            urlComponents.queryItems = [URLQueryItem(name: "userID", value: value)]
        case .deviceIdentifier(let value):
            urlComponents.queryItems = [URLQueryItem(name: "deviceIdentifier", value: value)]
        }

        guard let url = urlComponents.url else {
            return .failure(HomeViewServiceError(message: "Failed to build home request URL"))
        }
        let request = downloadRequest(url: url)

        os_log(.debug, log: .homeView, "Retrieving home view")

        let result = await download(with: request)

        let jsonData: Data
        switch result {
        case .success(let data, _):
            os_log(.debug, log: .homeView, "Successfully retrieved home view response")
            jsonData = data
        case .error(let error, _):
            os_log(
                .error, log: .homeView, "Failed to fetch home view from %@: %@",
                endpoint.absoluteString, error?.localizedDescription ?? "unknown reason")
            return .failure(
                HomeViewServiceError(message: error?.localizedDescription ?? "unknown reason"))
        }

        do {
            let response = try JSONDecoder().decode(HomeViewResponse.self, from: jsonData)
            return .success(response)
        } catch {
            os_log(
                .error, log: .homeView,
                "Failed to decode home view response: %@",
                error.localizedDescription)
            return .failure(HomeViewServiceError(message: error.localizedDescription))
        }
    }
}

/// Error wrapper for home view request failures.
struct HomeViewServiceError: Error {
    /// Human-readable failure description.
    let message: String
}
