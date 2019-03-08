//
//  SyncQuery.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-08-28.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public struct SyncQuery {
    public struct Argument: Equatable, Hashable {
        public var name: String
        public var type: String
        
        public init(name: String, type: String) {
            self.name = name
            self.type = type
        }
    }
    
    public var name: String
    public var body: String
    public var arguments: [Argument]
    public var fragments: [String]
    
    public init(name: String, body: String, arguments: [Argument], fragments: [String]) {
        self.name = name
        self.body = body
        self.arguments = arguments
        self.fragments = fragments
    }
}

extension SyncQuery {
    var signature: String? {
        if arguments.isEmpty {
            return nil
        }
        
        return arguments.map {
            "$\(name)\($0.name.capitalized):\($0.type)"
        }.joined(separator: ", ")
    }
    
    var definition: String {
        let expression: String = {
            if arguments.isEmpty {
                return ""
            }
            
            let signature = arguments.map {
                "\($0.name):$\(name)\($0.name.capitalized)"
            }.joined(separator: ", ")
            
            return "(\(signature))"
        }()
        
        return """
            \(name)\(expression) {
                \(body)
            }
            """
    }
}
