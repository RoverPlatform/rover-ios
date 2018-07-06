//
//  GraphQLOperation.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//


public protocol GraphQLOperation: Encodable {
    associatedtype Variables: Encodable
    
    var operationType: GraphQLOperationType { get }
    var query: String { get }
    var variables: Variables? { get }
    var fragments: [String]? { get }
}

fileprivate enum CodingKeys: String, CodingKey {
    case query
    case variables
    case fragments
}

extension GraphQLOperation {
    public var operationType: GraphQLOperationType {
        return .query
    }
    
    public var variables: Attributes? {
        return nil
    }
    
    public var fragments: [String]? {
        return nil
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(query, forKey: .query)
        
        if let variables = variables {
            try container.encode(variables, forKey: .variables)
        }
        
        if let fragments = fragments {
            try container.encode(fragments, forKey: .fragments)
        }
    }
}
