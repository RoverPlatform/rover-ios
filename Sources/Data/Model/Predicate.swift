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

public enum ComparisonPredicateModifier: String, Decodable, Encodable {
    case direct = "DIRECT"
    case any = "ANY"
    case all = "ALL"
}

public enum ComparisonPredicateOperator: String, Decodable, Encodable {
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

public enum CompoundPredicateLogicalType: String, Decodable, Encodable {
    case or = "OR"
    case and = "AND"
    case not = "NOT"
}

public struct ComparisonPredicate: Predicate, Decodable, Encodable {
    public private(set) var keyPath: String
    public private(set) var modifier: ComparisonPredicateModifier
    public private(set) var `operator`: ComparisonPredicateOperator
    public private(set) var numberValue: Double? = nil
    public private(set) var numberValues: [Double]? = nil
    public private(set) var stringValue: String? = nil
    public private(set) var stringValues: [String]? = nil
    public private(set) var booleanValue: Bool? = nil
    public private(set) var booleanValues: [Bool]? = nil
    public private(set) var dateTimeValue: Date? = nil
    public private(set) var dateTimeValues: [Date]? = nil
    
    enum CodingKeys: String, CodingKey {
        case keyPath
        case modifier
        case `operator`
        case numberValue
        case numberValues
        case stringValue
        case stringValues
        case booleanValue
        case booleanValues
        case dateTimeValue
        case dateTimeValues
        case typename = "__typename"
    }
    
    public init(
        keyPath: String,
        modifier: ComparisonPredicateModifier,
        `operator`: ComparisonPredicateOperator
    ) {
        self.keyPath = keyPath
        self.modifier = modifier
        self.`operator` = `operator`
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.keyPath = try container.decode(String.self, forKey: .keyPath)
        self.modifier = try container.decode(ComparisonPredicateModifier.self, forKey: .modifier)
        self.operator = try container.decode(ComparisonPredicateOperator.self, forKey: .operator)
        self.numberValue = try container.decodeIfPresent(Double.self, forKey: .numberValue)
        self.numberValues = try container.decodeIfPresent([Double].self, forKey: .numberValues)
        self.stringValue = try container.decodeIfPresent(String.self, forKey: .stringValue)
        self.stringValues = try container.decodeIfPresent([String].self, forKey: .stringValues)
        self.booleanValue = try container.decodeIfPresent(Bool.self, forKey: .booleanValue)
        self.booleanValues = try container.decodeIfPresent([Bool].self, forKey: .booleanValues)
        self.dateTimeValue = try container.decodeIfPresent(Date.self, forKey: .dateTimeValue)
        self.dateTimeValues = try container.decodeIfPresent([Date].self, forKey: .dateTimeValues)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyPath, forKey: .keyPath)
        try container.encode(modifier, forKey: .modifier)
        try container.encode(`operator`, forKey: .operator)
        try container.encode(numberValue, forKey: .numberValue)
        try container.encode(numberValues, forKey: .numberValues)
        try container.encode(stringValue, forKey: .stringValue)
        try container.encode(stringValues, forKey: .stringValues)
        try container.encode(booleanValue, forKey: .booleanValue)
        try container.encode(booleanValues, forKey: .booleanValues)
        try container.encode(dateTimeValue, forKey: .dateTimeValue)
        try container.encode(dateTimeValues, forKey: .dateTimeValues)
        try container.encode("ComparisonPredicate", forKey: .typename)
    }
}

public struct CompoundPredicate: Predicate, Decodable, Encodable {
    public private(set) var booleanOperator: CompoundPredicateLogicalType
    
    public private(set) var predicates: [Predicate]
    
    public enum CodingKeys: String, CodingKey {
        case booleanOperator
        case predicates
        case typename = "__typename"
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
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("CompoundPredicate", forKey: .typename)
        try container.encode(booleanOperator, forKey: .booleanOperator)

        var predicatesContainer = container.nestedUnkeyedContainer(forKey: .predicates)
        try self.predicates.forEach { predicate in
            switch predicate {
            case let compound as CompoundPredicate:
                try predicatesContainer.encode(compound)
            case let comparison as ComparisonPredicate:
                try predicatesContainer.encode(comparison)
            default:
                let context = EncodingError.Context(codingPath: predicatesContainer.codingPath, debugDescription: "Unexpected predicate type appeared during encode.")
                throw EncodingError.invalidValue(predicate, context)
            }
        }
    }
}
