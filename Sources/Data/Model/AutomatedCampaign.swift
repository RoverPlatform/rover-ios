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

    public private(set) var dayOfWeekFilterMonday: Bool? {
        get { return getOptionalBooleanForPrimitiveField(forKey: Attributes.dayOfWeekFilterMonday.rawValue) }
        set { setOptionalBooleanForPrimitiveField(newValue: newValue, forKey: Attributes.dayOfWeekFilterMonday.rawValue) }
    }
    
    public private(set) var dayOfWeekFilterTuesday: Bool? {
        get { return getOptionalBooleanForPrimitiveField(forKey: Attributes.dayOfWeekFilterTuesday.rawValue) }
        set { setOptionalBooleanForPrimitiveField(newValue: newValue, forKey: Attributes.dayOfWeekFilterTuesday.rawValue) }
    }
    
    public private(set) var dayOfWeekFilterWednesday: Bool? {
        get { return getOptionalBooleanForPrimitiveField(forKey: Attributes.dayOfWeekFilterWednesday.rawValue) }
        set { setOptionalBooleanForPrimitiveField(newValue: newValue, forKey: Attributes.dayOfWeekFilterWednesday.rawValue) }
    }
    
    public private(set) var dayOfWeekFilterThursday: Bool? {
        get { return getOptionalBooleanForPrimitiveField(forKey: Attributes.dayOfWeekFilterThursday.rawValue) }
        set { setOptionalBooleanForPrimitiveField(newValue: newValue, forKey: Attributes.dayOfWeekFilterThursday.rawValue) }
    }
    
    public private(set) var dayOfWeekFilterFriday: Bool? {
        get { return getOptionalBooleanForPrimitiveField(forKey: Attributes.dayOfWeekFilterFriday.rawValue) }
        set { setOptionalBooleanForPrimitiveField(newValue: newValue, forKey: Attributes.dayOfWeekFilterFriday.rawValue) }
    }
    
    public private(set) var dayOfWeekFilterSaturday: Bool? {
        get { return getOptionalBooleanForPrimitiveField(forKey: Attributes.dayOfWeekFilterSaturday.rawValue) }
        set { setOptionalBooleanForPrimitiveField(newValue: newValue, forKey: Attributes.dayOfWeekFilterSaturday.rawValue) }
    }
    
    public private(set) var dayOfWeekFilterSunday: Bool? {
        get { return getOptionalBooleanForPrimitiveField(forKey: Attributes.dayOfWeekFilterSunday.rawValue) }
        set { setOptionalBooleanForPrimitiveField(newValue: newValue, forKey: Attributes.dayOfWeekFilterSunday.rawValue) }
    }

    @discardableResult
    public static func insert(into context: NSManagedObjectContext) -> AutomatedCampaign {
        return AutomatedCampaign(context: context)
    }
    
    public private(set) var triggerSegmentPredicate: Predicate? {
        get {
            return getPredicateForPrimitiveField(forKey: Attributes.triggerSegmentPredicate.rawValue)
        }
        set {
            setPrimitiveValue(newValue, forKey: Attributes.triggerSegmentPredicate.rawValue)
        }
    }

    public private(set) var eventAttributeFilterPredicate: Predicate? {
        get {
            return getPredicateForPrimitiveField(forKey: Attributes.eventAttributeFilterPredicate.rawValue)
        }
        set {
            setPrimitiveValue(newValue, forKey: Attributes.eventAttributeFilterPredicate.rawValue)
        }
    }
    
    private func getPredicateForPrimitiveField(forKey key: String) -> Predicate? {
        self.willAccessValue(forKey: key)
        defer { self.didAccessValue(forKey: key) }
        guard let primitiveValue = primitiveValue(forKey: key) as? Data else {
            return nil
        }
        
        guard let predicateType = try? JSONDecoder.default.decode(PredicateType.self, from: primitiveValue) else {
            os_log("Unable to determine type of predicate stored in Core Data.", log: .persistence, type: .error)
            return nil
        }
        
        do {
            switch predicateType {
            case .comparisonPredicate:
                return try JSONDecoder.default.decode(ComparisonPredicate.self, from: primitiveValue)
            case .compoundPredicate:
                return try JSONDecoder.default.decode(CompoundPredicate.self, from: primitiveValue)
            }
        } catch {
            os_log("Unable to decode predicate stored in core data: %s", log: .persistence, type: .error, String(describing: error))
            return nil
        }
    }
    
    private func setPredicateForPrimitiveField(newValue: Predicate?, forKey key: String) {
        willChangeValue(forKey: key)
        defer { didChangeValue(forKey: key) }
        let primitiveValue: Data
        
        guard let newValue = newValue else {
            setPrimitiveValue(nil, forKey: key)
            return
        }
        
        do {
            switch newValue {
            case let compound as CompoundPredicate:
                primitiveValue = try JSONEncoder.default.encode(compound)
            case let comparison as ComparisonPredicate:
                primitiveValue = try JSONEncoder.default.encode(comparison)
            default:
                let context = EncodingError.Context(codingPath: [], debugDescription: "Unexpected predicate type appeared during encode.")
                throw EncodingError.invalidValue(newValue, context)
            }
        } catch {
            os_log("Unable to encode predicate for storage in core data: %@", log: .persistence, type: .error, String(describing: error))
            return
        }
        
        setPrimitiveValue(primitiveValue, forKey: key)
    }
    
    private func getOptionalBooleanForPrimitiveField(forKey key: String) -> Bool? {
        self.willAccessValue(forKey: key)
        defer { self.didAccessValue(forKey: key) }
        guard let primitiveValue = primitiveValue(forKey: key) as? NSNumber else {
            return nil
        }
        return primitiveValue != 0
    }
    
    private func setOptionalBooleanForPrimitiveField(newValue: Bool?, forKey key: String) {
        willChangeValue(forKey: key)
        defer { didChangeValue(forKey: key) }
        
        guard let newValue = newValue else {
            setPrimitiveValue(nil, forKey: key)
            return
        }
        setPrimitiveValue(NSNumber(value: newValue), forKey: key)
    }
    
    /// Provides strings of field names for the manually created Core Data accessors.
    enum Attributes: String {
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
    }
}
