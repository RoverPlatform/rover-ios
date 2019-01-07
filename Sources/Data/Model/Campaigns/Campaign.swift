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

@objc public enum ComparisonPredicateModifier : Int {
    case direct
    case any
    case all
    
    // TODO: Codable.
}

@objc public enum ComparisonPredicateOperator : Int {
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
    
    // TODO: Codable
}

@objc public enum CompoundPredicateLogicalType : Int {
    case or
    case and
    case not
    
    // TODO: Codable
}

class ComparisonPredicate: Predicate {
    @NSManaged public internal(set) var keyPath: String
    @NSManaged public internal(set) var modifier: ComparisonPredicateModifier
    @NSManaged public internal(set) var op: ComparisonPredicateOperator
    @NSManaged public internal(set) var value: NSObject // could be any of Float, String, DateTime, Number, or NSArrays thereof.  Booleans are also possible, but will just appear as Number.
    
    // TODO: Codable
    
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

