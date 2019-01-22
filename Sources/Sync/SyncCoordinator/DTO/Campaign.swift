//
//  Campaign.swift
//  RoverSync
//
//  Created by Andrew Clunis on 2019-01-21.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

protocol Predicate {
    
}

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

enum ComparisonPredicateModifier : String, Decodable {
    case direct
    case any
    case all
}

enum ComparisonPredicateOperator : String, Decodable {
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

enum CompoundPredicateLogicalType : String, Decodable {
    case or
    case and
    case not
}

struct ComparisonPredicate : Predicate, Decodable {
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

struct CompoundPredicate : Predicate, Decodable {
    // https://github.com/RoverPlatform/rover-ios/blob/0839c6f4de891219ce199a39ed4a35ce4933cdcb/Sources/Data/Model/Campaigns/Campaign.swift
    
    let booleanOperator: CompoundPredicateLogicalType
    
    let predicates: [Predicate]
    
    enum CodingKeys: String, CodingKey {
        case booleanOperator
        case predicates
    }
    
    init(from decoder: Decoder) throws {

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

extension Predicate  {
    // I may not use this because the unkeyed counterpart was a total fail.
    static func decodeFrom<C: CodingKey>(container: KeyedDecodingContainer<C>, forKey key: C) throws -> Predicate {
        let predicateType = try container.decode(PredicateType.self, forKey: key)
        switch predicateType {
        case .comparisonPredicate:
            return try container.decode(ComparisonPredicate.self, forKey: key)
        case .compoundPredicate:
            return try container.decode(CompoundPredicate.self, forKey: key)
        }
    }
}

enum CampaignStatus : String, Decodable {
    case draft
    case published
    case archived
}

protocol CampaignTrigger {
    
}

enum CampaignTriggerType : Decodable {
    case automated
    case scheduled
    
    enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .typeName)
        switch typeName {
        case "ScheduledCampaignTrigger":
            self = .scheduled
        case "AutomatedCampaignTrigger":
            self = .automated
        default:
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected either ScheduledCampaignTrigger or AutomatedCampaignTrigger – found \(typeName)")
        }
    }
}

protocol EventTriggerFilter {
}

enum EventTriggerFilterType : Decodable {
    case dayOfTheWeek
    case eventAttributes
    case scheduled
    case timeOfDay
    
    enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .typeName)
        switch typeName {
        case "DayOfTheWeekEventTriggerFilter":
            self = .dayOfTheWeek
        case "EventAttributesEventTriggerFilter":
            self = .eventAttributes
        case "ScheduledEventTriggerFilter":
            self = .scheduled
        case "TimeOfDayEventTriggerFilter":
            self = .timeOfDay
        default:
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected one of DayOfTheWeekEventTriggerFilter, EventAttributesEventTriggerFilter, ScheduledEventTriggerFilter, or TimeOfDayEventTriggerFilter – found \(typeName)")
        }
    }
}

// START HERE WITH DayOfTheWeekEventTriggerFilter
