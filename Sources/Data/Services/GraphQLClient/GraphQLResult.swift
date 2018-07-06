//
//  GraphQLResult.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public enum GraphQLResult {
    case error(error: Error?, isRetryable: Bool)
    case success(data: Data)
}
