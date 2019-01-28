//
//  Campaign.swift
//  RoverSync
//
//  Created by Andrew Clunis on 2019-01-21.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

/// These structures represent the Campaign data coming back from the cloud-side GraphQL API for Sync.

protocol Predicate {

}

enum PredicateType: Decodable {
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

enum ComparisonPredicateModifier: String, Decodable {
    case direct = "DIRECT"
    case any = "ANY"
    case all = "ALL"
}

enum ComparisonPredicateOperator: String, Decodable {
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

enum CompoundPredicateLogicalType: String, Decodable {
    case or = "OR"
    case and = "AND"
    case not = "NOT"
}

struct ComparisonPredicate: Predicate, Decodable {
    let keyPath: String
    let modifier: ComparisonPredicateModifier
    let `operator`: ComparisonPredicateOperator
    let numberValue: Double? = nil
    let numberValues: [Double]? = nil
    let stringValue: String? = nil
    let stringValues: [String]? = nil
    let booleanValue: Bool? = nil
    let booleanValues: [Bool]? = nil
    let dateTimeValue: Date? = nil
    let dateTimeValues: [Date]? = nil
}

struct CompoundPredicate: Predicate, Decodable {
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

struct AutomatedCampaignTrigger: CampaignTrigger, Decodable {
    let delay: TimeInterval
    let eventTrigger: EventTrigger
    let limits: [FrequencyLimit]
}

struct ScheduledCampaignTrigger: CampaignTrigger, Decodable {
    let dateTime: DateTimeComponents
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
        case "NotificationCampaignDeliverable":
            self = .notification
        default:
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.typeName, in: container, debugDescription: "Expected NotificationCampaignDeliverable – found \(typeName)")
        }
    }
}

struct NotificationAlertOptions: Decodable {
    let badgeNumber: Bool
    let notificationCenter: Bool
    let systemNotification: Bool
}

enum NotificationAttachmentType: String, Decodable {
    case audio
    case image
    case video
}

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

struct NotificationCampaignDeliverable: CampaignDeliverable, Decodable {
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
            self.deliverable = try container.decode(NotificationCampaignDeliverable.self, forKey: .deliverable)
        }

        let triggerType = try container.decode(CampaignTriggerType.self, forKey: .trigger)
        switch triggerType {
        case .automated:
            self.trigger = try container.decode(AutomatedCampaignTrigger.self, forKey: .trigger)
        case .scheduled:
            self.trigger = try container.decode(ScheduledCampaignTrigger.self, forKey: .trigger)
        }
    }
}
