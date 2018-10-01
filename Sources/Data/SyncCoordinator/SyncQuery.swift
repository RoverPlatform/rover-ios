//
//  SyncQuery.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-08-28.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public struct SyncQuery {
    public struct Argument: Equatable, Hashable {
        public enum Style: Equatable, Hashable {
            case int
            case float
            case string
            case boolean
            case id
        }
        
        public var name: String
        public var style: Style
        public var isRequired: Bool
        
        public init(name: String, style: Style, isRequired: Bool) {
            self.name = name
            self.style = style
            self.isRequired = isRequired
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
        
        return arguments.map({
            "$\(name)\($0.name.capitalized):\($0.typeDescriptor)"
        }).joined(separator: ", ")
    }
    
    var definition: String {
        let expression: String = {
            if arguments.isEmpty {
                return ""
            }
            
            let signature = arguments.map({
                "\($0.name):$\(name)\($0.name.capitalized)"
            }).joined(separator: ", ")
            
            return "(\(signature))"
        }()
        
        return """
            \(name)\(expression) {
                \(body)
            }
            """
    }
}

// MARK: SyncQuery.Argument

extension SyncQuery.Argument {
    public static var first: SyncQuery.Argument {
        return SyncQuery.Argument(name: "first", style: .int, isRequired: true)
    }
    
    public static var after: SyncQuery.Argument {
        return SyncQuery.Argument(name: "after", style: .string, isRequired: false)
    }
    
    public static var last: SyncQuery.Argument {
        return SyncQuery.Argument(name: "last", style: .int, isRequired: true)
    }
    
    public static var before: SyncQuery.Argument {
        return SyncQuery.Argument(name: "before", style: .string, isRequired: false)
    }
    
    public static var pagingArguments: [SyncQuery.Argument] {
        return [SyncQuery.Argument.first, SyncQuery.Argument.after]
    }
    
    public var typeDescriptor: String {
        var typeDescriptor = self.style.typeDescriptor
        
        if self.isRequired {
            typeDescriptor = "\(typeDescriptor)!"
        }
        
        return typeDescriptor
    }
}

// MARK: SyncQuery.Argument.Style

extension SyncQuery.Argument.Style {
    public var typeDescriptor: String {
        switch self {
        case .int:
            return "Int"
        case .float:
            return "Float"
        case .string:
            return "String"
        case .boolean:
            return "Boolean"
        case .id:
            return "ID"
        }
    }
    
    public var valueType: Any.Type {
        switch self {
        case .int:
            return Int.self
        case .float:
            return Double.self
        case .string:
            return String.self
        case .boolean:
            return Bool.self
        case .id:
            return ID.self
        }
    }
}
