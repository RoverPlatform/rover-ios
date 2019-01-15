//
//  Campaign.swift
//  RoverData
//
//  Created by Andrew Clunis on 2019-01-04.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import CoreData

class Predicate : NSManagedObject {
    // abstract.
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
    @NSManaged public internal(set) var value: NSObject // could be any of NSNumber, NSString, NSDate, or NSArrays thereof.  Booleans are also possible, but will just appear as Number. TODO maybe need to use same arrangement for booleans as we did with Attributes.
    @NSManaged public internal(set) var valueType: ComparisonPredicateValueType
    
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
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.keyPath = try container.decode(String.self, forKey: .keyPath)
        self.modifier = try container.decode(ComparisonPredicateModifier.self, forKey: .modifier)
        self.op = try container.decode(ComparisonPredicateOperator.self, forKey: .op)
        
        // On the GraphQL side ComparisonPredicateValue is basically a union of all possible value types, but only one may be filled in.  Those value types are all primitives OR arrays thereof.  All of those can be represented with NSObjects (NSArrays, NSNumber, etc.), all of which support NSCoding, so unlike the GraphQL side they'll work very nicely as a single field here.

        if container.contains(.numberValue) {
            self.value = NSNumber(value: try container.decode(Double.self, forKey: .numberValue))
            self.valueType = .numberValue
        } else if container.contains(.numberValues) {
            self.value = NSArray(array: try container.decode([Double].self, forKey: .numberValues).map({ double in
                return NSNumber(value: double)
            }))
            self.valueType = .numberValues
        } else if container.contains(.stringValue) {
            self.value = NSString(string: try container.decode(String.self, forKey: .stringValue))
            self.valueType = .stringValue
        } else if container.contains(.stringValues) {
            self.value = NSArray(array: try container.decode([String].self, forKey: .stringValues).map({ string in
                return NSString(string: string)
            }))
            self.valueType = .stringValues
        } else if container.contains(.booleanValue) {
            self.value = NSNumber(value: try container.decode(Bool.self, forKey: .booleanValue))
            self.valueType = .booleanValue
        } else if container.contains(.booleanValues) {
            self.value = NSArray(array: try container.decode([Bool].self, forKey: .booleanValues).map({ bool in
                return BooleanValue(bool)
            }))
        } else if container.contains(.dateTimeValue) {
            self.value = try container.decode(Date.self, forKey: .dateTimeValue) as NSDate
            self.valueType = .dateTimeValue
        } else if container.contains(.dateTimeValues) {
            self.value = NSArray(array: try container.decode([Date].self, forKey: .dateTimeValues).map({ date in
                date as NSDate
            }))
            self.valueType = .dateTimeValues
        } else {
            let context = DecodingError.Context(codingPath: [], debugDescription: "Missing one of numberValue, numberValues, stringValue, stringValues, booleanValue, booleanValues, dateTimeValue, dateTimeValues")
            throw DecodingError.dataCorrupted(context)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.keyPath, forKey: .keyPath)
        try container.encode(self.modifier, forKey: .modifier)
        try container.encode(self.op, forKey: .op)
        
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

class CompoundPredicate: Predicate {
    @NSManaged public internal(set) var booleanOperator: CompoundPredicateLogicalType
    @NSManaged public internal(set) var predicates: Set<Predicate>
    
    // TODO: Codable
}

@objc public enum CampaignStatus : Int {
    case draft
    case published
    case archived
    
    // TODO: Codable.
}

class CampaignTrigger : NSManagedObject {
    // abstract.
    @NSManaged public internal(set) var campaign: Campaign
}

class EventTriggerFilter : NSManagedObject {
    // abstract.
}

class DayOfTheWeekEventTriggerFilter : NSManagedObject, Codable {
    @NSManaged public internal(set) var monday: Bool
    @NSManaged public internal(set) var tuesday: Bool
    @NSManaged public internal(set) var wednesday: Bool
    @NSManaged public internal(set) var thursday: Bool
    @NSManaged public internal(set) var friday: Bool
    @NSManaged public internal(set) var saturday: Bool
    @NSManaged public internal(set) var sunday: Bool
    
    // TODO: Codable.
}

class EventAttributesEventTriggerFilter : NSManagedObject {
    @NSManaged public internal(set) var predicate: Predicate
    
    // TODO: codable.
}

class DateTimeComponents: NSObject, NSCoding {
    public var date: String // 8601 ?? note that it is a DATE and not a moment in time.
    public var time: Int // count of seconds into the day (seconds past midnight)
    public var timeZone: String? // zoneinfo name of time zone.  if nil, then local device timezone shall apply.
    
    // TODO: Codable, NSCoding.
}

class ScheduledEventTriggerFilter : NSManagedObject {
    @NSManaged public internal(set) var startDateTime: DateTimeComponents
    @NSManaged public internal(set) var endDateTime: DateTimeComponents
    
    // TODO: Codable.
}

class TimeOfDayEventTriggerFilter : NSManagedObject {
    @NSManaged public internal(set) var startTime: Int
    @NSManaged public internal(set) var endTime: Int
    
    // TODO: Codable.
}

class EventTrigger : NSManagedObject {
    @NSManaged public internal(set) var eventName: String
    @NSManaged public internal(set) var eventNamespace: String?
    @NSManaged public internal(set) var filters: Set<EventTriggerFilter>
    
    // TODO: Codable.
}

class FrequencyLimit : NSManagedObject {
    @NSManaged public internal(set) var count: Int
    @NSManaged public internal(set) var interval: TimeInterval // TODO: change to int if needed, value is in seconds.
    
    // TODO: Codable.
}

class AutomatedCampaignTrigger : CampaignTrigger {
    @NSManaged public internal(set) var delay: TimeInterval // TODO: change to Int if needed.  value is in seconds.
    @NSManaged public internal(set) var eventTrigger: EventTrigger
    @NSManaged public internal(set) var limits: Set<FrequencyLimit>
    
    // TODO: Codable.
}

class CampaignDeliverable : NSManagedObject {
    @NSManaged public internal(set) var campaign: Campaign
    
    // TODO: Codable.
}

class NotificationAlertOptions : NSObject, NSCoding {
    public var badgeNumber: Bool
    public var notificationCenter: Bool
    public var systemNotification: Bool
    
    // TODO: Codable & NSCoding
}

public enum NotificationAttachmentType : String, Codable {
    case audio
    case image
    case video
    
    // this is used in an NSCoding value object, which needs its own handwritten NSCoding implementation, so can I get away with having it just be pure swift and not @objc.
}

class iOSNotificationOptions : NSObject, NSCoding {
    public var categoryIdentifier: String?
    public var contentAvailable: Bool?
    public var mutableContent: Bool?
    public var sound: String?
    public var threadIdentifier: String?
    
    // TODO: Codable and NSCoding.
}

class NotificationAttachment : NSObject, NSCoding {
    public var type: NotificationAttachmentType
    public var url: URL
    
    // TODO: Codable and NSCoding.
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
    
    // TODO: Codable and NSCoding.
}

class NotificationTapBehavior : NSObject, NSCoding {
    public var type: NotificationTapBehaviorType
    public var url: URL
    
    // TODO: Codable and NSCoding.
}

class NotificationCampaignDeliverable : CampaignDeliverable {
    @NSManaged public internal(set) var alertOptions: NotificationAlertOptions
    @NSManaged public internal(set) var attachment: NotificationAttachment?
    @NSManaged public internal(set) var body: String
    @NSManaged public internal(set) var title: String?
    @NSManaged public internal(set) var iOSOptions: iOSNotificationOptions?
    @NSManaged public internal(set) var tapBehavior: NotificationTapBehavior
    
    // TODO: Codable
}

class Campaign : NSManagedObject {
    @NSManaged public internal(set) var id: String
    @NSManaged public internal(set) var name: String
    @NSManaged public internal(set) var status: CampaignStatus
    @NSManaged public internal(set) var createdAt: Date
    @NSManaged public internal(set) var updatedAt: Date
    
    @NSManaged public internal(set) var deliverable: CampaignDeliverable
    @NSManaged public internal(set) var trigger: CampaignTrigger
    
    // TODO: Codable.
}

