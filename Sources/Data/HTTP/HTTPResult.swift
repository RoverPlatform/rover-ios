//
//  HTTPResult.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public enum HTTPResult {
    case error(error: Error?, isRetryable: Bool)
    case success(data: Data)
}

extension HTTPResult {
    init(data: Data?, urlResponse: URLResponse?, error: Error?) {
        if let error = error {
            self = .error(error: error, isRetryable: true)
            return
        }
        
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            self = .error(error: error, isRetryable: true)
            return
        }
        
        if httpResponse.statusCode != 200 {
            let error = HTTPError.invalidStatusCode(statusCode: httpResponse.statusCode)
            self = .error(error: error, isRetryable: false)
            return
        }
        
        guard var data = data else {
            self = .error(error: HTTPError.emptyResponseData, isRetryable: true)
            return
        }
        
        if data.isGzipped {
            do {
                try data = data.gunzipped()
            } catch {
                self = .error(error: HTTPError.failedToUnzipResponseData, isRetryable: true)
                return
            }
        }
        
        self = .success(data: data)
    }
}
