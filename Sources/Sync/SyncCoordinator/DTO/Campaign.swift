//
//  Campaign.swift
//  RoverSync
//
//  Created by Andrew Clunis on 2019-01-21.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation


enum PredicateType : Decodable {
    case comparisonPredicate
    case compoundPredicate

    enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
    }

    init(from decoder: Decoder) throws {
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


enum ComparisonPredicateModifier : String, Codable {
    case direct
    case any
    case all
}

enum ComparisonPredicateOperator : String, Codable {
    case lessThan
    case lessThanOrEqualTo
    case greaterThan
    case greaterThanOrEqualTo
    case equalTo
    case notEqualTo
    case like
    case beginsWith
    case endsWith
    case in_
    case contains
    case between
    case geoWithin

    enum CodingKeys : String, CodingKey {
        case lessThan
        case lessThanOrEqualTo
        case greaterThan
        case greaterThanOrEqualTo
        case equalTo
        case notEqualTo
        case like
        case beginsWith
        case endsWith
        case in_ = "in"
        case contains
        case between
        case geoWithin
    }
}

enum CompoundPredicateLogicalType : String, Codable {
    case or
    case and
    case not
}

struct ComparisonPredicate : Decodable {
    let keyPath: String
    let modifier: ComparisonPredicateModifier
    let op: ComparisonPredicateModifier
    let numberValue: Double? = nil
    let numberValues: [Double]? = nil
    let stringValue: String? = nil
    let stringValues: [String]? = nil
    let booleanValue: Bool? = nil
    let booleanValues: [Bool]? = nil
    let dateTimeValue: Date? = nil
    let dateTimeValues: [Date]? = nil
    
    enum CodingKeys : String, CodingKey {
        case keyPath
        case modifier
        case op = "operator"
        case numberValue
        case numberValues
        case stringValue
        case stringValues
        case booleanValue
        case booleanValues
        case dateTimeValue
        case dateTimeValues
    }
}

struct CompoundPredicate : Codable {
    // TODO: ANDREW START HERE and continue plugging in pure-swift/decodable versions of the Campaign types.
    
    // https://github.com/RoverPlatform/rover-ios/blob/0839c6f4de891219ce199a39ed4a35ce4933cdcb/Sources/Data/Model/Campaigns/Campaign.swift
}
