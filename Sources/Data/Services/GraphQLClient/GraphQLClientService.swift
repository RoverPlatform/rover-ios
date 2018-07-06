//
//  GraphQLClientService.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

class GraphQLClientService: GraphQLClient {
    let accountToken: String
    let endpoint: URL
    let session: URLSessionProtocol
    
    init(accountToken: String, endpoint: URL, session: URLSessionProtocol) {
        self.accountToken = accountToken
        self.endpoint = endpoint
        self.session = session
    }
    
    func task<T>(with operation: T, completionHandler: @escaping (GraphQLResult) -> Void) -> URLSessionTask where T: GraphQLOperation {
        switch operation.operationType {
        case .query:
            return downloadTask(with: operation, completionHandler: completionHandler) as! URLSessionTask
        case .mutation:
            return uploadTask(with: operation, completionHandler: completionHandler) as! URLSessionTask
        }
    }
    
    func downloadTask<T>(with operation: T, completionHandler: @escaping (GraphQLResult) -> Void) -> URLSessionTaskProtocol where T: GraphQLOperation {
        let url = endpointWithURLEncodedOperation(operation)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("gzip", forHTTPHeaderField: "accept-encoding")
        
        addAccountToken(to: &urlRequest)
        
        return session.downloadTask(with: urlRequest, completionHandler: { (data, urlResponse, error) in
            let result = self.graphQLResult(from: data, urlResponse: urlResponse, error: error)
            completionHandler(result)
        })
    }
    
    func uploadTask<T>(with operation: T, completionHandler: @escaping (GraphQLResult) -> Void) -> URLSessionTaskProtocol where T: GraphQLOperation {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("gzip", forHTTPHeaderField: "accept-encoding")
        urlRequest.setValue("gzip", forHTTPHeaderField: "content-encoding")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        
        addAccountToken(to: &urlRequest)
        
        let bodyData = gzip(operation)
        return session.uploadTask(with: urlRequest, from: bodyData, completionHandler: { (data, urlResponse, error) in
            let result = self.graphQLResult(from: data, urlResponse: urlResponse, error: error)
            completionHandler(result)
        })
    }
    
    /**
     * Encode an operation's variables into URL query params and append to the endpoint.
     */
    func endpointWithURLEncodedOperation<T>(_ operation: T) -> URL where T: GraphQLOperation {
        guard var urlComponents = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            return endpoint
        }
        
        let condensed = operation.query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "query", value: condensed)
        ]
        
        if let variables = operation.variables, let encoded = encode(variables) {
            let value = String(data: encoded, encoding: .utf8)
            let queryItem = URLQueryItem(name: "variables", value: value)
            queryItems.append(queryItem)
        }
        
        if let fragments = operation.fragments, let encoded = encode(fragments) {
            let value = String(data: encoded, encoding: .utf8)
            let queryItem = URLQueryItem(name: "fragments", value: value)
            queryItems.append(queryItem)
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            return endpoint
        }
        
        return url
    }
    
    /**
     * GZIPs a payload.
     */
    func gzip<T>(_ payload: T) -> Data? where T: Encodable {
        guard let encoded = encode(payload) else {
            return nil
        }
        
        return try? encoded.gzipped()
    }
    
    /**
     * JSON Encodes a payload.
     */
    func encode<T>(_ payload: T) -> Data? where T: Encodable {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(payload)
    }
    
    /**
     * Add the x-rover-account-token header to the request.
     */
    func addAccountToken(to urlRequest: inout URLRequest) {
        urlRequest.setValue(accountToken, forHTTPHeaderField: "x-rover-account-token")
    }
    
    /**
     * Convert a response from a URLSessionTask completionHandler into an GraphQLResult.
     */
    func graphQLResult(from data: Data?, urlResponse: URLResponse?, error: Error?) -> GraphQLResult {
        if let error = error {
            return .error(error: error, isRetryable: true)
        }
        
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            return .error(error: error, isRetryable: true)
        }
        
        if httpResponse.statusCode != 200 {
            let error = GraphQLError.invalidStatusCode(statusCode: httpResponse.statusCode)
            return .error(error: error, isRetryable: false)
        }
        
        guard var data = data else {
            return .error(error: GraphQLError.emptyResponseData, isRetryable: true)
        }
        
        if data.isGzipped {
            do {
                try data = data.gunzipped()
            } catch {
                return .error(error: GraphQLError.failedToUnzipResponseData, isRetryable: true)
            }
        }
        
        return .success(data: data)
    }
}
