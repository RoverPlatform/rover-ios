//
//  HTTPClient.swift
//  RoverSync
//
//  Created by Sean Rucker on 2018-09-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import os.log

final class HTTPClient {
    let endpoint: URL
    let accountToken: String
    let session: URLSession
    
    init(accountToken: String, endpoint: URL, session: URLSession) {
        self.accountToken = accountToken
        self.endpoint = endpoint
        self.session = session
    }
}

extension HTTPClient {
    func downloadRequest(queryItems: [URLQueryItem]) -> URLRequest {
        var urlComponents = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = queryItems
        
        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("gzip", forHTTPHeaderField: "accept-encoding")
        urlRequest.setAccountToken(accountToken)
        return urlRequest
    }
    
    func uploadRequest() -> URLRequest {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("gzip", forHTTPHeaderField: "accept-encoding")
        urlRequest.setValue("gzip", forHTTPHeaderField: "content-encoding")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setAccountToken(accountToken)
        return urlRequest
    }
    
    func bodyData<T>(payload: T) -> Data? where T: Encodable {
        let encoded: Data
        do {
            encoded = try JSONEncoder.default.encode(payload)
        } catch {
            os_log("Failed to encode events: %@", log: .networking, type: .error, error.localizedDescription)
            return nil
        }
        
        let compressed: Data
        do {
            compressed = try encoded.gzipped()
        } catch {
            os_log("Failed to gzip events: %@", log: .networking, type: .error, error.localizedDescription)
            return nil
        }
        
        return compressed
    }
    
    func downloadTask(with request: URLRequest, completionHandler: @escaping (HTTPResult) -> Void) -> URLSessionDataTask {
        return self.session.dataTask(with: request) { data, urlResponse, error in
            let result = HTTPResult(data: data, urlResponse: urlResponse, error: error)
            completionHandler(result)
        }
    }
    
    func uploadTask(with request: URLRequest, from bodyData: Data?, completionHandler: @escaping (HTTPResult) -> Void) -> URLSessionUploadTask {
        return self.session.uploadTask(with: request, from: bodyData) { data, urlResponse, error in
            let result = HTTPResult(data: data, urlResponse: urlResponse, error: error)
            completionHandler(result)
        }
    }
}
