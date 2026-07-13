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
import RoverFoundation
import os.log

public final class HTTPClient {
    public let endpoint: URL
    public let engageEndpoint: URL
    public let accountToken: String
    public let session: URLSession
    public let authContext: AuthenticationContext
    package let userInfoManager: UserInfoManager

    public init(
        accountToken: String,
        endpoint: URL,
        engageEndpoint: URL,
        session: URLSession,
        authContext: AuthenticationContext
    ) {
        self.accountToken = accountToken
        self.endpoint = endpoint
        self.engageEndpoint = engageEndpoint
        self.session = session
        self.authContext = authContext
        self.userInfoManager = NullUserInfoManager()
    }

    package init(
        accountToken: String,
        endpoint: URL,
        engageEndpoint: URL,
        session: URLSession,
        authContext: AuthenticationContext,
        userInfoManager: UserInfoManager
    ) {
        self.accountToken = accountToken
        self.endpoint = endpoint
        self.engageEndpoint = engageEndpoint
        self.session = session
        self.authContext = authContext
        self.userInfoManager = userInfoManager
    }
}

private struct NullUserInfoManager: UserInfoManager {
    func updateUserInfo(block: (inout Attributes) -> Void) {}
    func clearUserInfo() {}
    var currentUserInfo: [String: Any] { [:] }
}

extension HTTPClient {
    public func authenticateRequestIfNeeded(request: URLRequest, for userID: String?) async -> URLRequest {
        guard userID != nil else {
            return request
        }

        return await authContext.authenticateRequest(request: request)
    }

    public func downloadRequest(queryItems: [URLQueryItem]) -> URLRequest {
        var urlComponents = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = queryItems

        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("gzip", forHTTPHeaderField: "accept-encoding")
        urlRequest.setAccountToken(accountToken)
        urlRequest.setRoverUserAgent()
        return urlRequest
    }

    public func downloadRequest(url: URL) -> URLRequest {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("gzip", forHTTPHeaderField: "accept-encoding")
        urlRequest.setAccountToken(accountToken)
        urlRequest.setRoverUserAgent()
        return urlRequest
    }

    package func authenticatedDownloadRequest(
        url: URL,
        queryItems: [URLQueryItem] = [],
        additionalHeaders: [String: String] = [:]
    ) async throws -> URLRequest {
        try await authenticatedRequest(
            url: url,
            queryItems: queryItems,
            additionalHeaders: additionalHeaders
        ) { downloadRequest(url: $0) }
    }

    package func authenticatedUploadRequest(
        url: URL,
        queryItems: [URLQueryItem] = [],
        additionalHeaders: [String: String] = [:]
    ) async throws -> URLRequest {
        try await authenticatedRequest(
            url: url,
            queryItems: queryItems,
            additionalHeaders: additionalHeaders
        ) { uploadRequest(url: $0) }
    }

    private func authenticatedRequest(
        url: URL,
        queryItems: [URLQueryItem],
        additionalHeaders: [String: String],
        base: (URL) -> URLRequest
    ) async throws -> URLRequest {
        let (resolvedURL, userID) = try await resolveAuthenticatedURL(url: url, queryItems: queryItems)
        var request = await authenticateRequestIfNeeded(request: base(resolvedURL), for: userID)
        for (field, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }

    private func resolveAuthenticatedURL(url: URL, queryItems: [URLQueryItem]) async throws -> (URL, String?) {
        let identifiers = await resolveIdentifiers(userInfoManager: userInfoManager)

        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw HTTPError.invalidURL
        }
        urlComponents.queryItems = (urlComponents.queryItems ?? []) + queryItems + identifiers.queryItems

        guard let resolvedURL = urlComponents.url else {
            throw HTTPError.invalidURL
        }

        return (resolvedURL, identifiers.userID)
    }

    package func authenticatedDownloadDecoding<T: Decodable>(
        _ type: T.Type,
        url: URL,
        queryItems: [URLQueryItem] = [],
        additionalHeaders: [String: String] = [:],
        log: OSLog,
        label: String
    ) async -> Result<T, Error> {
        let request: URLRequest
        do {
            request = try await authenticatedDownloadRequest(
                url: url,
                queryItems: queryItems,
                additionalHeaders: additionalHeaders
            )
        } catch {
            return .failure(error)
        }
        os_log(.debug, log: log, "Retrieving %@", label)
        return await downloadDecoding(type, with: request, log: log, label: label)
    }

    package func downloadDecoding<T: Decodable>(
        _ type: T.Type,
        with request: URLRequest,
        log: OSLog,
        label: String
    ) async -> Result<T, Error> {
        downloadDecoding(type, result: await download(with: request), log: log, label: label)
    }

    package func downloadDecoding<T: Decodable>(
        _ type: T.Type,
        result: HTTPResult,
        log: OSLog,
        label: String
    ) -> Result<T, Error> {
        switch result {
        case .success(let data, let response):
            os_log(.debug, log: log, "Successfully retrieved %@ (status: %d)", label, response.statusCode)
            do {
                return .success(try JSONDecoder.default.decode(T.self, from: data))
            } catch {
                os_log(
                    .error,
                    log: log,
                    "Failed to decode %@ response: %@ (status: %d, payload bytes: %d)",
                    label,
                    error.localizedDescription,
                    response.statusCode,
                    data.count
                )
                return .failure(HTTPError.decodingFailed(error))
            }
        case .error(let error, _):
            os_log(
                .error,
                log: log,
                "Failed to fetch %@: %@",
                label,
                error?.localizedDescription ?? "unknown"
            )
            return .failure(error ?? URLError(.unknown))
        }
    }

    public func uploadRequest() -> URLRequest {
        var urlRequest = uploadRequest(url: endpoint)
        urlRequest.setValue("gzip", forHTTPHeaderField: "content-encoding")
        return urlRequest
    }

    /// Builds a POST request to the given URL. Does not set `content-encoding`;
    /// if you gzip the body, add that header yourself (see `uploadRequest()`).
    public func uploadRequest(url: URL) -> URLRequest {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("gzip", forHTTPHeaderField: "accept-encoding")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setAccountToken(accountToken)
        urlRequest.setRoverUserAgent()
        return urlRequest
    }

    public func bodyData<T>(payload: T) -> Data? where T: Encodable {
        let encoded: Data
        do {
            encoded = try JSONEncoder.default.encode(payload)
        } catch {
            os_log("Failed to encode events: %@", log: .networking, type: .error, error.logDescription)
            return nil
        }

        guard let compressed: Data = encoded.gzip() else {
            os_log("Failed to gzip events.", log: .networking, type: .error)
            return nil
        }

        return compressed
    }

    public func downloadTask(
        with request: URLRequest,
        completionHandler: @escaping (HTTPResult) -> Void
    ) -> URLSessionDataTask {
        return self.session.dataTask(with: request) { data, urlResponse, error in
            let result = HTTPResult(data: data, urlResponse: urlResponse, error: error)
            completionHandler(result)
        }
    }

    public func uploadTask(
        with request: URLRequest,
        from bodyData: Data?,
        completionHandler: @escaping (HTTPResult) -> Void
    ) -> URLSessionUploadTask {
        return self.session.uploadTask(with: request, from: bodyData) { data, urlResponse, error in
            let result = HTTPResult(data: data, urlResponse: urlResponse, error: error)
            completionHandler(result)
        }
    }

    public func download(with request: URLRequest) async -> HTTPResult {
        do {
            let (data, urlResponse) = try await self.session.data(for: request)
            return HTTPResult(data: data, urlResponse: urlResponse, error: nil)
        } catch {
            return HTTPResult(data: nil, urlResponse: nil, error: error)
        }
    }

    public func upload(with request: URLRequest, from bodyData: Data) async -> HTTPResult {
        do {
            let (data, urlResponse) = try await self.session.upload(for: request, from: bodyData)
            return HTTPResult(data: data, urlResponse: urlResponse, error: nil)
        } catch {
            return HTTPResult(data: nil, urlResponse: nil, error: error)
        }
    }
}
