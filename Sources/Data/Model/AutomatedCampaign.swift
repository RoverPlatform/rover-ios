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
/// The data structure provided by the GraphQL API is squashed and modified somewhat to better suit storage and queryability in Core Data.
public final class AutomatedCampaign: Campaign {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<AutomatedCampaign> {
        return NSFetchRequest<AutomatedCampaign>(entityName: "AutomatedCampaign")
    }
    
    public struct InsertionInfo {
        var eventTriggerEventName: String
        var eventTriggerEventNamespace: String?
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
        
        var triggerSegmentPredicate: Predicate?
        var eventAttributeFilterPredicate: Predicate?
        var scheduledFilterStartDateTime: DateTimeComponents?
        var scheduledFilterEndDateTime: DateTimeComponents?

        public init(
            eventTriggerEventName: String,
            eventTriggerEventNamespace: String?,
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
            triggerSegmentPredicate: Predicate?,
            eventAttributeFilterPredicate: Predicate?,
            scheduledFilterStartDateTime: DateTimeComponents?,
            scheduledFilterEndDateTime: DateTimeComponents?
        ) {
            self.hasDayOfWeekFilter = hasDayOfWeekFilter
            self.hasTimeOfDayFilter = hasTimeOfDayFilter
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
            self.triggerSegmentPredicate = triggerSegmentPredicate
            self.eventAttributeFilterPredicate = eventAttributeFilterPredicate
            self.scheduledFilterStartDateTime = scheduledFilterStartDateTime
            self.scheduledFilterEndDateTime = scheduledFilterEndDateTime
        }
    }
    
    @NSManaged public private(set) var eventTriggerEventName: String
    @NSManaged public private(set) var eventTriggerEventNamespace: String?
    
    /// Specifies if this automated campaign have a Day of Week filter, and thus the timeOfDayFilterStartTime and timeOfDayFilterEndTime fields should be honoured.
    @NSManaged public var hasDayOfWeekFilter: Bool
    @NSManaged public var hasTimeOfDayFilter: Bool
    @NSManaged public var hasEventAttributeFilter: Bool
    @NSManaged public var hasScheduledFilter: Bool
    

    @NSManaged public private(set) var dayOfWeekFilterMonday: Bool
    @NSManaged public private(set) var dayOfWeekFilterTuesday: Bool
    @NSManaged public private(set) var dayOfWeekFilterWednesday: Bool
    @NSManaged public private(set) var dayOfWeekFilterThursday: Bool
    @NSManaged public private(set) var dayOfWeekFilterFriday: Bool
    @NSManaged public private(set) var dayOfWeekFilterSaturday: Bool
    @NSManaged public private(set) var dayOfWeekFilterSunday: Bool
    @NSManaged public private(set) var timeOfDayFilterStartTime: Int
    @NSManaged public private(set) var timeOfDayFilterEndTime: Int


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
        campaign.dayOfWeekFilterMonday = insertionInfo.dayOfWeekFilterMonday
        campaign.dayOfWeekFilterTuesday = insertionInfo.dayOfWeekFilterTuesday
        campaign.dayOfWeekFilterWednesday = insertionInfo.dayOfWeekFilterWednesday
        campaign.dayOfWeekFilterThursday = insertionInfo.dayOfWeekFilterThursday
        campaign.dayOfWeekFilterFriday = insertionInfo.dayOfWeekFilterFriday
        campaign.dayOfWeekFilterSaturday = insertionInfo.dayOfWeekFilterSaturday
        campaign.dayOfWeekFilterSunday = insertionInfo.dayOfWeekFilterSunday
        campaign.timeOfDayFilterStartTime = insertionInfo.timeOfDayFilterStartTime
        campaign.timeOfDayFilterEndTime = insertionInfo.timeOfDayFilterEndTime
        campaign.triggerSegmentPredicate = insertionInfo.triggerSegmentPredicate
        campaign.eventAttributeFilterPredicate = insertionInfo.eventAttributeFilterPredicate
        campaign.scheduledFilterStartDateTime = insertionInfo.scheduledFilterStartDateTime
        campaign.scheduledFilterEndDateTime = insertionInfo.scheduledFilterEndDateTime
        return campaign
    }
    
    public private(set) var triggerSegmentPredicate: Predicate? {
        get {
            return getPredicateForPrimitiveField(forKey: Attributes.triggerSegmentPredicate.rawValue)
        }
        set {
            setPredicateForPrimitiveField(newValue, forKey: Attributes.triggerSegmentPredicate.rawValue)
        }
    }

    public private(set) var eventAttributeFilterPredicate: Predicate? {
        get {
            return getPredicateForPrimitiveField(forKey: Attributes.eventAttributeFilterPredicate.rawValue)
        }
        set {
            setPredicateForPrimitiveField(newValue, forKey: Attributes.eventAttributeFilterPredicate.rawValue)
        }
    }
    
    public private(set) var scheduledFilterStartDateTime: DateTimeComponents? {
        get {
            return getDateTimeComponentsForPrimitiveField(forKey: Attributes.scheduledFilterStartDateTime.rawValue)
        }
        set {
            setDateTimeComponentsForPrimitiveField(newValue, forKey: Attributes.scheduledFilterStartDateTime.rawValue)
        }
    }
    
    public private(set) var scheduledFilterEndDateTime: DateTimeComponents? {
        get {
            return getDateTimeComponentsForPrimitiveField(forKey: Attributes.scheduledFilterEndDateTime.rawValue)
        }
        set {
            setDateTimeComponentsForPrimitiveField(newValue, forKey: Attributes.scheduledFilterEndDateTime.rawValue)
        }
    }
    
    /// Provides strings of field names for the manually created Core Data accessors.
    private enum Attributes: String {
        case eventAttributeFilterPredicate
        case triggerSegmentPredicate
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
    }
}
