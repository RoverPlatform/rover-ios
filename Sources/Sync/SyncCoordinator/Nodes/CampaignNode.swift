//
//  Campaign.swift
//  RoverSync
//
//  Created by Andrew Clunis on 2019-01-21.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

/// These structures represent the Campaign data coming back from the cloud-side GraphQL API for Sync.

enum CampaignStatus: String, Decodable {
    case draft = "DRAFT"
    case published = "PUBLISHED"
    case archived = "ARCHIVED"
}

protocol CampaignTrigger {
}

enum CampaignTriggerType: Decodable {
    case automated
    case scheduled
    
    enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .typeName)
        switch typeName {
        case "CampaignScheduledTrigger":
            self = .scheduled
        case "CampaignAutomatedTrigger":
            self = .automated
        default:
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected either ScheduledCampaignTrigger or AutomatedCampaignTrigger – found \(typeName)")
        }
    }
}

protocol EventTriggerFilter {
}

enum EventTriggerFilterType: Decodable {
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

struct DayOfTheWeekEventTriggerFilter: EventTriggerFilter, Decodable {
    let monday: Bool
    let tuesday: Bool
    let wednesday: Bool
    let thursday: Bool
    let friday: Bool
    let saturday: Bool
    let sunday: Bool
}

struct EventAttributesEventTriggerFilter: EventTriggerFilter, Decodable {
    let predicate: Predicate
    
    enum CodingKeys: String, CodingKey {
        case predicate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let predicateType = try container.decode(PredicateType.self, forKey: .predicate)
        switch predicateType {
        case .comparisonPredicate:
            self.predicate = try container.decode(ComparisonPredicate.self, forKey: .predicate)
        case .compoundPredicate:
            self.predicate = try container.decode(CompoundPredicate.self, forKey: .predicate)
        }
    }
}

struct DateTimeComponents: Decodable {
    let date: String
    let time: Int
    let timeZone: String?
}

struct ScheduledEventTriggerFilter: EventTriggerFilter, Decodable {
    let startDateTime: DateTimeComponents
    let endDateTime: DateTimeComponents
}

struct TimeOfDayEventTriggerFilter: EventTriggerFilter, Decodable {
    let startTime: Int
    let endTime: Int
}

struct EventTrigger: Decodable {
    let eventName: String
    let eventNamespace: String?
    let filters: [EventTriggerFilter]
    
    enum CodingKeys: String, CodingKey {
        case eventName
        case eventNamespace
        case filters
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.eventName = try container.decode(String.self, forKey: .eventName)
        self.eventNamespace = try container.decodeIfPresent(String.self, forKey: .eventNamespace)
        
        var filtersContainer = try container.nestedUnkeyedContainer(forKey: .filters)
        var typePeekContainer = filtersContainer
        var filters = [EventTriggerFilter]()
        // TODO: ANDREW START HERE AND FIGURE OUT WHY THIS FAILURE IS HAPPENING ON DECODE:
        // [Sync] Failed to decode response: keyNotFound(CodingKeys(stringValue: "predicate", intValue: nil), Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "data", intValue: nil), CodingKeys(stringValue: "campaigns", intValue: nil), CodingKeys(stringValue: "nodes", intValue: nil), _JSONKey(stringValue: "Index 0", intValue: 0), CodingKeys(stringValue: "trigger", intValue: nil), CodingKeys(stringValue: "eventTrigger", intValue: nil), _JSONKey(stringValue: "Index 0", intValue: 0)], debugDescription: "No value associated with key CodingKeys(stringValue: \"predicate\", intValue: nil) (\"predicate\").", underlyingError: nil))
        while !filtersContainer.isAtEnd {
            let filterType = try typePeekContainer.decode(EventTriggerFilterType.self)
            switch filterType {
            case .dayOfTheWeek:
                filters.append(try filtersContainer.decode(DayOfTheWeekEventTriggerFilter.self))
            case .eventAttributes:
                filters.append(try filtersContainer.decode(EventAttributesEventTriggerFilter.self))
            case .scheduled:
                filters.append(try filtersContainer.decode(EventAttributesEventTriggerFilter.self))
            case .timeOfDay:
                filters.append(try filtersContainer.decode(TimeOfDayEventTriggerFilter.self))
            }
        }
        self.filters = filters
    }
}

struct FrequencyLimit: Decodable {
    let count: Int
    let interval: TimeInterval
}

struct Segment: Decodable {
    // The GraphQL API types themselves are actually unions of several possible segment type, themeselves categorized for each trigger type.  Besides being difficult to represent directly in Swift, the extra type information is unnecessary. All of the Segment types we care about do nothing more than contain a predicate.

    let predicate: Predicate
    
    enum CodingKeys: String, CodingKey {
        case predicate
        case typename = "__typename"
    }
    
    init(from decoder: Decoder) throws {
        // do a manual decode so we can verify __typename
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let typeName = try container.decode(String.self, forKey: .typename)

        if typeName == "CompoundSegment" {
            throw DecodingError.dataCorruptedError(forKey: .typename, in: container, debugDescription: "Legacy CompoundSegment appeared, which is not supported by SDK 3.  These will soon be migrated away in the Rover Cloud API.")
        }
        
        let predicateType = try container.decode(PredicateType.self, forKey: .predicate)
        switch predicateType {
        case .comparisonPredicate:
            self.predicate = try container.decode(ComparisonPredicate.self, forKey: .predicate)
        case .compoundPredicate:
            self.predicate = try container.decode(CompoundPredicate.self, forKey: .predicate)
        }
    }
}

struct CampaignAutomatedTrigger: CampaignTrigger, Decodable {
    let delay: DelayTimeComponent
    let eventTrigger: EventTrigger
    let limits: [FrequencyLimit]
    let segment: Segment?
}

enum DelayUnit: String, Decodable {
    case seconds = "s"
    case minutes = "m"
    case hours = "h"
    case days = "d"
}

struct DelayTimeComponent: Decodable {
    let unit: DelayUnit
    let value: Int
}

struct CampaignScheduledTrigger: CampaignTrigger, Decodable {
    let dateTime: DateTimeComponents?
    let segment: Segment?
}

protocol CampaignDeliverable {
}

enum CampaignDeliverableType: Decodable {
    case notification
    
    enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .typeName)
        switch typeName {
        case "CampaignNotificationDeliverable":
            self = .notification
        default:
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected CampaignNotificationDeliverable – found \(typeName)")
        }
    }
}

struct NotificationAlertOptions: Decodable {
    let badgeNumber: Bool
    let notificationCenter: Bool
    let systemNotification: Bool
}

enum NotificationAttachmentType: String, Decodable {
    case audio = "AUDIO"
    case image = "IMAGE"
    case video = "VIDEO"
}

// iOS name is typically considered an exception to this rule, so silence the type name format warning.
// swiftlint:disable:next type_name
struct iOSNotificationOptions: Decodable {
    let categoryIdentifier: String?
    let contentAvailable: Bool?
    let mutableContent: Bool?
    let sound: String?
    let threadIdentifier: String?
}

struct NotificationAttachment: Decodable {
    let type: NotificationAttachmentType
    let url: URL
}

enum NotificationTapBehaviorType: String, Codable {
    case default_ = "DEFAULT"
    case openURL = "OPEN_URL"
    case presentExperience = "PRESENT_EXPERIENCE"
    case presentWebsite = "PRESENT_WEBSITE"
}

struct NotificationTapBehavior: Decodable {
    let type: NotificationTapBehaviorType
    let url: URL
}

struct CampaignNotificationDeliverable: CampaignDeliverable, Decodable {
    let alertOptions: NotificationAlertOptions
    let attachment: NotificationAttachment?
    let body: String
    let title: String?
    let iOSOptions: iOSNotificationOptions?
    let tapBehavior: NotificationTapBehavior
}

struct CampaignNode: Decodable {
    let id: String
    let name: String
    let status: CampaignStatus
    let createdAt: Date
    let updatedAt: Date
    let deliverable: CampaignDeliverable
    let trigger: CampaignTrigger
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case createdAt
        case updatedAt
        case deliverable
        case trigger
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.status = try container.decode(CampaignStatus.self, forKey: .status)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        
        let deliverableType = try container.decode(CampaignDeliverableType.self, forKey: .deliverable)
        switch deliverableType {
        case .notification:
            self.deliverable = try container.decode(CampaignNotificationDeliverable.self, forKey: .deliverable)
        }
        
        let triggerType = try container.decode(CampaignTriggerType.self, forKey: .trigger)
        switch triggerType {
        case .automated:
            self.trigger = try container.decode(CampaignAutomatedTrigger.self, forKey: .trigger)
        case .scheduled:
            self.trigger = try container.decode(CampaignScheduledTrigger.self, forKey: .trigger)
        }
    }
}
