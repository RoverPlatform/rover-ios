//
//  Predicate.swift
//  RoverData
//
//  Created by Andrew Clunis on 2019-02-12.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

/// Rover's Representation of a Predicate, directly inspired by (and compatible with) the Apple platform's NSPredicate.
public protocol Predicate {
}

/// Used to discriminate between Predicate types arriving back from GraphQL.
public enum PredicateType: Decodable {
    case comparisonPredicate
    case compoundPredicate
    
    enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .typeName)
        switch typeName {
        case "ComparisonPredicate":
            self = .comparisonPredicate
        case "CompoundPredicate":
            self = .compoundPredicate
        default:
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected either ComparisonPredicate or CompoundPredicate – found \(typeName)")
        }
    }
}

public enum ComparisonPredicateModifier: String, Decodable {
    case direct = "DIRECT"
    case any = "ANY"
    case all = "ALL"
}

public enum ComparisonPredicateOperator: String, Decodable {
    case lessThan = "LESS_THAN"
    case lessThanOrEqualTo = "LESS_THAN_OR_EQUAL_TO"
    case greaterThan = "GREATER_THAN"
    case greaterThanOrEqualTo = "GREATER_THAN_OR_EQUAL_TO"
    case equalTo = "EQUAL_TO"
    case notEqualTo = "NOT_EQUAL_TO"
    case like = "LIKE"
    case beginsWith = "BEGINS_WITH"
    case endsWith = "ENDS_WITH"
    case `in` = "IN"
    case contains = "CONTAINS"
    case between = "BETWEEN"
    case geoWithin = "GEO_WITHIN"
}

public enum CompoundPredicateLogicalType: String, Decodable {
    case or = "OR"
    case and = "AND"
    case not = "NOT"
}

public struct ComparisonPredicate: Predicate, Decodable {
    public let keyPath: String
    public let modifier: ComparisonPredicateModifier
    public let `operator`: ComparisonPredicateOperator
    public let numberValue: Double? = nil
    public let numberValues: [Double]? = nil
    public let stringValue: String? = nil
    public let stringValues: [String]? = nil
    public let booleanValue: Bool? = nil
    public let booleanValues: [Bool]? = nil
    public let dateTimeValue: Date? = nil
    public let dateTimeValues: [Date]? = nil
    
    public init(
        keyPath: String,
        modifier: ComparisonPredicateModifier,
        `operator`: ComparisonPredicateOperator
    ) {
        self.keyPath = keyPath
        self.modifier = modifier
        self.`operator` = `operator`
    }
}

public struct CompoundPredicate: Predicate, Decodable {
    public let booleanOperator: CompoundPredicateLogicalType
    
    public let predicates: [Predicate]
    
    public enum CodingKeys: String, CodingKey {
        case booleanOperator
        case predicates
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.booleanOperator = try container.decode(CompoundPredicateLogicalType.self, forKey: .booleanOperator)
        
        var predicatesContainer = try container.nestedUnkeyedContainer(forKey: .predicates)
        var typePeekContainer = predicatesContainer
        var predicates = [Predicate]()
        while !predicatesContainer.isAtEnd {
            let predicateType = try typePeekContainer.decode(PredicateType.self)
            switch predicateType {
            case .comparisonPredicate:
                predicates.append(try predicatesContainer.decode(ComparisonPredicate.self))
            case .compoundPredicate:
                predicates.append(try predicatesContainer.decode(CompoundPredicate.self))
            }
        }
        self.predicates = predicates
    }
}
