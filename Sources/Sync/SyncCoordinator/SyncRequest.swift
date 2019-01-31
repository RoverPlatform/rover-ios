//
//  SyncRequest.swift
//  RoverSync
//
//  Created by Sean Rucker on 2018-09-09.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public struct SyncRequest {
    public var query: SyncQuery
    public var variables: Attributes
    
    // TODO change this to Attributes?
    public init(query: SyncQuery, values: [String: Any]) {
        self.query = query
        variables = query.arguments.reduce(into: Attributes(), { (result, argument) in
            result.rawValue[argument.name] = values[argument.name]
        })
    }
}
