//
//  AutomatedCampaign.swift
//  RoverData
//
//  Created by Andrew Clunis on 2019-01-22.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation
import os

/// Locally stored version of a Campaign that has an AutomatedCampaignTrigger.
///
/// This is a somewhat squashed and modified representation of the data structure provided by the GraphQL API to better suit storage and queryability in Core Data.
public final class AutomatedCampaign: Campaign {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<AutomatedCampaign> {
        return NSFetchRequest<AutomatedCampaign>(entityName: "AutomatedCampaign")
    }
    
    public struct InsertionInfo {
        var id: String
        var eventTriggerEventName: String
        var eventTriggerEventNamespace: String?
        var deliverable: CampaignDeliverable
        var delayValue: Int
        var delayUnit: DelayUnit
        var hasDayOfWeekFilter: Bool
        var hasTimeOfDayFilter: Bool
        var hasEventAttributeFilter: Bool
        var hasScheduledFilter: Bool
        var dayOfWeekFilterMonday: Bool
        var dayOfWeekFilterTuesday: Bool
        var dayOfWeekFilterWednesday: Bool
        var dayOfWeekFilterThursday: Bool
        var dayOfWeekFilterFriday: Bool
        var dayOfWeekFilterSaturday: Bool
        var dayOfWeekFilterSunday: Bool
        var timeOfDayFilterStartTime: Int
        var timeOfDayFilterEndTime: Int
        var deviceFilterPredicate: Predicate?
        var eventAttributeFilterPredicate: Predicate?
        var scheduledFilterStartDateTime: DateTimeComponents?
        var scheduledFilterEndDateTime: DateTimeComponents?

        public init(
            id: String,
            eventTriggerEventName: String,
            eventTriggerEventNamespace: String?,
            deliverable: CampaignDeliverable,
            delayValue: Int,
            delayUnit: DelayUnit,
            hasDayOfWeekFilter: Bool,
            hasTimeOfDayFilter: Bool,
            hasEventAttributeFilter: Bool,
            hasScheduledFilter: Bool,
            dayOfWeekFilterMonday: Bool,
            dayOfWeekFilterTuesday: Bool,
            dayOfWeekFilterWednesday: Bool,
            dayOfWeekFilterThursday: Bool,
            dayOfWeekFilterFriday: Bool,
            dayOfWeekFilterSaturday: Bool,
            dayOfWeekFilterSunday: Bool,
            timeOfDayFilterStartTime: Int,
            timeOfDayFilterEndTime: Int,
            deviceFilterPredicate: Predicate?,
            eventAttributeFilterPredicate: Predicate?,
            scheduledFilterStartDateTime: DateTimeComponents?,
            scheduledFilterEndDateTime: DateTimeComponents?
        ) {
            self.id = id
            self.hasDayOfWeekFilter = hasDayOfWeekFilter
            self.hasTimeOfDayFilter = hasTimeOfDayFilter
            self.deliverable = deliverable
            self.delayValue = delayValue
            self.delayUnit = delayUnit
            self.hasEventAttributeFilter = hasEventAttributeFilter
            self.hasScheduledFilter = hasScheduledFilter
            self.eventTriggerEventName = eventTriggerEventName
            self.eventTriggerEventNamespace = eventTriggerEventNamespace
            self.dayOfWeekFilterMonday = dayOfWeekFilterMonday
            self.dayOfWeekFilterTuesday = dayOfWeekFilterTuesday
            self.dayOfWeekFilterWednesday = dayOfWeekFilterWednesday
            self.dayOfWeekFilterThursday = dayOfWeekFilterThursday
            self.dayOfWeekFilterFriday = dayOfWeekFilterFriday
            self.dayOfWeekFilterSaturday = dayOfWeekFilterSaturday
            self.dayOfWeekFilterSunday = dayOfWeekFilterSunday
            self.timeOfDayFilterStartTime = timeOfDayFilterStartTime
            self.timeOfDayFilterEndTime = timeOfDayFilterEndTime
            self.deviceFilterPredicate = deviceFilterPredicate
            self.eventAttributeFilterPredicate = eventAttributeFilterPredicate
            self.scheduledFilterStartDateTime = scheduledFilterStartDateTime
            self.scheduledFilterEndDateTime = scheduledFilterEndDateTime
        }
    }
    
    @discardableResult
    public static func insert(
        into context: NSManagedObjectContext,
        insertionInfo: InsertionInfo
    ) -> AutomatedCampaign {
        let campaign = AutomatedCampaign(context: context)
        campaign.hasDayOfWeekFilter = insertionInfo.hasDayOfWeekFilter
        campaign.hasTimeOfDayFilter = insertionInfo.hasTimeOfDayFilter
        campaign.hasEventAttributeFilter = insertionInfo.hasEventAttributeFilter
        campaign.hasScheduledFilter = insertionInfo.hasScheduledFilter
        campaign.eventTriggerEventName = insertionInfo.eventTriggerEventName
        campaign.eventTriggerEventNamespace = insertionInfo.eventTriggerEventNamespace
        campaign.delayValue = insertionInfo.delayValue
        campaign.delayUnit = insertionInfo.delayUnit
        campaign.dayOfWeekFilterMonday = insertionInfo.dayOfWeekFilterMonday
        campaign.dayOfWeekFilterTuesday = insertionInfo.dayOfWeekFilterTuesday
        campaign.dayOfWeekFilterWednesday = insertionInfo.dayOfWeekFilterWednesday
        campaign.dayOfWeekFilterThursday = insertionInfo.dayOfWeekFilterThursday
        campaign.dayOfWeekFilterFriday = insertionInfo.dayOfWeekFilterFriday
        campaign.dayOfWeekFilterSaturday = insertionInfo.dayOfWeekFilterSaturday
        campaign.dayOfWeekFilterSunday = insertionInfo.dayOfWeekFilterSunday
        campaign.timeOfDayFilterStartTime = insertionInfo.timeOfDayFilterStartTime
        campaign.timeOfDayFilterEndTime = insertionInfo.timeOfDayFilterEndTime
        campaign.deviceFilterPredicate = insertionInfo.deviceFilterPredicate
        campaign.eventAttributeFilterPredicate = insertionInfo.eventAttributeFilterPredicate
        campaign.scheduledFilterStartDateTime = insertionInfo.scheduledFilterStartDateTime
        campaign.scheduledFilterEndDateTime = insertionInfo.scheduledFilterEndDateTime
        return campaign
    }
    
    @NSManaged public internal(set) var eventTriggerEventName: String
    @NSManaged public internal(set) var eventTriggerEventNamespace: String?
    
    @NSManaged public internal(set) var delayValue: Int
    
    
    /// Specifies if this automated campaign has a Day of Week filter and thus the dayOfWeekFilter* properties should be honoured.
    @NSManaged public internal(set) var hasDayOfWeekFilter: Bool
    
    /// Specifies if this automated campaign has a Time of Day filter, and thus the timeOfDayFilterStartTime and timeOfDayFilterEndTime fields should be honoured.
    @NSManaged public internal(set) var hasTimeOfDayFilter: Bool
    
    /// Specifies if this automated campaign has an Event Attributes filter, and thus the eventAttributeFilterPredicate should be honoured.
    @NSManaged public internal(set) var hasEventAttributeFilter: Bool
    
    // Specifies if this automated campaign has a Scheduled filter, and thus the timeOfDayFilterStartTime and timeOfDayFilterEndTime properties should be honoured.
    @NSManaged public internal(set) var hasScheduledFilter: Bool
    
    @NSManaged public internal(set) var dayOfWeekFilterMonday: Bool
    @NSManaged public internal(set) var dayOfWeekFilterTuesday: Bool
    @NSManaged public internal(set) var dayOfWeekFilterWednesday: Bool
    @NSManaged public internal(set) var dayOfWeekFilterThursday: Bool
    @NSManaged public internal(set) var dayOfWeekFilterFriday: Bool
    @NSManaged public internal(set) var dayOfWeekFilterSaturday: Bool
    @NSManaged public internal(set) var dayOfWeekFilterSunday: Bool
    
    /// Start of a window of when campaign may be triggered, as a time of day in seconds.
    @NSManaged public internal(set) var timeOfDayFilterStartTime: Int
    
    /// End of a window of \when the campaign may be triggered, as a time of day in seconds.
    @NSManaged public internal(set) var timeOfDayFilterEndTime: Int
    
    public internal(set) var deviceFilterPredicate: Predicate? {
        get {
            return getPredicateForPrimitiveField(forKey: Attributes.deviceFilterPredicate.rawValue)
        }
        set {
            setPredicateForPrimitiveField(newValue, forKey: Attributes.deviceFilterPredicate.rawValue)
        }
    }

    public internal(set) var eventAttributeFilterPredicate: Predicate? {
        get {
            return getPredicateForPrimitiveField(forKey: Attributes.eventAttributeFilterPredicate.rawValue)
        }
        set {
            setPredicateForPrimitiveField(newValue, forKey: Attributes.eventAttributeFilterPredicate.rawValue)
        }
    }
    
    public internal(set) var scheduledFilterStartDateTime: DateTimeComponents? {
        get {
            return getDateTimeComponentsForPrimitiveField(forKey: Attributes.scheduledFilterStartDateTime.rawValue)
        }
        set {
            setDateTimeComponentsForPrimitiveField(newValue, forKey: Attributes.scheduledFilterStartDateTime.rawValue)
        }
    }
    
    public internal(set) var scheduledFilterEndDateTime: DateTimeComponents? {
        get {
            return getDateTimeComponentsForPrimitiveField(forKey: Attributes.scheduledFilterEndDateTime.rawValue)
        }
        set {
            setDateTimeComponentsForPrimitiveField(newValue, forKey: Attributes.scheduledFilterEndDateTime.rawValue)
        }
    }
    
    public internal(set) var delayUnit: DelayUnit {
        get {
            let key = Attributes.delayUnit.rawValue
            self.willAccessValue(forKey: key)
            defer { self.didAccessValue(forKey: key) }
            let value = primitiveValue(forKey: key) as? String ?? ""
            return DelayUnit(rawValue: value) ?? .seconds
        }
        set {
            let key = Attributes.delayUnit.rawValue
            willChangeValue(forKey: key)
            defer { didChangeValue(forKey: key) }
            setPrimitiveValue(newValue.rawValue, forKey: key)
        }
    }
    
    /// Provides strings of field names for the manually created Core Data accessors.
    private enum Attributes: String {
        case eventAttributeFilterPredicate
        case deviceFilterPredicate
        case timeOfDayFilterStartTime
        case timeOfDayFilterEndTime
        case dayOfWeekFilterMonday
        case dayOfWeekFilterTuesday
        case dayOfWeekFilterWednesday
        case dayOfWeekFilterThursday
        case dayOfWeekFilterFriday
        case dayOfWeekFilterSaturday
        case dayOfWeekFilterSunday
        case scheduledFilterStartDateTime
        case scheduledFilterEndDateTime
        case delayUnit
    }
    
    public enum DelayUnit: String, Decodable {
        case seconds = "s"
        case minutes = "m"
        case hours = "h"
        case days = "d"
    }
}
