//
//  GraphQLClient.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-16.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol GraphQLClient {
    func task<T>(with operation: T, completionHandler: @escaping (GraphQLResult) -> Void) -> URLSessionTask where T: GraphQLOperation
}
