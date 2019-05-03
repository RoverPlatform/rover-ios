//
//  HTTPClient.swift
//  Rover
//
//  Created by Sean Rucker on 2018-09-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import os.log

public final class HTTPClient {
    public let authContextProvider: () -> AuthContext
    public let session: URLSession
    
    public init(session: URLSession, authContextProvider: @escaping () -> AuthContext) {
        self.authContextProvider = authContextProvider
        self.session = session
    }
}

extension HTTPClient {
    public func downloadRequest(queryItems: [URLQueryItem]) -> URLRequest {
        var urlComponents = URLComponents(url: authContextProvider().endpoint, resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = queryItems
        
        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("gzip", forHTTPHeaderField: "accept-encoding")
        
        setAccountToken(urlRequest: &urlRequest)
        return urlRequest
    }
    
    public func uploadRequest() -> URLRequest {
        var urlRequest = URLRequest(url: authContextProvider().endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("gzip", forHTTPHeaderField: "accept-encoding")
        urlRequest.setValue("gzip", forHTTPHeaderField: "content-encoding")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        
        setAccountToken(urlRequest: &urlRequest)
        return urlRequest
    }
    
    private func setAccountToken(urlRequest: inout URLRequest) {
        let accountToken = authContextProvider().accountToken
        assert(accountToken != nil, "Your Rover auth token has not been set.  Use Rover.accountToken = \"MY_TOKEN\".")
        urlRequest.setValue(accountToken, forHTTPHeaderField: "x-rover-account-token")
    }
    
    public func bodyData<T>(payload: T) -> Data? where T: Encodable {
        let encoded: Data
        do {
            encoded = try JSONEncoder.default.encode(payload)
        } catch {
            os_log("Failed to encode events: %@", log: .rover, type: .error, error.localizedDescription)
            return nil
        }
        
        guard let compressed: Data = encoded.gzip() else {
            os_log("Failed to gzip events.", log: .rover, type: .error)
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
