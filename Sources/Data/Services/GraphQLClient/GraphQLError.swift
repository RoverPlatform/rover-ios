//
//  GraphQLError.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

enum GraphQLError: Error {
    case emptyResponseData
    case failedToUnzipResponseData
    case invalidStatusCode(statusCode: Int)
}

extension GraphQLError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptyResponseData:
            return "Empty response data"
        case .failedToUnzipResponseData:
            return "Failed to unzip response data"
        case let .invalidStatusCode(statusCode):
            return "Invalid status code: \(statusCode)"
        }
    }
}
