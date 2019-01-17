//
//  Campaign.swift
//  RoverData
//
//  Created by Andrew Clunis on 2019-01-04.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import CoreData
import os

class Predicate : NSManagedObject {
    // abstract.
    
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
                throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected either ComparisonPredicate or CompoundPredicate – found \(typeName)")
            }
        }
    }
}

@objc public enum ComparisonPredicateModifier : Int, Codable {
    case direct
    case any
    case all
    
    enum CodingKeys : String, CodingKey {
        case direct
        case any
        case all
    }
}

@objc public enum ComparisonPredicateOperator : Int, Codable {
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

@objc public enum CompoundPredicateLogicalType : Int, Codable {
    case or
    case and
    case not
    
    enum CodingKeys : String, CodingKey {
        case or
        case and
        case not
    }
}

@objc public enum ComparisonPredicateValueType : Int {
    case numberValue
    case numberValues
    case stringValue
    case stringValues
    case booleanValue
    case booleanValues
    case dateTimeValue
    case dateTimeValues
}

class ComparisonPredicate: Predicate, Codable {
    @NSManaged public internal(set) var keyPath: String
    @NSManaged public internal(set) var modifier: ComparisonPredicateModifier
    @NSManaged public internal(set) var op: ComparisonPredicateOperator
    @NSManaged public internal(set) var value: NSObject // could be any of NSNumber, NSString, NSDate, or NSArrays thereof.  Booleans are also possible, but will just appear as NSNumber.
    @NSManaged public internal(set) var valueType: ComparisonPredicateValueType
    
    enum CodingKeys : String, CodingKey {
        case keyPath
        case modifier
        case op = "operator"
        case typeName = "__typename"
        
        case numberValue
        case numberValues
        case stringValue
        case stringValues
        case booleanValue
        case booleanValues
        case dateTimeValue
        case dateTimeValues
    }
    
    public required init(from decoder: Decoder) throws {
        let context = (Rover.shared?.resolve(NSManagedObjectContext.self, name: "backgroundContext"))!
        let entity = NSEntityDescription.entity(forEntityName: "ComparisonPredicate", in: context)!
        super.init(entity: entity, insertInto: context)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.keyPath = try container.decode(String.self, forKey: .keyPath)
        self.modifier = try container.decode(ComparisonPredicateModifier.self, forKey: .modifier)
        self.op = try container.decode(ComparisonPredicateOperator.self, forKey: .op)
        
        // On the GraphQL side ComparisonPredicateValue is basically a union of all possible value types, but only one may be filled in.  Those value types are all primitives OR arrays thereof.  All of those can be represented with NSObjects (NSArrays, NSNumber, etc.), all of which support NSCoding, so unlike the GraphQL side they'll work very nicely as a single field here.

        if container.contains(.numberValue) {
            self.value = NSNumber(value: try container.decode(Double.self, forKey: .numberValue))
            self.valueType = .numberValue
        } else if container.contains(.numberValues) {
            self.value = NSArray(array: try container.decode([Double].self, forKey: .numberValues).map { double in
                return NSNumber(value: double)
            })
            self.valueType = .numberValues
        } else if container.contains(.stringValue) {
            self.value = NSString(string: try container.decode(String.self, forKey: .stringValue))
            self.valueType = .stringValue
        } else if container.contains(.stringValues) {
            self.value = NSArray(array: try container.decode([String].self, forKey: .stringValues).map { string in
                return NSString(string: string)
            })
            self.valueType = .stringValues
        } else if container.contains(.booleanValue) {
            self.value = NSNumber(value: try container.decode(Bool.self, forKey: .booleanValue))
            self.valueType = .booleanValue
        } else if container.contains(.booleanValues) {
            self.value = NSArray(array: try container.decode([Bool].self, forKey: .booleanValues).map { bool in
                return BooleanValue(bool)
            })
            self.valueType = .booleanValues
        } else if container.contains(.dateTimeValue) {
            self.value = try container.decode(Date.self, forKey: .dateTimeValue) as NSDate
            self.valueType = .dateTimeValue
        } else if container.contains(.dateTimeValues) {
            self.value = NSArray(array: try container.decode([Date].self, forKey: .dateTimeValues).map { date in
                date as NSDate
            })
            self.valueType = .dateTimeValues
        } else {
            let context = DecodingError.Context(codingPath: container.codingPath, debugDescription: "Must have one of the numberValue, numberValues, stringValue, stringValues, booleanValue, booleanValues, dateTimeValue, dateTimeValues properties")
            throw DecodingError.dataCorrupted(context)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.keyPath, forKey: .keyPath)
        try container.encode(self.modifier, forKey: .modifier)
        try container.encode(self.op, forKey: .op)
        try container.encode("ComparisonPredicate", forKey: .typeName)
        
        switch valueType {
        case .numberValue:
            try container.encode((value as? NSNumber)?.doubleValue, forKey: .numberValue)
        case .numberValues:
            var arrayContainer = container.nestedUnkeyedContainer(forKey: .numberValues)
            
            guard let nsArray = self.value as? NSArray else {
                let errorContext = EncodingError.Context(codingPath: arrayContainer.codingPath, debugDescription: "dynamic `value` field was not NSArray")
                throw EncodingError.invalidValue(self.value, errorContext)
            }
            guard let asNumbers = nsArray as? [NSNumber] else {
                let errorContext = EncodingError.Context(codingPath: arrayContainer.codingPath, debugDescription: "dynamic `value` field was not array of NSNumbers")
                throw EncodingError.invalidValue(self.value, errorContext)
            }
            let asDoubles = asNumbers.map { nsNumber in
                return nsNumber.doubleValue
            }
            try arrayContainer.encode(contentsOf: asDoubles)
        case .booleanValue:
            try container.encode(value as? NSNumber != 0, forKey: .booleanValue)
        case .booleanValues:
            var arrayContainer = container.nestedUnkeyedContainer(forKey: .booleanValues)
            
            guard let nsArray = self.value as? NSArray else {
                let errorContext = EncodingError.Context(codingPath: arrayContainer.codingPath, debugDescription: "dynamic `value` field was not NSArray")
                throw EncodingError.invalidValue(self.value, errorContext)
            }
            guard let asNumbers = nsArray as? [NSNumber] else {
                let errorContext = EncodingError.Context(codingPath: arrayContainer.codingPath, debugDescription: "dynamic `value` field was not array of NSNumber for booleans.")
                throw EncodingError.invalidValue(self.value, errorContext)
            }
            let asBools = asNumbers.map { nsNumber in
                return nsNumber != 0
            }
            try arrayContainer.encode(contentsOf: asBools)
        case .dateTimeValue:
            guard let asDate = self.value as? NSDate else {
                let errorContext = EncodingError.Context(codingPath: container.codingPath, debugDescription: "dynamic `value` field was not NSDate")
                throw EncodingError.invalidValue(self.value, errorContext)
            }
            try container.encode(asDate as Date, forKey: .dateTimeValue)
        case .dateTimeValues:
            var arrayContainer = container.nestedUnkeyedContainer(forKey: .dateTimeValues)
            
            guard let nsArray = self.value as? NSArray else {
                let errorContext = EncodingError.Context(codingPath: arrayContainer.codingPath, debugDescription: "dynamic `value` field was not NSArray")
                throw EncodingError.invalidValue(self.value, errorContext)
            }
            guard let asDates = nsArray as? [NSDate] else {
                let errorContext = EncodingError.Context(codingPath: arrayContainer.codingPath, debugDescription: "dynamic `value` field was not array of NSDate")
                throw EncodingError.invalidValue(self.value, errorContext)
            }
            try arrayContainer.encode(contentsOf: asDates as [Date])
        case .stringValue:
            guard let asString = value as? NSString else {
                let errorContext = EncodingError.Context(codingPath: container.codingPath, debugDescription: "dynamic `value` field was not NSString")
                throw EncodingError.invalidValue(self.value, errorContext)
            }
            try container.encode(asString as String, forKey: .stringValue)
        case .stringValues:
            var arrayContainer = container.nestedUnkeyedContainer(forKey: .stringValues)
            
            guard let nsArray = self.value as? NSArray else {
                let errorContext = EncodingError.Context(codingPath: arrayContainer.codingPath, debugDescription: "dynamic `value` field was not NSArray")
                throw EncodingError.invalidValue(self.value, errorContext)
            }
            guard let asStrings = nsArray as? [NSString] else {
                let errorContext = EncodingError.Context(codingPath: arrayContainer.codingPath, debugDescription: "dynamic `value` field was not array of NSString")
                throw EncodingError.invalidValue(self.value, errorContext)
            }
            try arrayContainer.encode(contentsOf: asStrings as [String])
        }
    }
}

class CompoundPredicate: Predicate, Codable {
    @NSManaged public internal(set) var booleanOperator: CompoundPredicateLogicalType
    @NSManaged public internal(set) var predicates: Set<Predicate>
    
    enum CodingKeys: String, CodingKey {
        case booleanOperator
        case predicates
    }
    
    public required init(from decoder: Decoder) throws {
        let context = (Rover.shared?.resolve(NSManagedObjectContext.self, name: "backgroundContext"))!
        let entity = NSEntityDescription.entity(forEntityName: "CompoundPredicate", in: context)!
        super.init(entity: entity, insertInto: context)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.booleanOperator = try container.decode(CompoundPredicateLogicalType.self, forKey: .booleanOperator)
        // now to handle the embedded predicates:
        let predicateTypes = try container.decode([Predicate.PredicateType].self, forKey: .predicates)
        var predicatesContainer = try container.nestedUnkeyedContainer(forKey: .predicates)
        
        var loadedPredicates = [Predicate]()
        while !predicatesContainer.isAtEnd {
            switch predicateTypes[predicatesContainer.currentIndex] {
            case .compoundPredicate:
                loadedPredicates.append(try predicatesContainer.decode(CompoundPredicate.self))
            case .comparisonPredicate:
                loadedPredicates.append(try predicatesContainer.decode(ComparisonPredicate.self))
            }
        }
        
        self.predicates = Set(loadedPredicates)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(booleanOperator, forKey: .booleanOperator)
        var predicatesContainer = container.nestedUnkeyedContainer(forKey: .predicates)
        try predicates.forEach { predicate in
            switch predicate {
            case let comparison as ComparisonPredicate:
                try predicatesContainer.encode(comparison)
            case let compound as CompoundPredicate:
                try predicatesContainer.encode(compound)
            default:
                throw EncodingError.invalidValue(predicate, .init(codingPath: predicatesContainer.codingPath, debugDescription: "Unexpected predicate type appeared in a compound predicate."))
            }
        }
    }
}

@objc public enum CampaignStatus : Int, Codable {
    case draft
    case published
    case archived
}

class CampaignTrigger : NSManagedObject {
    // abstract.
    
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
                throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected either ScheduledCampaignTrigger or AutomatedCampaignTrigger – found \(typeName)")
            }
        }
    }
}

class EventTriggerFilter : NSManagedObject {
    // abstract.
    
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
                throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected one of DayOfTheWeekEventTriggerFilter, EventAttributesEventTriggerFilter, ScheduledEventTriggerFilter, or TimeOfDayEventTriggerFilter – found \(typeName)")
            }
        }
    }
}

class DayOfTheWeekEventTriggerFilter : EventTriggerFilter, Codable {
    @NSManaged public internal(set) var monday: Bool
    @NSManaged public internal(set) var tuesday: Bool
    @NSManaged public internal(set) var wednesday: Bool
    @NSManaged public internal(set) var thursday: Bool
    @NSManaged public internal(set) var friday: Bool
    @NSManaged public internal(set) var saturday: Bool
    @NSManaged public internal(set) var sunday: Bool
    
    enum CodingKeys : String, CodingKey {
        case monday
        case tuesday
        case wednesday
        case thursday
        case friday
        case saturday
        case sunday
    }

    required init(from decoder: Decoder) throws {
        let context = (Rover.shared?.resolve(NSManagedObjectContext.self, name: "backgroundContext"))!
        let entity = NSEntityDescription.entity(forEntityName: "DayOfTheWeekEventTriggerFilter", in: context)!
        super.init(entity: entity, insertInto: context)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        monday = try container.decode(Bool.self, forKey: .monday)
        tuesday = try container.decode(Bool.self, forKey: .tuesday)
        wednesday = try container.decode(Bool.self, forKey: .wednesday)
        thursday = try container.decode(Bool.self, forKey: .thursday)
        friday = try container.decode(Bool.self, forKey: .friday)
        saturday = try container.decode(Bool.self, forKey: .saturday)
        sunday = try container.decode(Bool.self, forKey: .sunday)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.monday, forKey: .monday)
        try container.encode(self.tuesday, forKey: .tuesday)
        try container.encode(self.wednesday, forKey: .wednesday)
        try container.encode(self.thursday, forKey: .thursday)
        try container.encode(self.friday, forKey: .friday)
        try container.encode(self.saturday, forKey: .saturday)
        try container.encode(self.sunday, forKey: .sunday)
    }
}

class EventAttributesEventTriggerFilter : EventTriggerFilter, Codable {
    @NSManaged public internal(set) var predicate: Predicate
    
    enum CodingKeys : String, CodingKey {
        case predicate
    }
    
    required init(from decoder: Decoder) throws {
        let context = (Rover.shared?.resolve(NSManagedObjectContext.self, name: "backgroundContext"))!
        let entity = NSEntityDescription.entity(forEntityName: "EventTriggerFilter", in: context)!
        super.init(entity: entity, insertInto: context)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(Predicate.PredicateType.self, forKey: .predicate)
        switch typeName {
        case .comparisonPredicate:
            self.predicate = try container.decode(ComparisonPredicate.self, forKey: .predicate)
        case .compoundPredicate:
            self.predicate = try container.decode(CompoundPredicate.self, forKey: .predicate)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self.predicate {
        case let comparision as ComparisonPredicate:
            try container.encode(comparision, forKey: .predicate)
        case let compound as CompoundPredicate:
            try container.encode(compound, forKey: .predicate)
        default:
            throw EncodingError.invalidValue(predicate, .init(codingPath: container.codingPath + [CodingKeys.predicate], debugDescription: "Unexpected predicate type appeared in a compound predicate."))
        }
    }
}

class DateTimeComponents: NSObject, NSCoding, Codable {
    public var date: String // 8601 date, without a time component.
    public var time: Int // count of seconds into the day (seconds past midnight)
    public var timeZone: String? // zoneinfo name of time zone.  if nil, then local device timezone shall apply.
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(date, forKey: "date")
        aCoder.encode(time, forKey: "time")
        aCoder.encode("timeZone", forKey: "timeZone")
    }
    
    required init?(coder aDecoder: NSCoder) {
        guard let dateString = aDecoder.decodeObject(forKey: "date") as? String else {
            return nil
        }
        self.date = dateString
        self.time = aDecoder.decodeInteger(forKey: "time")
        self.timeZone = aDecoder.decodeObject(forKey: "timeZone") as? String
    }
}

class ScheduledEventTriggerFilter : EventTriggerFilter, Codable {
    @NSManaged public internal(set) var startDateTime: DateTimeComponents
    @NSManaged public internal(set) var endDateTime: DateTimeComponents
    
    enum CodingKeys : String, CodingKey {
        case startDateTime
        case endDateTime
    }
    
    required init(from decoder: Decoder) throws {
        let context = (Rover.shared?.resolve(NSManagedObjectContext.self, name: "backgroundContext"))!
        let entity = NSEntityDescription.entity(forEntityName: "ScheduledEventTriggerFilter", in: context)!
        super.init(entity: entity, insertInto: context)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.startDateTime = try container.decode(DateTimeComponents.self, forKey: .startDateTime)
        self.endDateTime = try container.decode(DateTimeComponents.self, forKey: .endDateTime)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.startDateTime, forKey: .startDateTime)
        try container.encode(self.endDateTime, forKey: .endDateTime)
    }
}

class TimeOfDayEventTriggerFilter : EventTriggerFilter, Codable {
    @NSManaged public internal(set) var startTime: Int
    @NSManaged public internal(set) var endTime: Int
    
    
    enum CodingKeys : String, CodingKey {
        case startTime
        case endTime
    }
    
    required init(from decoder: Decoder) throws {
        let context = (Rover.shared?.resolve(NSManagedObjectContext.self, name: "backgroundContext"))!
        let entity = NSEntityDescription.entity(forEntityName: "TimeOfDayEventTriggerFilter", in: context)!
        super.init(entity: entity, insertInto: context)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.startTime = try container.decode(Int.self, forKey: .startTime)
        self.endTime = try container.decode(Int.self, forKey: .endTime)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.startTime, forKey: .startTime)
        try container.encode(self.endTime, forKey: .endTime)
    }
}

class EventTrigger : NSManagedObject, Codable {
    @NSManaged public internal(set) var eventName: String
    @NSManaged public internal(set) var eventNamespace: String?
    @NSManaged public internal(set) var filters: Set<EventTriggerFilter>
    
    enum CodingKeys : String, CodingKey {
        case eventName
        case eventNamespace
        case filters
    }
    
    required init(from decoder: Decoder) throws {
        let context = (Rover.shared?.resolve(NSManagedObjectContext.self, name: "backgroundContext"))!
        let entity = NSEntityDescription.entity(forEntityName: "EventTrigger", in: context)!
        super.init(entity: entity, insertInto: context)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.eventName = try container.decode(String.self, forKey: .eventName)
        self.eventNamespace = try container.decodeIfPresent(String.self, forKey: .eventNamespace)
     
        // now to handle the embedded predicates:
        let filterTypes = try container.decode([EventTriggerFilter.EventTriggerFilterType].self, forKey: .filters)
        var filtersContainer = try container.nestedUnkeyedContainer(forKey: .filters)
        
        var loadedFilters = [EventTriggerFilter]()
        while !filtersContainer.isAtEnd {
            switch filterTypes[filtersContainer.currentIndex] {
            case .dayOfTheWeek:
                loadedFilters.append(try filtersContainer.decode(DayOfTheWeekEventTriggerFilter.self))
            case .eventAttributes:
                loadedFilters.append(try filtersContainer.decode(EventAttributesEventTriggerFilter.self))
            case .scheduled:
                loadedFilters.append(try filtersContainer.decode(ScheduledEventTriggerFilter.self))
            case .timeOfDay:
                loadedFilters.append(try filtersContainer.decode(TimeOfDayEventTriggerFilter.self))
            }
        }
        
        self.filters = Set(loadedFilters)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        var filtersContainer = container.nestedUnkeyedContainer(forKey: .filters)
        try self.filters.forEach { filter in
            switch filter {
            case let dayOfWeek as DayOfTheWeekEventTriggerFilter:
                try filtersContainer.encode(dayOfWeek)
            case let eventAttributes as EventAttributesEventTriggerFilter:
                try filtersContainer.encode(eventAttributes)
            case let scheduled as ScheduledEventTriggerFilter:
                try filtersContainer.encode(scheduled)
            case let timeOfDay as TimeOfDayEventTriggerFilter:
                try filtersContainer.encode(timeOfDay)
            default:
                throw EncodingError.invalidValue(filter, .init(codingPath: filtersContainer.codingPath, debugDescription: "Unexpected filter type appeared in an EventTrigger."))
            }
        }
    }
}

class FrequencyLimit : NSManagedObject, Codable {
    @NSManaged public internal(set) var count: Int
    @NSManaged public internal(set) var interval: TimeInterval // TODO: change to int if needed, value is in seconds.
    
    enum CodingKeys: String, CodingKey {
        case count
        case interval
    }
    
    required init(from decoder: Decoder) throws {
        let context = (Rover.shared?.resolve(NSManagedObjectContext.self, name: "backgroundContext"))!
        let entity = NSEntityDescription.entity(forEntityName: "FrequencyLimit", in: context)!
        super.init(entity: entity, insertInto: context)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.count = try container.decode(Int.self, forKey: .count)
        self.interval = try container.decode(TimeInterval.self, forKey: .interval)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.count, forKey: .count)
        try container.encode(self.interval, forKey: .interval)
    }
}

class AutomatedCampaignTrigger : CampaignTrigger, Codable {
    @NSManaged public internal(set) var delay: TimeInterval // TODO: change to Int if needed.  value is in seconds.
    @NSManaged public internal(set) var eventTrigger: EventTrigger
    @NSManaged public internal(set) var limits: Set<FrequencyLimit>
    
    enum CodingKeys : String, CodingKey {
        case delay
        case eventTrigger
        case limits
    }
    
    required init(from decoder: Decoder) throws {
        let context = (Rover.shared?.resolve(NSManagedObjectContext.self, name: "backgroundContext"))!
        let entity = NSEntityDescription.entity(forEntityName: "AutomatedCampaignTrigger", in: context)!
        super.init(entity: entity, insertInto: context)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.delay = try container.decode(TimeInterval.self, forKey: .delay)
        self.eventTrigger = try container.decode(EventTrigger.self, forKey: .eventTrigger)
        self.limits = Set(try container.decode([FrequencyLimit].self, forKey: .limits))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.delay, forKey: .delay)
        try container.encode(self.eventTrigger, forKey: .eventTrigger)
        try container.encode(self.limits, forKey: .limits)
    }
}

class ScheduledCampaignTrigger : CampaignTrigger, Codable {
    @NSManaged public internal(set) var dateTime: DateTimeComponents
    
    enum CodingKeys: String, CodingKey {
        case dateTime
    }
    
    required init(from decoder: Decoder) throws {
        let context = (Rover.shared?.resolve(NSManagedObjectContext.self, name: "backgroundContext"))!
        let entity = NSEntityDescription.entity(forEntityName: "ScheduledCampaignTrigger", in: context)!
        super.init(entity: entity, insertInto: context)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dateTime = try container.decode(DateTimeComponents.self, forKey: .dateTime)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.dateTime, forKey: .dateTime)
    }
}

class CampaignDeliverable : NSManagedObject, Codable {
    @NSManaged public internal(set) var campaign: Campaign
    
    enum CodingKeys: String, CodingKey {
        case campaign
    }
    
    required init(from decoder: Decoder) throws {
        let context = (Rover.shared?.resolve(NSManagedObjectContext.self, name: "backgroundContext"))!
        let entity = NSEntityDescription.entity(forEntityName: "CampaignDeliverable", in: context)!
        super.init(entity: entity, insertInto: context)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.campaign = try container.decode(Campaign.self, forKey: .campaign)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.campaign, forKey: .campaign)
    }
}

class NotificationAlertOptions : NSObject, NSCoding, Codable {
    func encode(with aCoder: NSCoder) {
        aCoder.encode(badgeNumber, forKey: "badgeNumber")
        aCoder.encode(notificationCenter, forKey: "notificationCenter")
        aCoder.encode(systemNotification, forKey: "systemNotification")
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.badgeNumber = aDecoder.decodeBool(forKey: "badgeNumber")
        self.notificationCenter = aDecoder.decodeBool(forKey: "notificationCenter")
        self.systemNotification = aDecoder.decodeBool(forKey: "systemNotification")
    }
    
    public var badgeNumber: Bool
    public var notificationCenter: Bool
    public var systemNotification: Bool
}

public enum NotificationAttachmentType : String, Codable {
    case audio
    case image
    case video
}

class iOSNotificationOptions : NSObject, NSCoding, Codable {

    
    public var categoryIdentifier: String?
    public var contentAvailable: Bool?
    public var mutableContent: Bool?
    public var sound: String?
    public var threadIdentifier: String?
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(categoryIdentifier, forKey: "categoryIdentifier")
        aCoder.encode(contentAvailable, forKey: "contentAvailable")
        aCoder.encode(mutableContent, forKey: "mutableContent")
        aCoder.encode(sound, forKey: "sound")
        aCoder.encode(threadIdentifier, forKey: "threadIdentifier")
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.categoryIdentifier = aDecoder.decodeObject(forKey: "categoryIdentifier") as? String
        self.contentAvailable = aDecoder.decodeObject(forKey: "contentAvailable") as? Bool
        self.mutableContent = aDecoder.decodeObject(forKey: "mutableContent") as? Bool
        self.sound = aDecoder.decodeObject(forKey: "sound") as? String
        self.threadIdentifier = aDecoder.decodeObject(forKey: "threadIdentifier") as? String
    }
}

class NotificationAttachment : NSObject, NSCoding, Codable {
    public var type: NotificationAttachmentType
    public var url: URL
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(type, forKey: "type")
        aCoder.encode(url, forKey: "url")
    }
    
    required init?(coder aDecoder: NSCoder) {
        guard let type = aDecoder.decodeObject(forKey: "type") as? NotificationAttachmentType else {
            os_log("Type field missing/invalid from NotificationAttachment on nscoding restore", log: .persistence, type: .error)
            return nil
        }
        self.type = type
        guard let url = aDecoder.decodeObject(forKey: "url") as? URL else {
            os_log("URL field missing/invalid from NotificationAttachment on nscoding restore", log: .persistence, type: .error)
            return nil
        }
        self.url = url
    }
}

enum NotificationTapBehaviorType: String, Codable {
    case default_
    case openURL
    case presentExperience
    case presentWebsite
    
    enum CodingKeys: String, CodingKey {
        case default_ = "default"
        case openURL
        case presentExperience
        case presentWebsite
    }
}

class NotificationTapBehavior : NSObject, NSCoding, Codable {
    public var type: NotificationTapBehaviorType
    public var url: URL
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(type, forKey: "type")
        aCoder.encode(url, forKey: "url")
    }
    
    required init?(coder aDecoder: NSCoder) {
        guard let type = aDecoder.decodeObject(forKey: "type") as? NotificationTapBehaviorType else {
            os_log("Type field missing/invalid from NotificationTapBehaviorType on nscoding restore", log: .persistence, type: .error)
            return nil
        }
        self.type = type
        guard let url = aDecoder.decodeObject(forKey: "url") as? URL else {
            os_log("URL field missing/invalid from NotificationTapBehaviorType on nscoding restore", log: .persistence, type: .error)
            return nil
        }
        self.url = url
    }
}

class NotificationCampaignDeliverable : CampaignDeliverable {
    @NSManaged public internal(set) var alertOptions: NotificationAlertOptions
    @NSManaged public internal(set) var attachment: NotificationAttachment?
    @NSManaged public internal(set) var body: String
    @NSManaged public internal(set) var title: String?
    @NSManaged public internal(set) var iOSOptions: iOSNotificationOptions?
    @NSManaged public internal(set) var tapBehavior: NotificationTapBehavior
    
}

class Campaign : NSManagedObject, Codable {
    @NSManaged public internal(set) var id: String
    @NSManaged public internal(set) var name: String
    @NSManaged public internal(set) var status: CampaignStatus
    @NSManaged public internal(set) var createdAt: Date
    @NSManaged public internal(set) var updatedAt: Date
    
    @NSManaged public internal(set) var deliverable: CampaignDeliverable
    @NSManaged public internal(set) var trigger: CampaignTrigger
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case createdAt
        case updatedAt
        case deliverable
        case trigger
    }
    
    required init(from decoder: Decoder) throws {
        let context = (Rover.shared?.resolve(NSManagedObjectContext.self, name: "backgroundContext"))!
        let entity = NSEntityDescription.entity(forEntityName: "Campaign", in: context)!
        super.init(entity: entity, insertInto: context)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.status = try container.decode(CampaignStatus.self, forKey: .status)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.deliverable = try container.decode(CampaignDeliverable.self, forKey: .deliverable)
        
        let triggerType = try container.decode(CampaignTrigger.CampaignTriggerType.self, forKey: .trigger)
        switch triggerType {
        case .automated:
            self.trigger = try container.decode(AutomatedCampaignTrigger.self, forKey: .trigger)
        case .scheduled:
            self.trigger = try container.decode(ScheduledCampaignTrigger.self, forKey: .trigger)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self.trigger {
        case let scheduled as ScheduledCampaignTrigger:
            try container.encode(scheduled, forKey: .trigger)
        case let automated as AutomatedCampaignTrigger:
            try container.encode(automated, forKey: .trigger)
        default:
            throw EncodingError.invalidValue(self.trigger, .init(codingPath: container.codingPath + [CodingKeys.trigger], debugDescription: "Unexpected trigger type appeared in a Campaign."))
        }
    }
}
