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
    
    public init(query: SyncQuery, values: [String: AttributeRepresentable]) {
        self.query = query
        self.variables = query.arguments.reduce(into: Attributes(), { (result, argument) in
            result[argument.name] = values[argument.name]
        })
    }
}
