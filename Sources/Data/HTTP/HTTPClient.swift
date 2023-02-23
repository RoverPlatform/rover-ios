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

public final class HTTPClient {
    public let endpoint: URL
    public let accountToken: String
    public let session: URLSession
    
    public init(accountToken: String, endpoint: URL, session: URLSession) {
        self.accountToken = accountToken
        self.endpoint = endpoint
        self.session = session
    }
}

extension HTTPClient {
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
    
    public func uploadRequest() -> URLRequest {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("gzip", forHTTPHeaderField: "accept-encoding")
        urlRequest.setValue("gzip", forHTTPHeaderField: "content-encoding")
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
    
    public func downloadTask(with request: URLRequest, completionHandler: @escaping (HTTPResult) -> Void) -> URLSessionDataTask {
        return self.session.dataTask(with: request) { data, urlResponse, error in
            let result = HTTPResult(data: data, urlResponse: urlResponse, error: error)
            completionHandler(result)
        }
    }
    
    public func uploadTask(with request: URLRequest, from bodyData: Data?, completionHandler: @escaping (HTTPResult) -> Void) -> URLSessionUploadTask {
        return self.session.uploadTask(with: request, from: bodyData) { data, urlResponse, error in
            let result = HTTPResult(data: data, urlResponse: urlResponse, error: error)
            completionHandler(result)
        }
    }
}
