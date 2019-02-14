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
    
    @NSManaged public private(set) var eventTriggerEventName: String?
    @NSManaged public private(set) var eventTriggerEventNamespace: String?
    
    @NSManaged public private(set) var dayOfWeekFilterMonday: Bool
    @NSManaged public private(set) var dayOfWeekFilterTuesday: Bool
    @NSManaged public private(set) var dayOfWeekFilterWednesday: Bool
    @NSManaged public private(set) var dayOfWeekFilterThursday: Bool
    @NSManaged public private(set) var dayOfWeekFilterFriday: Bool
    @NSManaged public private(set) var dayOfWeekFilterSaturday: Bool
    @NSManaged public private(set) var dayOfWeekFilterSunday: Bool
    
    @NSManaged public private(set) var timeOfDayFilterStartTime: Int
    @NSManaged public private(set) var timeOfDayFilterEndTime: Int
    
    /// Specifies if this automated campaign have a Day of Week filter, and thus the timeOfDayFilterStartTime and timeOfDayFilterEndTime fields should be honoured.
    @NSManaged public private(set) var hasDayOfWeekFilter: Bool
    @NSManaged public private(set) var hasTimeOfDayFilter: Bool
    @NSManaged public private(set) var hasEventAttributeFilter: Bool
    @NSManaged public private(set) var hasScheduledFilter: Bool

    @discardableResult
    public static func insert(into context: NSManagedObjectContext) -> AutomatedCampaign {
        return AutomatedCampaign(context: context)
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
