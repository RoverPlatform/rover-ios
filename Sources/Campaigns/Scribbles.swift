//
//  Scribbles.swift
//  RoverCampaigns
//
//  Created by Andrew Clunis on 2019-02-08.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation
import os

extension Array where Element == AutomatedCampaign { // TODO: change Element to Campaign and ensure that device filter (segment) field is promoted to abstract type
    func filterBy(deviceSnapshot: DeviceSnapshot) -> [Element] {
        return self.filter { campaign in
            guard let deviceFilter = campaign.triggerSegmentPredicate else {
                // campaign is not filtering by device.
                return true
            }
            let deviceFilterNsPredicate = deviceFilter.nsPredicate()
            return deviceFilterNsPredicate.evaluate(with: deviceSnapshot)
        }
    }
}

func relevantCampaigns(forEvent event: Event, in context: NSManagedObjectContext) throws -> [AutomatedCampaign] {
    var fetchRequest: NSFetchRequest<AutomatedCampaign> = AutomatedCampaign.fetchRequest()
    

    let today = Date()
    let gregorianCalendar = Calendar(identifier: .gregorian)
    let todayWeekday = gregorianCalendar.component(.weekday, from: today)
    
    let todayComponents = gregorianCalendar.dateComponents([.hour, .minute, .second], from: today)
    let secondsSoFarToday = (todayComponents.hour! * 3_600) + (todayComponents.minute! * 60) + todayComponents.second!

    fetchRequest.predicate = NSCompoundPredicate(
        andPredicateWithSubpredicates: [
            NSPredicate(format: "%K == %@", #keyPath(AutomatedCampaign.eventTriggerEventName), event.name),
            NSPredicate(format: "%K == %@", #keyPath(AutomatedCampaign.eventTriggerEventNamespace), event.namespace ?? 0),
            
            // now to match on the queryable filters, which are based on simple types and flattened into the AutomatedCampaign record.
            
            // How we match on filters only when they are enabled: !hasAGivenFilter || (filter expressions...)
        
            // day of week.
            NSCompoundPredicate(
                orPredicateWithSubpredicates: [
                    NSPredicate(format: "!%K", #keyPath(AutomatedCampaign.hasDayOfWeekFilter)),
                    NSCompoundPredicate(
                        andPredicateWithSubpredicates: [
                            NSPredicate(format: "%K == %@", #keyPath(AutomatedCampaign.dayOfWeekFilterSunday), todayWeekday == 1),
                            NSPredicate(format: "%K == %@", #keyPath(AutomatedCampaign.dayOfWeekFilterMonday), todayWeekday == 2),
                            NSPredicate(format: "%K == %@", #keyPath(AutomatedCampaign.dayOfWeekFilterTuesday), todayWeekday == 3),
                            NSPredicate(format: "%K == %@", #keyPath(AutomatedCampaign.dayOfWeekFilterWednesday), todayWeekday == 4),
                            NSPredicate(format: "%K == %@", #keyPath(AutomatedCampaign.dayOfWeekFilterThursday), todayWeekday == 5),
                            NSPredicate(format: "%K == %@", #keyPath(AutomatedCampaign.dayOfWeekFilterFriday), todayWeekday == 6),
                            NSPredicate(format: "%K == %@", #keyPath(AutomatedCampaign.dayOfWeekFilterSaturday), todayWeekday == 7)
                        ]
                    )
                ]
            ),
            
            // time of day.
            NSCompoundPredicate(
                orPredicateWithSubpredicates: [
                    NSPredicate(format: "!%K", #keyPath(AutomatedCampaign.hasTimeOfDayFilter)),
                    NSCompoundPredicate(
                        andPredicateWithSubpredicates: [
                            NSPredicate(format: "%K >= %@", #keyPath(AutomatedCampaign.timeOfDayFilterStartTime), secondsSoFarToday),
                            NSPredicate(format: "%K < %@", #keyPath(AutomatedCampaign.timeOfDayFilterEndTime), secondsSoFarToday),
                        ]
                    )
                ]
            )
        ]
    )
    
    // campaigns that match the things we could query directly through Core Data.  However, not yet fully discriminated
    let queriedCampaigns = try context.fetch(fetchRequest)
    
    // finish the filtering process by filtering by the Automated Campaign filters that could not be implemented in the above large predicate:
    return queriedCampaigns.filter { candidateCampaign in
        // Scheduled filter, which needs its DateTimeComponents transformed into local time when needed.  Too complex to query on directly through Core Data.
        if candidateCampaign.hasScheduledFilter {
            guard let scheduledFilterStartDateTime = candidateCampaign.scheduledFilterStartDateTime else {
                os_log("Campaign marked as having a scheduled filter lacked an start time.", log: .persistence, type: .error)
                return false
            }
            guard let scheduledFilterEndDateTime = candidateCampaign.scheduledFilterEndDateTime else {
                os_log("Campaign marked as having a scheduled filter lacked an end time.", log: .persistence, type: .error)
                return false
            }
            let startDate = Date.initFrom(fromDateTimeComponents: scheduledFilterStartDateTime)
            let endDate = Date.initFrom(fromDateTimeComponents: scheduledFilterEndDateTime)
            let today = Date()
            
            let afterStartDate = startDate == nil ? true : today.compare(startDate!) == ComparisonResult.orderedDescending
            let beforeEndDate = endDate == nil ? true : today.compare(endDate!) == ComparisonResult.orderedAscending
            
            if !(afterStartDate && beforeEndDate) {
                return false
            }
        }
        
        // Event Attributes filter, which has its own representation of a custom predicate stored right in data.  Naturally cannot be queryed with directly in Core Data:
        if candidateCampaign.hasEventAttributeFilter {
            guard let eventPredicate = candidateCampaign.eventAttributeFilterPredicate else {
                os_log("Campaign marked as having an event attribute filter lacked an event attributes predicate.", log: .persistence, type: .error)
                return false
            }
            let nsEventPredicate = eventPredicate.nsPredicate()
            if !nsEventPredicate.evaluate(with: event) {
                return false
            }
        }

        return true
    }
}

extension Predicate {
    // TODO: change these to be contruction extensions on NSPredicate() instead, to be more idiomatic.
    func nsPredicate() -> NSPredicate {
        let nsPredicate: NSPredicate

        switch self {
        case let comparisonPredicate as ComparisonPredicate:
            nsPredicate = comparisonPredicate.nsPredicate()
        case let compoundPredicate as CompoundPredicate:
            nsPredicate = compoundPredicate.nsPredicate()
        default:
            nsPredicate = NSPredicate()
        }

        return nsPredicate
    }
}

extension ComparisonPredicate {
    /// Map the Rover Comparison Predicate into its equivalent Apple NSPredicate.
    func nsPredicate() -> NSPredicate {
        // Left-hand-side value will be the item being tested (as given by keypath).
        // Right-hand-side value is the constant value given.
        
        let rightExpression = NSExpression(forKeyPath: self.keyPath)
        
        // The Predicate has just a single value, to be used as the RHS value.  However, for GraphQL typing reasons separate fields are needed to cover all the types, and nils are used in the unneeded fields. Exactly one should be not nil.  So we aggregate them all down into a single Any? value.
        // can't use one big expression here because the Swift compiler's type inference lags out, so aggregate the nil values in several chunks.
        let value1: Any? = self.booleanValue ?? self.booleanValues
        let value2: Any? = self.dateTimeValue ?? self.dateTimeValues
        let value3: Any? = self.numberValue ?? self.numberValues
        let value4: Any? = self.stringValue ?? self.stringValues
        let value: Any? = value1 ?? value2 ?? value3 ?? value4
        
        if value == nil {
            // this means the Predicate given from GraphQL was invalid.
            os_log("Predicate was missing an RHS value.  Cloud API should not have given us such a Predicate.", log: .campaigns, type: .error)
            return NSPredicate(value: false)
        }
        
        let leftExpression = NSExpression(
            forConstantValue: value
        )
        
        return NSComparisonPredicate(
            leftExpression: leftExpression,
            rightExpression: rightExpression,
            modifier: modifier.nsModifier,
            type: `operator`.nsOperator,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
    }
}

extension CompoundPredicate {
    /// Map the Rover Comparison Predicate into its equivalent Apple NSPredicate.
    func nsPredicate() -> NSPredicate {
        let nsPredicates = self.predicates.map { predicate in
            predicate.nsPredicate()
        }
        
        return NSCompoundPredicate(type: self.booleanOperator.nsLogicalType, subpredicates: nsPredicates)
    }
}

extension ComparisonPredicateOperator {
    /// Map the Rover comparison predicate operator type into its equivalent Apple NSPredicate type.
    var nsOperator: NSComparisonPredicate.Operator {
        switch self {
        case .lessThan:
            return .lessThan
        case .lessThanOrEqualTo:
            return .lessThanOrEqualTo
        case .greaterThan:
            return .greaterThan
        case .greaterThanOrEqualTo:
            return .greaterThanOrEqualTo
        case .equalTo:
            return .equalTo
        case .notEqualTo:
            return .notEqualTo
        case .like:
            return .like
        case .beginsWith:
            return .beginsWith
        case .endsWith:
            return .endsWith
        case .in:
            return .in
        case .contains:
            return .contains
        case .between:
            return .between
        case .geoWithin:
            // TODO: uh this has to be handled separately.  An entire compound predicate needs to be constructed with multiple expressions.  Use an closure-based NSExpression
            fatalError("geoWithin operator not yet implemented")
        }
    }
}

extension ComparisonPredicateModifier {
    /// Map the Rover comparison predicate modifier type into its equivalent Apple NSPredicate type.
    var nsModifier: NSComparisonPredicate.Modifier {
        switch self {
        case .all:
            return .all
        case .any:
            return .any
        case .direct:
            return .direct
        }
    }
}

extension CompoundPredicateLogicalType {
    /// Map the Rover compound predicate logical type into its equivalent Apple NSPredicate type.
    var nsLogicalType: NSCompoundPredicate.LogicalType {
        switch self {
        case .and:
            return .and
        case .or:
            return .or
        case .not:
            return .not
        }
    }
}

extension Date {
    static func initFrom(fromDateTimeComponents components: DateTimeComponents) -> Date? {
        let gregorian = Calendar(identifier: .gregorian)
        let timeZone: TimeZone
        if let timeZoneString = components.timeZone {
            timeZone = TimeZone(identifier: timeZoneString) ?? TimeZone.current
        } else {
            timeZone = TimeZone.current
        }
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        
        guard let parsedDate = formatter.date(from: components.date) else {
            os_log("Illegal date appeared: %s", log: .persistence, type: .error, components.date)
            return nil
        }
        
        return gregorian.date(byAdding: .minute, value: components.time, to: parsedDate)
    }
}
