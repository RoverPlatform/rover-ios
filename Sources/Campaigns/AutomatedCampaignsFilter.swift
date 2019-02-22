//
//  AutomationEngine.swift
//  RoverCampaigns
//
//  Created by Andrew Clunis on 2019-02-08.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation
import os

/// This contains all of the logic for matching an Event to any locally stored Automated Campaigns that match it.
open class AutomatedCampaignsFilter {
    let managedObjectContext: NSManagedObjectContext
    
    init (managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }
    
    /// Returns the automated campaigns that match the given event.
    open func automatedCampaignsMatching(
        event: Event,
        forDevice device: DeviceSnapshot,
        in context: NSManagedObjectContext,
        todayBeing today: Date = Date(),
        inTimeZone timeZone: TimeZone = TimeZone.current
    ) throws -> [AutomatedCampaign] {
        let fetchRequest: NSFetchRequest<AutomatedCampaign> = AutomatedCampaign.fetchRequest()
        fetchRequest.predicate = queryPredicateForCampaignQueryableFilters(forEvent: event, todayBeing: today, in: timeZone)
        let queryMatchedCampaigns = try context.fetch(fetchRequest)
        // now apply the computed filters that could not be done directly in the query predicate:
        return queryMatchedCampaigns
            .filterByScheduledTime(todayBeing: today, in: timeZone)
            .filterBy(deviceSnapshot: device)
            .filterBy(attributesFromEvent: event)
    }
    
    /// A query predicate, suitable for use with Core Data, for filtering down the Automated Campaigns down to ones that match the event. Howvever, this does not apply all of the Campaigns' filters: only those filters that can be pratically filtered in Core Data are used.  You should subsequently use filterByDeviceSnapshot, filterByEventAttributes, and filterByScheduledTime to fully discriminate the list.
    private func queryPredicateForCampaignQueryableFilters(
        forEvent event: Event,
        todayBeing today: Date,
        in timeZone: TimeZone
    ) -> NSPredicate {
        var gregorianCalendar = Calendar(identifier: .gregorian)
        gregorianCalendar.timeZone = timeZone
        let todayWeekday = gregorianCalendar.component(.weekday, from: today)
        
        let todayComponents = gregorianCalendar.dateComponents([.hour, .minute, .second], from: today)
        let secondsSoFarToday = (todayComponents.hour! * 3_600) + (todayComponents.minute! * 60) + todayComponents.second!
        
        return NSCompoundPredicate(
            andPredicateWithSubpredicates: [
                NSPredicate(format: "%K == %@", #keyPath(AutomatedCampaign.eventTriggerEventName), event.name),
                NSPredicate(format: "%K == %@", #keyPath(AutomatedCampaign.eventTriggerEventNamespace), event.namespace ?? 0),
                // How we match on filters only when they are enabled: !hasAGivenFilter || (filter expressions...)
                
                // day of week.
                NSCompoundPredicate(
                    orPredicateWithSubpredicates: [
                        NSPredicate(format: "%K == NO", #keyPath(AutomatedCampaign.hasDayOfWeekFilter)),
                        NSCompoundPredicate(
                            andPredicateWithSubpredicates: [
                                NSPredicate(format: "%K == %d", #keyPath(AutomatedCampaign.dayOfWeekFilterSunday), todayWeekday == 1),
                                NSPredicate(format: "%K == %d", #keyPath(AutomatedCampaign.dayOfWeekFilterMonday), todayWeekday == 2),
                                NSPredicate(format: "%K == %d", #keyPath(AutomatedCampaign.dayOfWeekFilterTuesday), todayWeekday == 3),
                                NSPredicate(format: "%K == %d", #keyPath(AutomatedCampaign.dayOfWeekFilterWednesday), todayWeekday == 4),
                                NSPredicate(format: "%K == %d", #keyPath(AutomatedCampaign.dayOfWeekFilterThursday), todayWeekday == 5),
                                NSPredicate(format: "%K == %d", #keyPath(AutomatedCampaign.dayOfWeekFilterFriday), todayWeekday == 6),
                                NSPredicate(format: "%K == %d", #keyPath(AutomatedCampaign.dayOfWeekFilterSaturday), todayWeekday == 7)
                            ]
                        )
                    ]
                ),
                
                // time of day.
                NSCompoundPredicate(
                    orPredicateWithSubpredicates: [
                        NSPredicate(format: "%K == NO", #keyPath(AutomatedCampaign.hasTimeOfDayFilter)),
                        NSCompoundPredicate(
                            andPredicateWithSubpredicates: [
                                NSPredicate(format: "%K <= %d", #keyPath(AutomatedCampaign.timeOfDayFilterStartTime), secondsSoFarToday),
                                NSPredicate(format: "%K > %d", #keyPath(AutomatedCampaign.timeOfDayFilterEndTime), secondsSoFarToday)
                            ]
                        )
                    ]
                )
            ]
        )
    }
}

extension Array where Element == AutomatedCampaign {
    /// Filter out any campaigns with a Scheduled Filter, if one is present, that do not match the current time.
    public func filterByScheduledTime(todayBeing today: Date, in timeZone: TimeZone) -> [Element] {
        return filter { campaign in
            // Scheduled filter, which needs its DateTimeComponents transformed into local time when needed.  Too complex to query on directly through Core Data.
            if campaign.hasScheduledFilter {
                guard let scheduledFilterStartDateTime = campaign.scheduledFilterStartDateTime else {
                    os_log("Campaign marked as having a scheduled filter lacked an start time.", log: .persistence, type: .error)
                    return false
                }
                guard let scheduledFilterEndDateTime = campaign.scheduledFilterEndDateTime else {
                    os_log("Campaign marked as having a scheduled filter lacked an end time.", log: .persistence, type: .error)
                    return false
                }
                let startDate = Date.initFrom(fromDateTimeComponents: scheduledFilterStartDateTime, whereLocalTimeZoneIs: timeZone)
                let endDate = Date.initFrom(fromDateTimeComponents: scheduledFilterEndDateTime, whereLocalTimeZoneIs: timeZone)
                
                let afterStartDate = startDate == nil ? true : today.compare(startDate!) == ComparisonResult.orderedDescending
                let beforeEndDate = endDate == nil ? true : today.compare(endDate!) == ComparisonResult.orderedAscending
                
                if !(afterStartDate && beforeEndDate) {
                    return false
                }
            }
            return true
        }
    }
    
    /// Filters out any campaigns with Event Attributes filter, if one is present, that do not match the given event.
    public func filterBy(attributesFromEvent event: Event) -> [Element] {
        return filter { campaign in
            // Event Attributes filter, which has its own representation of a custom predicate stored right in data.  Naturally cannot be queryed with directly in Core Data:
            if campaign.hasEventAttributeFilter {
                guard let eventPredicate = campaign.eventAttributeFilterPredicate else {
                    os_log("Campaign marked as having an event attribute filter lacked an event attributes predicate.", log: .persistence, type: .error)
                    return false
                }
                let nsEventPredicate = eventPredicate.nsPredicate
                // The underlying dictionary, rawValue, implements KVC so it can be used as an NSPredicate target.
                if !nsEventPredicate.evaluate(withObjectSwallowingExceptions: event.attributes.rawValue) {
                    return false
                }
            }
            
            return true
        }
    }
    
    // TODO: when implementing Scheduled campaigns change Element to Campaign and ensure that device filter (segment) field is promoted to abstract type
    /// Filters out any campaigns with a device filter, if one is present, that do not match the current device.  Sometimes referred to as a Segment.
    // TODO: this method should be factored out into a separate shared extension.
    public func filterBy(deviceSnapshot: DeviceSnapshot) -> [Element] {
        return self.filter { campaign in
            guard let deviceFilter = campaign.deviceFilterPredicate else {
                // campaign is not filtering by device.
                return true
            }
            let deviceFilterNsPredicate = deviceFilter.nsPredicate
            // DeviceSnapshot, despite being an NSObject, cannot readily be made KVC compliant. So, we'll use its Codable implementation throug JSONEncoder/JSONDecoder to coerce it to a simple Swift [String: Any] dictionary, which does support KVC.  This also makes it explicit that we're comparing against the JSON version, which is the exact format our backend supports, so all the data types (particularly things like booleans) are represented for comparison here the exact same way as the Predicates coming our backend will expect.
            let deviceDictionary: [String: Any]
            do {
                let deviceJson = try JSONEncoder.default.encode(deviceSnapshot)
                guard let dictionary = try JSONSerialization.jsonObject(with: deviceJson, options: .allowFragments) as? [String: Any] else {
                    os_log("Problem coercing DeviceSnapshot JSON back to a dictionary for device filter comparison.  Ignoring this campaign.")
                    return false
                }
                deviceDictionary = dictionary
            } catch {
                os_log("Problem dealing with DeviceSnapshot value for device filter comparison.  Ignoring this campaign: %@", String(describing: error))
                return false
            }
            return deviceFilterNsPredicate.evaluate(with: deviceDictionary)
        }
    }
}

extension Predicate {
    /// Map the Rover Comparison Predicate into its equivalent Apple NSPredicate.
    var nsPredicate: NSPredicate {
        let nsPredicate: NSPredicate

        switch self {
        case let comparisonPredicate as ComparisonPredicate:
            nsPredicate = comparisonPredicate.nsPredicate
        case let compoundPredicate as CompoundPredicate:
            nsPredicate = compoundPredicate.nsPredicate()
        default:
            nsPredicate = NSPredicate()
        }

        return nsPredicate
    }
}

extension NSArray {
    /// Used as a target for an NSPredicate .customSelector in order to implement our custom geoWithin operator.  Uses the haversine algorithm to determine if the given value is within the coordinates.
    /// LHS (self) is expected [lat, long, radius].
    /// RHS (latLongAndRadius) is target coordinates for comparision, [lat, long].
    @objc
    fileprivate func compareGeowithin(latLongAndRadius: NSArray) -> Bool {
        // invoked on the left-hand-side (which should be a tuple NSArray of lat/long) with the right-hand side as the argument (which should be an NSArray triple of lat/long/radius).
        guard let withinTriple = self as? [Double] else {
            return false
        }
        if withinTriple.count != 3 {
            os_log("Invalid value array given for geoWithin operator: %@", String(describing: latLongAndRadius))
            return false
        }
        let withinLat = withinTriple[0]
        let withinLong = withinTriple[1]
        let withinRadius = withinTriple[2]
        
        guard let pointTriple = latLongAndRadius as? [Double] else {
            return false
        }
        if pointTriple.count != 2 {
            os_log("Invalid value array given for geoWithin to compare against: %@", String(describing: self))
            return false
        }
        let pointLat = pointTriple[0]
        let pointLong = pointTriple[1]
        
        return NSArray.distanceBetween(latitude: withinLat, longitude: withinLong, otherLatitude: pointLat, otherLongitude: pointLong) < withinRadius
    }
    
    // https://en.wikipedia.org/wiki/Figure_of_the_Earth
    private static let earthRadius: Double = 6_371_000
    
    private static let haversin: (Double) -> Double = {
        (1 - cos($0)) / 2
    }
    
    private static let ahaversin: (Double) -> Double = {
        2 * asin(sqrt($0))
    }
    
    private static let degreesToRadians: (Double) -> Double = {
        ($0 / 360) * 2 * Double.pi
    }
    
    private static func distanceBetween(latitude: Double, longitude: Double, otherLatitude: Double, otherLongitude: Double) -> Double {
        let lat1 = degreesToRadians(latitude)
        let lon1 = degreesToRadians(longitude)
        let lat2 = degreesToRadians(otherLatitude)
        let lon2 = degreesToRadians(otherLongitude)
        return earthRadius * ahaversin(haversin(lat2 - lat1) + cos(lat1) * cos(lat2) * haversin(lon2 - lon1))
    }
}

extension ComparisonPredicate {
    /// Map the Rover Comparison Predicate into its equivalent Apple NSPredicate.
    var nsPredicate: NSPredicate {
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
        
        if `operator` == .geoWithin {
            // geoWithin is our own custom operator.  In that case, refer to a custom selector.
            // Note that if used this operator precludes the use of this predicate with Core Data (or some other mechanism that transforms the predicate to another language rather than evaluating it directly in the framework).
            return NSComparisonPredicate(
                leftExpression: leftExpression,
                rightExpression: rightExpression,
                customSelector: #selector(NSArray.compareGeowithin(latLongAndRadius:))
            )
        } else {
            return NSComparisonPredicate(
                leftExpression: leftExpression,
                rightExpression: rightExpression,
                modifier: modifier.nsModifier,
                type: `operator`.nsOperator,
                options: NSComparisonPredicate.Options(rawValue: 0)
            )
        }
    }
}

extension CompoundPredicate {
    /// Map the Rover Comparison Predicate into its equivalent Apple NSPredicate.
    public func nsPredicate() -> NSPredicate {
        let nsPredicates = self.predicates.map { predicate in
            predicate.nsPredicate
        }
        
        return NSCompoundPredicate(type: self.booleanOperator.nsLogicalType, subpredicates: nsPredicates)
    }
}

extension ComparisonPredicateOperator {
    /// Map the Rover comparison predicate operator type into its equivalent Apple NSPredicate type.
    public var nsOperator: NSComparisonPredicate.Operator {
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
            // We implement our own custom `geoWithin` operator using an NSPredicate custom selector.  See ComparisonPredicate.nsPredicate.
            return .customSelector
        }
    }
}

extension ComparisonPredicateModifier {
    /// Map the Rover comparison predicate modifier type into its equivalent Apple NSPredicate type.
    public var nsModifier: NSComparisonPredicate.Modifier {
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
    public var nsLogicalType: NSCompoundPredicate.LogicalType {
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
    // Instantiate an Apple Date type from the Rover DateTimeComponents model class, which is equivalent to the Apple DateTimeComponents class.
    public static func initFrom(fromDateTimeComponents components: DateTimeComponents, whereLocalTimeZoneIs localTimeZone: TimeZone) -> Date? {
        let gregorian = Calendar(identifier: .gregorian)
        let timeZone: TimeZone
        if let timeZoneString = components.timeZone {
            timeZone = TimeZone(identifier: timeZoneString) ?? localTimeZone
        } else {
            timeZone = localTimeZone
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

