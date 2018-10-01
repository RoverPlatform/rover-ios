//
//  SyncRequest.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-09.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public struct SyncRequest {
    public var query: SyncQuery
    public var variables: Attributes
    
    public init?(query: SyncQuery, values: [SyncQuery.Argument: Any]) {
        var variables = Attributes()
        for argument in query.arguments {
            // TODO: Make sure value is of type argument.style.valueType
            if let value = values[argument] as? AttributeRepresentable {
                variables[argument.name] = value
            } else if argument.isRequired {
                return nil
            }
        }
        
        self.query = query
        self.variables = variables
    }
}
